import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class NotificationsRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<List<Map<String, dynamic>>> list({int limit = 50}) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return [];
    final rows = await c
        .from('notifications')
        .select('id,type,title,body,data,is_read,created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<int> unreadCount() async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return 0;
    final rows = await c
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_read', false);
    return (rows as List).length;
  }

  Future<void> markRead(String id) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    await c.from('notifications').update({'is_read': true}).eq('id', id).eq('user_id', user.id);
  }

  Future<void> markAllRead() async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    await c.from('notifications').update({'is_read': true}).eq('user_id', user.id).eq('is_read', false);
  }
}
