import 'package:flutter/material.dart';
import '../../services/prediction_repository.dart';

const _statsBlue = Color(0xFF00AEEF);
const _statsSurface = Color(0xFF111111);

class PredictionStatsPanel extends StatefulWidget {
  final String predictionId;
  final bool compact;
  const PredictionStatsPanel({super.key, required this.predictionId, this.compact = false});
  @override State<PredictionStatsPanel> createState() => _PredictionStatsPanelState();
}

class _PredictionStatsPanelState extends State<PredictionStatsPanel> {
  late Future<Map<String, dynamic>> future;
  @override void initState() { super.initState(); future = PredictionRepository().stats(widget.predictionId); }
  @override Widget build(BuildContext context) => FutureBuilder<Map<String,dynamic>>(
    future: future,
    builder: (_, s) {
      if (s.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(color: _statsBlue));
      final data = s.data ?? {};
      final total = (data['participants'] as num?)?.toInt() ?? 0;
      final winner = List<Map<String,dynamic>>.from(data['winner'] ?? const []);
      final method = List<Map<String,dynamic>>.from(data['method'] ?? const []);
      final round = List<Map<String,dynamic>>.from(data['round'] ?? const []);
      if (widget.compact) return _compact(total, winner);
      return Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _statsSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.insights_outlined, color: _statsBlue, size: 18), const SizedBox(width: 7), const Expanded(child: Text('TENDANCES DES PRONOSTICS', style: TextStyle(color: _statsBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8))), Text('$total participants', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 12),
        _group('Vainqueur', winner, total),
        if (method.isNotEmpty) ...[const SizedBox(height: 10), _group('Méthode', method, total)],
        if (round.isNotEmpty) ...[const SizedBox(height: 10), _group('Round', round, total)],
        const SizedBox(height: 7),
        const Text('Statistiques agrégées des choix des utilisateurs.', style: TextStyle(color: Colors.white38, fontSize: 9)),
      ]));
    },
  );

  Widget _compact(int total, List<Map<String,dynamic>> winner) => Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: _statsSurface, borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white10)), child: Row(children: [const Icon(Icons.bar_chart_rounded, color: _statsBlue, size: 17), const SizedBox(width: 7), Expanded(child: Text('$total personnes ont pronostiqué', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))), if (winner.isNotEmpty) Text('${winner.first['percentage'] ?? 0}% sur ${winner.first['label'] ?? ''}', style: const TextStyle(color: _statsBlue, fontSize: 9, fontWeight: FontWeight.w900))]));

  Widget _group(String title, List<Map<String,dynamic>> rows, int total) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)), const SizedBox(height: 5), ...rows.map((r) { final pct = (r['percentage'] as num?)?.toDouble() ?? 0; return Padding(padding: const EdgeInsets.only(bottom: 5), child: Column(children: [Row(children: [Expanded(child: Text(r['label']?.toString() ?? 'Choix', style: const TextStyle(fontSize: 10))), Text('${r['count'] ?? 0} • ${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%', style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700))]), const SizedBox(height: 3), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct / 100, minHeight: 5, backgroundColor: Colors.white10, color: _statsBlue))])); }).toList()]);
}
