import 'package:flutter/material.dart';

class FighterFightDetailScreen extends StatelessWidget {
  final Map<String, dynamic> fighter;
  final Map<String, dynamic> fight;

  const FighterFightDetailScreen({
    super.key,
    required this.fighter,
    required this.fight,
  });

  @override
  Widget build(BuildContext context) {
    final isWin = fight['result'] == 'Victoire';
    final landed = fight['sigLanded'] as int;
    final attempted = fight['sigAttempted'] as int;
    final accuracy = attempted == 0 ? 0 : ((landed / attempted) * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text(
          'Détail du combat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fightHeader(isWin),
            const SizedBox(height: 18),
            _sectionTitle('Performance du combat'),
            const SizedBox(height: 10),
            _grid([
              _metric('Résultat', fight['result']),
              _metric('Méthode', fight['method']),
              _metric('Round', fight['round']),
              _metric('Temps', fight['time']),
              _metric('Date', fight['date']),
              _metric('Précision frappes', '$accuracy %'),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Frappes significatives'),
            const SizedBox(height: 10),
            _statGroup([
              _metric('Total', '${fight['sigLanded']} / ${fight['sigAttempted']}'),
              _metric('Tête', '${fight['headLanded']}'),
              _metric('Corps', '${fight['bodyLanded']}'),
              _metric('Jambes', '${fight['legLanded']}'),
              _metric('Knockdowns', '${fight['knockdowns']}'),
              _metric('Précision', '$accuracy %'),
            ]),
            const SizedBox(height: 14),
            _sectionTitle('Grappling'),
            const SizedBox(height: 10),
            _statGroup([
              _metric('Takedowns', '${fight['takedownLanded']} / ${fight['takedownAttempted']}'),
              _metric('Soumissions tentées', '${fight['submissionAttempts']}'),
              _metric('Temps de contrôle', fight['control']),
            ]),
            const SizedBox(height: 20),
            _sectionTitle('Combattants'),
            const SizedBox(height: 10),
            _fighterRow(fighter['name'], fighter['nickname'], true),
            _fighterRow(fight['opponent'], 'Adversaire', false),
          ],
        ),
      ),
    );
  }

  Widget _fightHeader(bool isWin) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fight['event'],
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isWin ? const Color(0xFF61D982) : Colors.white24).withOpacity(.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  fight['result'],
                  style: TextStyle(color: isWin ? const Color(0xFF61D982) : Colors.white70, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${fighter['name']}  vs  ${fight['opponent']}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            '${fight['method']} • ${fight['round']} • ${fight['time']}',
            style: const TextStyle(color: Color(0xFF00AEEF), fontSize: 12, fontWeight: FontWeight.w800),
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

  Widget _statGroup(List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.05)),
      ),
      child: _grid(items),
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _fighterRow(String name, String subtitle, bool highlighted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: highlighted ? const Color(0xFF00AEEF).withOpacity(.3) : Colors.white.withOpacity(.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.person, color: Colors.white38),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ),
          if (highlighted) const Icon(Icons.verified, color: Color(0xFF00AEEF), size: 18),
        ],
      ),
    );
  }
}
