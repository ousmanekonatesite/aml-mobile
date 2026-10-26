import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/competition_repository.dart';
import '../../services/fights_repository.dart';
import '../../utils/aml_time.dart';
import '../predictions/predictions_screen.dart';
import 'fight_detail_screen.dart';
import '../../widgets_face_avatar.dart';
import '../../widgets_card_backdrop.dart';
import '../fighters/fighter_profile_loader.dart';

const _blue = Color(0xFF00AEEF);
const _black = Color(0xFF050505);
const _surface = Color(0xFF111111);

/// Liste des cartes par compétition (AML d'abord) ; une carte ouvre `FightsScreen(eventId: …)`
/// qui affiche tous les combats de cette carte.
class FightsScreen extends StatefulWidget {
  final String? eventId;
  final String? eventTitle;
  const FightsScreen({super.key, this.eventId, this.eventTitle});
  @override State<FightsScreen> createState() => _FightsScreenState();
}

class _FightsScreenState extends State<FightsScreen> {
  final competitionsRepo = CompetitionRepository();
  final fightsRepo = FightsRepository();
  bool loading = true;
  List<Map<String, dynamic>> competitions = [];
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> fights = [];
  String selected = 'all';

  bool get detail => widget.eventId != null;

  @override void initState() { super.initState(); _load(first: true); }

  Future<void> _load({bool first = false}) async {
    setState(() => loading = true);
    if (detail) {
      final data = await fightsRepo.upcoming(eventId: widget.eventId);
      data.sort((a, b) => ((a['bout_order'] as num?)?.toInt() ?? 999).compareTo((b['bout_order'] as num?)?.toInt() ?? 999));
      if (!mounted) return;
      setState(() { fights = data; loading = false; });
      return;
    }
    // Les compétitions sont déjà triées : AML en premier, puis les autres par ordre alphabétique.
    final comps = await competitionsRepo.active();
    if (first && comps.isNotEmpty) selected = comps.first['id'].toString();
    final data = await fightsRepo.events(competitionId: selected == 'all' ? null : selected);
    if (!mounted) return;
    setState(() { competitions = comps; events = data; loading = false; });
  }

  void _select(String id) { if (selected == id) return; setState(() => selected = id); _load(); }

  DateTime? _date(Map<String, dynamic> e) => DateTime.tryParse('${e['starts_at'] ?? ''}')?.toLocal();

  bool _isUpcoming(Map<String, dynamic> e) {
    if (e['status'] == 'live') return true;
    if (e['status'] == 'finished') return false;
    final d = _date(e);
    return d == null || d.isAfter(DateTime.now().subtract(const Duration(hours: 12)));
  }

  bool _isAml(Map<String, dynamic> e) => (e['competition'] is Map) && e['competition']['is_aml'] == true;

  List<Map<String, dynamic>> _amlFirst(List<Map<String, dynamic>> list) =>
      selected == 'all' ? [...list.where(_isAml), ...list.where((e) => !_isAml(e))] : list;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _black,
    appBar: AppBar(
      backgroundColor: _black,
      title: Text(detail ? (widget.eventTitle ?? 'Fight card') : 'Combats', style: TextStyle(fontSize: detail ? 20 : 26, fontWeight: FontWeight.w900)),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: _blue))
        : RefreshIndicator(
            color: _blue,
            onRefresh: _load,
            child: detail ? _detailView() : _listView(),
          ),
  );

  Widget _detailView() => ListView(
    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    children: [
      if (fights.isNotEmpty) ...[
        Text('${fights.length} combat${fights.length > 1 ? 's' : ''} sur cette carte', style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 14),
        ...fights.map(_fightCard),
      ] else
        const Padding(padding: EdgeInsets.all(35), child: Center(child: Text('Aucun combat publié sur cette carte pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)))),
    ],
  );

  Widget _listView() {
    final upcoming = events.where(_isUpcoming).toList()
      ..sort((a, b) {
        final da = _date(a), db = _date(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db); // la prochaine carte d'abord
      });
    final past = events.where((e) => !_isUpcoming(e)).toList()
      ..sort((a, b) {
        final da = _date(a), db = _date(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da); // la plus récente d'abord
      });
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...competitions.map((c) => _Filter(label: c['name']?.toString() ?? 'Compétition', selected: selected == c['id'].toString(), onTap: () => _select(c['id'].toString()))),
              _Filter(label: 'Toutes', selected: selected == 'all', onTap: () => _select('all')),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (events.isEmpty)
          const Padding(padding: EdgeInsets.all(35), child: Center(child: Text('Aucune carte publiée pour cette compétition.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))))
        else ...[
          if (upcoming.isNotEmpty) ...[
            const _SectionLabel('À VENIR'),
            ..._amlFirst(upcoming).map(_eventCard),
          ],
          if (past.isNotEmpty) ...[
            const _SectionLabel('HISTORIQUE DES CARTES'),
            ..._amlFirst(past).map(_eventCard),
          ],
        ],
      ],
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final comp = Map<String, dynamic>.from(e['competition'] ?? {});
    final poster = (e['poster_url'] ?? e['cover_url'] ?? '').toString().trim();
    final count = (e['fight_count'] as num?)?.toInt() ?? 0;
    final titles = (e['title_fight_count'] as num?)?.toInt() ?? 0;
    final status = e['status']?.toString();
    final date = amlFormatDate(e['starts_at']);
    final city = (e['city'] ?? '').toString().trim();
    final placeholder = Container(width: 74, height: 74, color: const Color(0xFF202020), child: const Icon(Icons.sports_mma, color: Colors.white30));
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FightsScreen(eventId: e['id'].toString(), eventTitle: e['name']?.toString()))),
      child: AmlCardBackdrop(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        radius: 18,
        color: _surface,
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: poster.isEmpty ? placeholder : CachedNetworkImage(imageUrl: poster, width: 74, height: 74, fit: BoxFit.cover, alignment: Alignment.topCenter, errorWidget: (_, __, ___) => placeholder),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _blue.withOpacity(.12), borderRadius: BorderRadius.circular(7)), child: Text(comp['name']?.toString() ?? 'MMA', style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900))),
              const SizedBox(width: 6),
              if (status == 'live') const Text('EN DIRECT', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w900))
              else if (status == 'finished') const Text('TERMINÉE', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Text(e['name']?.toString() ?? 'Carte', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text([if (date.isNotEmpty) date, if (city.isNotEmpty) city].join(' • '), style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 3),
            Text('$count combat${count > 1 ? 's' : ''}${titles > 0 ? ' • $titles titre${titles > 1 ? 's' : ''} en jeu' : ''}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.white24),
        ]),
      ),
    );
  }

  String _fighterName(Map<String, dynamic> fighter) {
    final first = (fighter['first_name'] ?? '').toString().trim();
    final last = (fighter['last_name'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    final nickname = (fighter['nickname'] ?? '').toString().trim();
    return nickname;
  }

  String _formatDate(String raw) {
    final dt=DateTime.tryParse(raw);
    if(dt==null) return raw;
    final local=dt.toLocal();
    final d='${local.day.toString().padLeft(2,'0')}/${local.month.toString().padLeft(2,'0')}/${local.year}';
    return 'Combat prévu le $d';
  }

  Widget _fightCard(Map<String, dynamic> fight) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FightDetailScreen(fight: fight))),
    child: _fightCardBody(fight),
  );

  Widget _fightCardBody(Map<String, dynamic> fight) {
    final event = Map<String, dynamic>.from(fight['events'] ?? {});
    final competition = Map<String, dynamic>.from(fight['competition'] ?? {});
    final a = Map<String, dynamic>.from(fight['fighter_a'] ?? {});
    final b = Map<String, dynamic>.from(fight['fighter_b'] ?? {});
    final weight = Map<String, dynamic>.from(fight['weight_category'] ?? {});
    final nameA = _fighterName(a);
    final nameB = _fighterName(b);
    return AmlCardBackdrop(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      radius: 20,
      color: _surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _blue.withOpacity(.12), borderRadius: BorderRadius.circular(7)), child: Text(competition['name']?.toString() ?? 'MMA', style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          Expanded(child: Text(event['name']?.toString() ?? 'Événement', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700))),
          if (fight['title_bout'] == true) const Icon(Icons.workspace_premium, color: Colors.amber, size: 17),
        ]),
        if ((event['starts_at']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(_formatDate(event['starts_at'].toString()), style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
        if ((event['city']?.toString() ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(event['city'].toString(), style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ],
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _FighterTile(fighter: a, name: nameA, fighterId: fight['fighter_a_id']?.toString())),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('VS', style: TextStyle(color: _blue, fontSize: 14, fontWeight: FontWeight.w900))),
          Expanded(child: _FighterTile(fighter: b, name: nameB, right: true, fighterId: fight['fighter_b_id']?.toString())),
        ]),
        const SizedBox(height: 13),
        Row(children: [Icon(Icons.category_outlined, size: 15, color: Colors.white38), const SizedBox(width: 6), Text(weight['name']?.toString() ?? 'MMA', style: const TextStyle(color: Colors.white54, fontSize: 11)), const Spacer(), Text('${fight['scheduled_rounds'] ?? 3} rounds', style: const TextStyle(color: Colors.white54, fontSize: 11)),]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FightDetailScreen(fight: fight))),
          icon: const Icon(Icons.bolt, size: 18),
          label: const Text('Pronostiquer'),
          style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
        )),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(text, style: const TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
  );
}


class _Filter extends StatelessWidget { final String label; final bool selected; final VoidCallback onTap; const _Filter({required this.label, required this.selected, required this.onTap}); @override Widget build(BuildContext c) => GestureDetector(onTap:onTap,child:Container(margin:const EdgeInsets.only(right:8),padding:const EdgeInsets.symmetric(horizontal:15),alignment:Alignment.center,decoration:BoxDecoration(color:selected?_blue:const Color(0xFF111111),borderRadius:BorderRadius.circular(14),border:Border.all(color:selected?_blue:Colors.white10)),child:Text(label,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900,color:selected?Colors.white:Colors.white70)))); }
class _FighterTile extends StatelessWidget {
  final Map<String, dynamic> fighter;
  final String name;
  final bool right;
  final String? fighterId;
  const _FighterTile({required this.fighter, required this.name, this.right = false, this.fighterId});
  @override
  Widget build(BuildContext context) {
    final photo = fighter['photo_url']?.toString().trim() ?? '';
    final display = name.isEmpty ? 'Combattant à confirmer' : name;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: fighterId == null ? null : () => FighterProfileLoader.open(context, fighterId),
      child: Column(
      crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        AmlFaceAvatar(radius: 29, backgroundColor: const Color(0xFF202020), image: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null, child: photo.isEmpty ? const Icon(Icons.person_outline, color: Colors.white30, size: 28) : null),
        const SizedBox(height: 8),
        Text(display, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: right ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    ));
  }
}
