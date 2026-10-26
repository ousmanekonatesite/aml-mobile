import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supabase_service.dart';
import '../../utils/aml_time.dart';
import '../predictions/predictions_screen.dart';
import '../fighters/fighter_profile_loader.dart';

const _fightBlue = Color(0xFF00AEEF);
const _fightSurface = Color(0xFF111111);

/// Page riche d'un combat : face-à-face, bilans, infos de la carte et pronostic
/// (vainqueur, méthode, round) directement intégré pour parier sans changer d'écran.
class FightDetailScreen extends StatefulWidget {
  final Map<String, dynamic> fight;
  const FightDetailScreen({super.key, required this.fight});
  @override
  State<FightDetailScreen> createState() => _FightDetailScreenState();
}

class _FightDetailScreenState extends State<FightDetailScreen> {
  final Map<String, Map<String, dynamic>> stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final client = SupabaseService.client;
    final ids = [widget.fight['fighter_a_id'], widget.fight['fighter_b_id']].whereType<String>().toList();
    if (client == null || ids.isEmpty) return;
    try {
      final rows = await client.from('fighter_stats').select('fighter_id,wins,losses,draws,ko_tko_wins,submission_wins,decision_wins').inFilter('fighter_id', ids);
      if (!mounted) return;
      setState(() {
        for (final r in List<Map<String, dynamic>>.from(rows)) {
          stats[r['fighter_id'].toString()] = r;
        }
      });
    } catch (_) {}
  }

  String _name(dynamic value) {
    if (value is! Map) return 'Combattant à confirmer';
    final first = (value['first_name'] ?? '').toString().trim();
    final last = (value['last_name'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    return (value['name'] ?? value['nickname'] ?? 'Combattant à confirmer').toString();
  }

  String _record(String? fighterId) {
    final s = fighterId == null ? null : stats[fighterId];
    if (s == null) return '';
    return '${s['wins'] ?? 0}V - ${s['losses'] ?? 0}D - ${s['draws'] ?? 0}N';
  }

  Widget _fighter(Map<String, dynamic>? fighter, String? fighterId, {required bool right}) {
    final photo = fighter?['photo_url']?.toString().trim() ?? '';
    final nickname = (fighter?['nickname'] ?? '').toString().trim();
    final record = _record(fighterId);
    final placeholder = Container(color: const Color(0xFF202020), child: const Center(child: Icon(Icons.person, size: 54, color: Colors.white24)));
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: fighterId == null ? null : () => FighterProfileLoader.open(context, fighterId),
        child: Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: photo.isEmpty
                ? placeholder
                : CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover, alignment: Alignment.topCenter, errorWidget: (_, __, ___) => placeholder),
          ),
        ),
        const SizedBox(height: 10),
        Text(_name(fighter), textAlign: right ? TextAlign.right : TextAlign.left, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        if (nickname.isNotEmpty) Text('« $nickname »', textAlign: right ? TextAlign.right : TextAlign.left, style: const TextStyle(color: _fightBlue, fontSize: 12, fontWeight: FontWeight.w700)),
        if (record.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(record, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        if (fighterId != null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Voir le profil ›', style: TextStyle(color: Color(0xFF00AEEF), fontSize: 11, fontWeight: FontWeight.w800))),
      ])),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.05), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: Colors.white54), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))]),
  );

  @override
  Widget build(BuildContext context) {
    final fight = widget.fight;
    final a = fight['fighter_a'] is Map ? Map<String, dynamic>.from(fight['fighter_a']) : null;
    final b = fight['fighter_b'] is Map ? Map<String, dynamic>.from(fight['fighter_b']) : null;
    final event = fight['events'] is Map ? Map<String, dynamic>.from(fight['events']) : <String, dynamic>{};
    final competition = fight['competition'] is Map ? Map<String, dynamic>.from(fight['competition']) : <String, dynamic>{};
    final weight = fight['weight_category'] is Map ? Map<String, dynamic>.from(fight['weight_category']) : <String, dynamic>{};
    final when = amlFormatDateTime(event['starts_at']);
    final city = (event['city'] ?? '').toString().trim();
    final fightId = fight['id']?.toString();
    final finished = fight['status'] == 'finished';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('Combat', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _fightSurface, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white12)),
          child: Column(children: [
            Text(competition['name']?.toString() ?? 'MMA', style: const TextStyle(color: _fightBlue, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(event['name']?.toString() ?? 'Événement AML', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            if (when.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(city.isEmpty ? when : '$when • $city', style: const TextStyle(color: Colors.white38, fontSize: 12))),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fighter(a, fight['fighter_a_id']?.toString(), right: false),
              const Padding(padding: EdgeInsets.fromLTRB(10, 60, 10, 0), child: Text('VS', style: TextStyle(color: _fightBlue, fontSize: 20, fontWeight: FontWeight.w900))),
              _fighter(b, fight['fighter_b_id']?.toString(), right: true),
            ]),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              _chip(Icons.category_outlined, (weight['name'] ?? 'MMA').toString()),
              _chip(Icons.timer_outlined, '${fight['scheduled_rounds'] ?? 3} rounds'),
              if (fight['title_bout'] == true) _chip(Icons.workspace_premium, 'Combat pour le titre'),
              if (finished && (fight['result'] ?? '').toString().isNotEmpty) _chip(Icons.flag_outlined, 'Résultat : ${fight['result']}'),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('PRONOSTIQUER', style: TextStyle(color: _fightBlue, letterSpacing: 1.2, fontWeight: FontWeight.w900, fontSize: 12)),
        const SizedBox(height: 12),
        if (finished)
          const Padding(padding: EdgeInsets.all(16), child: Text('Ce combat est terminé : les pronostics sont clos.', style: TextStyle(color: Colors.white54)))
        else
          AmlPredictionsScreen(fightId: fightId, embedded: true),
      ]),
    );
  }
}
