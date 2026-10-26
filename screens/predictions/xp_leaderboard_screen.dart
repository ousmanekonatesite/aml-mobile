import 'package:flutter/material.dart';
import '../../services/prediction_repository.dart';

const _blue = Color(0xFF00AEEF);

class AmlXpLeaderboardScreen extends StatefulWidget {
  const AmlXpLeaderboardScreen({super.key});
  @override State<AmlXpLeaderboardScreen> createState() => _AmlXpLeaderboardScreenState();
}

class _AmlXpLeaderboardScreenState extends State<AmlXpLeaderboardScreen> {
  final repo = PredictionRepository();
  bool loading = true;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await repo.leaderboard();
    if (!mounted) return;
    setState(() { rows = data; loading = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Classement XP', style: TextStyle(fontWeight: FontWeight.w900))),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: _blue))
        : rows.isEmpty
            ? const Center(child: Text('Le classement sera disponible dès les premiers XP.'))
            : RefreshIndicator(
                color: _blue,
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    final rank = i + 1;
                    final username = (row['username'] ?? row['full_name'] ?? 'Fan AML').toString();
                    final xp = ((row['xp'] as num?)?.toInt() ?? 0);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        SizedBox(width: 34, child: Text('$rank', style: TextStyle(color: rank <= 3 ? _blue : Colors.white54, fontSize: 18, fontWeight: FontWeight.w900))),
                        Expanded(child: Text(username, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text('$xp XP', style: const TextStyle(color: _blue, fontWeight: FontWeight.w900)),
                      ]),
                    );
                  },
                ),
              ),
  );
}
