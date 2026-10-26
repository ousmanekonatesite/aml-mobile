import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class NotificationRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<List<Map<String,dynamic>>> list() async {
    final c = client; final user = c?.auth.currentUser;
    if (c == null || user == null) return [];
    final rows = await c.from('notifications').select('*').eq('user_id', user.id).order('created_at', ascending:false).limit(50);
    return rows.map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }

  Future<void> markRead(String id) async {
    final c = client; final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    await c.from('notifications').update({'is_read':true}).eq('id',id).eq('user_id',user.id);
  }

  Future<void> markAllRead() async {
    final c = client; final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    await c.from('notifications').update({'is_read':true}).eq('user_id',user.id).eq('is_read',false);
  }
}
