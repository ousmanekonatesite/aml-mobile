import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'follow_service.dart';

class MessagingRepository {
  SupabaseClient? get client => SupabaseService.client;

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : [];

  Future<Map<String, dynamic>?> profile(String userId) async {
    final c = client;
    if (c == null) return null;
    return c.from('profiles')
        .select('id,first_name,last_name,username,display_name,avatar_url')
        .eq('id', userId)
        .maybeSingle();
  }

  /// Abonnés mutuels (demande de suivi acceptée) : les seuls membres avec qui on peut s'écrire.
  Future<List<Map<String, dynamic>>> myFollowers() => FollowService.connections();

  Future<List<Map<String, dynamic>>> searchMembers(String query) async {
    final all = await FollowService.connections();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((m) {
      final hay = '${m['username'] ?? ''} ${m['first_name'] ?? ''} ${m['last_name'] ?? ''} ${m['display_name'] ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> inbox() async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return [];

    final rows = await c.from('direct_messages')
        .select('id,sender_id,receiver_id,body,created_at,read_at')
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .order('created_at', ascending: false)
        .limit(300);

    final grouped = <String, Map<String, dynamic>>{};
    for (final raw in _list(rows)) {
      final otherId = raw['sender_id']?.toString() == user.id
          ? raw['receiver_id']?.toString()
          : raw['sender_id']?.toString();
      if (otherId == null || otherId.isEmpty || grouped.containsKey(otherId)) continue;
      final p = await profile(otherId);
      grouped[otherId] = {
        'user_id': otherId,
        'profile': p ?? <String, dynamic>{},
        'last_message': raw,
        'unread': raw['receiver_id']?.toString() == user.id && raw['read_at'] == null,
      };
    }
    return grouped.values.toList();
  }

  Future<List<Map<String, dynamic>>> thread(String otherUserId) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return [];
    final rows = await c.from('direct_messages')
        .select('id,sender_id,receiver_id,body,created_at,read_at')
        .or('and(sender_id.eq.${user.id},receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.${user.id})')
        .order('created_at');
    return _list(rows);
  }

  Future<void> markThreadRead(String otherUserId) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    await c.from('direct_messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('receiver_id', user.id)
        .eq('sender_id', otherUserId)
        .isFilter('read_at', null);
  }

  Future<Map<String, dynamic>> send(String otherUserId, String body) async {
    final c = client;
    final user = c?.auth.currentUser;
    final text = body.trim();
    if (c == null || user == null) throw Exception('Connecte-toi pour envoyer un message.');
    if (text.isEmpty) throw Exception('Le message est vide.');
    try {
      final row = await c.from('direct_messages').insert({
        'sender_id': user.id,
        'receiver_id': otherUserId,
        'body': text,
      }).select('id,sender_id,receiver_id,body,created_at,read_at').single();
      return Map<String, dynamic>.from(row);
    } catch (e) {
      final t = e.toString();
      if (t.contains('42501') || t.contains('row-level security') || t.contains('NOT_CONNECTED')) {
        throw Exception('Vous devez vous suivre mutuellement pour vous écrire. Envoie une demande de suivi depuis son profil.');
      }
      rethrow;
    }
  }

  // Compatibilité avec les anciennes pages qui démarraient une conversation par RPC.
  Future<String> startConversation(String otherUserId) async => otherUserId;

  Future<List<Map<String, dynamic>>> messages(String conversationId) async => thread(conversationId);
}
