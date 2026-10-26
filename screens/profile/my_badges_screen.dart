import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/xp_service.dart';

const _badgeBlue = Color(0xFF00AEEF);

class AmlMyBadgesScreen extends StatefulWidget {
  const AmlMyBadgesScreen({super.key});

  @override
  State<AmlMyBadgesScreen> createState() => _AmlMyBadgesScreenState();
}

class _AmlMyBadgesScreenState extends State<AmlMyBadgesScreen> {
  bool loading = true;
  int xp = 0;
  List<Map<String, dynamic>> badges = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    // Attribue les badges dont la condition est déjà remplie avant d'afficher la liste.
    try {
      await client.rpc('aml_check_my_badges');
    } catch (_) {}
    try {
      xp = await XpService.myXp();
    } catch (_) {}
    try {
      final r = await client.rpc('aml_my_badge_progress');
      if (r is List) badges = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final earned = badges.where((b) => b['earned'] == true).toList();
    final locked = badges.where((b) => b['earned'] != true).toList();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Mes badges & XP', style: TextStyle(fontWeight: FontWeight.w900))),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _badgeBlue))
          : RefreshIndicator(
              color: _badgeBlue,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00364A), Color(0xFF111111)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TA PROGRESSION AML', style: TextStyle(color: _badgeBlue, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text('$xp XP', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                        if (badges.isNotEmpty) Text('${earned.length} / ${badges.length} badges débloqués', style: const TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('BADGES OBTENUS', style: TextStyle(color: _badgeBlue, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (earned.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aucun badge obtenu pour le moment.', style: TextStyle(color: Colors.white60)),
                    ),
                  ...earned.map((b) => _BadgeRow(badge: b)),
                  const SizedBox(height: 20),
                  const Text('À DÉBLOQUER', style: TextStyle(color: _badgeBlue, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (badges.isEmpty)
                    const Text('Les badges seront bientôt disponibles.', style: TextStyle(color: Colors.white60)),
                  ...locked.map((b) => _BadgeRow(badge: b)),
                ],
              ),
            ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final Map<String, dynamic> badge;
  const _BadgeRow({required this.badge});

  @override
  Widget build(BuildContext context) {
    final earned = badge['earned'] == true;
    final emoji = (badge['icon_emoji'] ?? '').toString();
    final current = (badge['current_value'] as num?)?.toInt() ?? 0;
    final target = (badge['criteria_value'] as num?)?.toInt() ?? 1;
    final auto = badge['criteria_type'] != 'manual';
    final xpReward = (badge['xp_reward'] as num?)?.toInt() ?? 0;
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();
    return Opacity(
      opacity: earned ? 1 : .85,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14), border: Border.all(color: earned ? _badgeBlue.withOpacity(.4) : Colors.white10)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: earned ? _badgeBlue.withOpacity(.14) : Colors.white10, shape: BoxShape.circle),
              child: emoji.isNotEmpty
                  ? Text(emoji, style: TextStyle(fontSize: 24, color: earned ? null : Colors.white38))
                  : Icon(earned ? Icons.workspace_premium : Icons.lock_outline, color: earned ? _badgeBlue : Colors.white38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${badge['name'] ?? 'Badge AML'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text('${badge['description'] ?? ''}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  if (!earned && auto && target > 1) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white10, color: _badgeBlue),
                    ),
                    const SizedBox(height: 3),
                    Text('$current / $target', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ],
              ),
            ),
            if (xpReward > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('+$xpReward XP', style: TextStyle(color: earned ? _badgeBlue : Colors.white38, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }
}
