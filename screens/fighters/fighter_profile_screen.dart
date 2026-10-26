import 'package:flutter/material.dart';
import 'fighter_card_screen.dart';
import '../../services/fighter_repository.dart';
import 'fighter_fight_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets_flag.dart';

class FighterProfileScreen extends StatefulWidget {
  final Map<String, dynamic> fighter;

  const FighterProfileScreen({
    super.key,
    required this.fighter,
  });

  @override
  State<FighterProfileScreen> createState() => _FighterProfileScreenState();
}

class _FighterProfileScreenState extends State<FighterProfileScreen> {
  bool historyLoading = true;
  List<Map<String, dynamic>> history = [];

  Map<String, dynamic> get fighter => widget.fighter;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final id = widget.fighter['id']?.toString() ?? '';
    if (id.isEmpty) { if (mounted) setState(() => historyLoading = false); return; }
    try {
      final data = await FighterRepository().getFightHistory(id);
      if (mounted) setState(() { history = data; historyLoading = false; });
    } catch (_) {
      if (mounted) setState(() => historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text(
          'Profil du combattant',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileHeader(),
            const SizedBox(height: 18),
            _sectionTitle('Fiche athlète'),
            const SizedBox(height: 10),
            _grid([
              _metric('Âge', fighter['age'] is num && fighter['age'] != 0 ? '${fighter['age']} ans' : '—'),
              _metric('Taille', fighter['height']),
              _metric('Allonge', fighter['reach']),
              _metric('Garde', fighter['stance']),
              _metric('Catégorie', fighter['category']),
              _metric('Style', fighter['style']),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Bilan professionnel'),
            const SizedBox(height: 10),
            Row(
              children: [
                _bigStat('Victoires', '${fighter['wins']}', Icons.emoji_events_outlined),
                _bigStat('Défaites', '${fighter['losses']}', Icons.trending_down),
                _bigStat('Nuls', '${fighter['draws']}', Icons.horizontal_rule),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _bigStat('KO / TKO', '${fighter['ko']}', Icons.flash_on_outlined),
                _bigStat('Soumissions', '${fighter['submissions']}', Icons.lock_outline),
                _bigStat('Décisions', '${fighter['decisions']}', Icons.gavel_outlined),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Statistiques de combat'),
            const SizedBox(height: 10),
            _statGroup('Frappe', [
              _metric('Combats', '${fighter['fights']}'),
              _metric('Coups significatifs', '${fighter['sigStrikesLanded']} / ${fighter['sigStrikes']}'),
              _metric('Knockdowns', '${fighter['knockdowns']}'),
              _metric('Tête', '${fighter['headStrikes']}'),
              _metric('Corps', '${fighter['bodyStrikes']}'),
              _metric('Jambes', '${fighter['legStrikes']}'),
            ]),
            const SizedBox(height: 12),
            _statGroup('Grappling', [
              _metric('Takedowns', '${fighter['takedownsLanded']} / ${fighter['takedowns']}'),
              _metric('Tentatives de soumission', '${fighter['subAttempts']}'),
              _metric('Temps de contrôle', fighter['controlTime']),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Performance'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.06)),
              ),
              child: Column(
                children: [
                  _performanceRow('Temps moyen de combat', fighter['avgFightTime']),
                  _performanceRow('Taux de victoire', _winRate()),
                  _performanceRow('Finitions', '${fighter['ko'] + fighter['submissions']}'),
                  _performanceRow('Club', fighter['club']),
                  _performanceRow('Ville', fighter['city']),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FighterCardScreen(fighter: fighter),
                    ),
                  );
                },
                icon: const Icon(Icons.badge_outlined),
                label: const Text('VOIR LA CARTE PROFESSIONNELLE + QR CODE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00AEEF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Historique AML'),
            const SizedBox(height: 6),
            const Text('Les combats affichés proviennent des données officielles enregistrées dans AML Arena.', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 10),
            if (historyLoading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF00AEEF))))
            else if (history.isEmpty)
              const _OfficialEmptyHistory()
            else
              _fightHistory(context),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF003B55), Color(0xFF111111)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00AEEF).withOpacity(.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF242424),
              border: Border.all(color: const Color(0xFF00AEEF), width: 2.5),
            ),
            child: (fighter['photo_url']?.toString().trim().isNotEmpty ?? false)
                ? ClipOval(child: CachedNetworkImage(imageUrl: fighter['photo_url'].toString(), width: 78, height: 78, fit: BoxFit.cover, alignment: Alignment.topCenter, errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white38, size: 42)))
                : const Icon(Icons.person, color: Colors.white38, size: 42),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fighter['name'], style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('"${fighter['nickname']}"', style: const TextStyle(color: Color(0xFF00AEEF), fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(mainAxisSize: MainAxisSize.min, children: [AmlFlag(code: fighter['countryCode']?.toString(), height: 13), const SizedBox(width: 7), Text('${fighter['countryName']}', style: const TextStyle(color: Colors.white70, fontSize: 12))]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900));

  Widget _grid(List<Widget> items) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.35,
      children: items,
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _bigStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF00AEEF), size: 18),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _statGroup(String title, List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF00AEEF), fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _grid(items),
      ]),
    );
  }

  Widget _performanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
      ]),
    );
  }

  String _winRate() {
    final fights = fighter['fights'] is num ? (fighter['fights'] as num).toInt() : 0;
    final wins = fighter['wins'] is num ? (fighter['wins'] as num).toInt() : 0;
    if (fights <= 0) return '—';
    return '${((wins / fights) * 100).round()} %';
  }

  Widget _fightHistory(BuildContext context) {
    return Column(children: history.map((fight) {
      final event = Map<String, dynamic>.from(fight['event'] ?? {});
      final opponent = Map<String, dynamic>.from(fight['opponent'] ?? {});
      final opponentName = '${opponent['first_name'] ?? ''} ${opponent['last_name'] ?? ''}'.trim();
      final isWin = fight['display_result'] == 'Victoire';
      final date = DateTime.tryParse(event['starts_at']?.toString() ?? '');
      final dateLabel = date == null ? 'Date officielle à venir' : '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
      return Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.05))),
        child: Row(children: [
          Container(width: 8, height: 58, decoration: BoxDecoration(color: isWin ? const Color(0xFF61D982) : Colors.white24, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event['name']?.toString() ?? 'Événement AML', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(opponentName.isEmpty ? 'Adversaire officiel à venir' : 'vs $opponentName', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 3),
            Text(dateLabel, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ])),
          Text(fight['display_result']?.toString() ?? 'Résultat officiel à venir', style: TextStyle(color: isWin ? const Color(0xFF61D982) : Colors.white60, fontWeight: FontWeight.w900, fontSize: 11)),
        ]),
      );
    }).toList());
  }
}

class _OfficialEmptyHistory extends StatelessWidget {
  const _OfficialEmptyHistory();
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.history, color: Colors.white30, size: 30), SizedBox(height: 8), Text('Historique officiel à venir', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Aucun combat officiel enregistré pour ce fighter.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11))]));
}
