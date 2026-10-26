import 'package:flutter/material.dart';
import '../../services/notifications_repository.dart';
import '../messages/messages_screen.dart';
import '../community/community_screen.dart';
import '../../utils/aml_time.dart';
import '../profile/follow_requests_screen.dart';
import '../profile/my_badges_screen.dart';

const Color _nBlue = Color(0xFF00AEEF);
const Color _nBlack = Color(0xFF050505);
const Color _nSurface = Color(0xFF111111);

String _amlNotificationTime(dynamic value) => amlFormatDateTime(value);

class AmlNotificationsScreen extends StatefulWidget {
  const AmlNotificationsScreen({super.key});
  @override State<AmlNotificationsScreen> createState() => _AmlNotificationsScreenState();
}

class _AmlNotificationsScreenState extends State<AmlNotificationsScreen> {
  final repo = NotificationsRepository();
  List<Map<String, dynamic>> rows = [];
  bool loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await repo.list();
      if (mounted) setState(() { rows = data; loading = false; });
    } catch (e) {
      if (mounted) { setState(() => loading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    await repo.markRead(n['id'].toString());
    if (mounted) setState(() => n['is_read'] = true);
    final type = n['type']?.toString();
    final data = Map<String, dynamic>.from(n['data'] ?? {});
    if (type == 'private_message' && data['sender_id'] != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AmlMessageThreadScreen(otherUserId: data['sender_id'].toString(), profile: const {})));
    } else if (type == 'comment' || type == 'comment_reply' || type == 'new_post') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlCommunityScreen()));
    } else if (type == 'badge_earned') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlMyBadgesScreen()));
    } else if (type == 'follow_request') {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlFollowRequestsScreen()));
    } else if (type == 'follow_accepted' && data['user_id'] != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => AmlMessageThreadScreen(otherUserId: data['user_id'].toString(), profile: const {})));
    }
  }

  IconData _icon(String? type) => switch (type) {
    'private_message' => Icons.chat_bubble_outline,
    'comment_reply' => Icons.reply,
    'comment' => Icons.mode_comment_outlined,
    'follow_request' => Icons.person_add_alt_1_outlined,
    'badge_earned' => Icons.workspace_premium_outlined,
    'follow_accepted' => Icons.how_to_reg_outlined,
    'new_post' => Icons.dynamic_feed_outlined,
    _ => Icons.notifications_none,
  };

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _nBlack,
    appBar: AppBar(
      title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [IconButton(tooltip: 'Demandes de suivi', icon: const Icon(Icons.person_add_alt_1_outlined, color: _nBlue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlFollowRequestsScreen()))), TextButton(onPressed: () async { await repo.markAllRead(); if (mounted) setState(() { for (final x in rows) x['is_read'] = true; }); }, child: const Text('Tout lire', style: TextStyle(color: _nBlue)))],
    ),
    body: RefreshIndicator(
      color: _nBlue,
      onRefresh: _load,
      child: loading
        ? const Center(child: CircularProgressIndicator(color: _nBlue))
        : rows.isEmpty
          ? ListView(children: const [SizedBox(height: 180), Center(child: Text('Aucune notification.', style: TextStyle(color: Colors.white54)))])
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final n = rows[i]; final unread = n['is_read'] != true;
                return ListTile(
                  onTap: () => _open(n),
                  tileColor: unread ? _nBlue.withValues(alpha: .09) : _nSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  leading: CircleAvatar(backgroundColor: _nBlue.withValues(alpha: .14), child: Icon(_icon(n['type']?.toString()), color: _nBlue)),
                  title: Text(n['title']?.toString() ?? 'Notification AML', style: TextStyle(fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
                  subtitle: Text(
                    '${n['body']?.toString() ?? ''}${(n['created_at'] ?? '').toString().isNotEmpty ? '\n${_amlNotificationTime(n['created_at'])}' : ''}',
                    style: const TextStyle(color: Colors.white60, height: 1.3),
                  ),
                  trailing: unread ? const CircleAvatar(radius: 4, backgroundColor: _nBlue) : null,
                );
              },
            ),
    ),
  );
}
