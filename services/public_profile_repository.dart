import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'follow_service.dart';

class PublicProfileRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<Map<String, dynamic>?> load(String userId) async {
    final c = client;
    if (c == null) return null;
    try {
      final rows = await c.rpc('aml_public_profile', params: {'p_user_id': userId});
      if (rows is List && rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, int>> counts(String userId) async {
    final c = client;
    if (c == null) return {'followers': 0, 'following': 0, 'posts': 0};
    try {
      final followers = await c.from('follows').select('follower_id').eq('following_id', userId);
      final following = await c.from('follows').select('following_id').eq('follower_id', userId);
      final posts = await c.from('posts').select('id').eq('author_id', userId);
      return {
        'followers': (followers as List).length,
        'following': (following as List).length,
        'posts': (posts as List).length,
      };
    } catch (_) {
      return {'followers': 0, 'following': 0, 'posts': 0};
    }
  }

  Future<List<Map<String, dynamic>>> posts(String userId) async {
    final c = client;
    if (c == null) return [];
    try {
      final rows = await c
          .from('posts')
          .select('id,content,created_at')
          .eq('author_id', userId)
          .order('created_at', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  Future<bool> isFollowing(String userId) async {
    final c = client;
    final me = c?.auth.currentUser;
    if (c == null || me == null || me.id == userId) return false;
    try {
      final row = await c
          .from('follows')
          .select('follower_id')
          .eq('follower_id', me.id)
          .eq('following_id', userId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Envoie une demande de suivi ; retourne true si les deux membres se suivent déjà.
  Future<bool> toggleFollow(String userId, bool following) async {
    final c = client;
    final me = c?.auth.currentUser;
    if (c == null || me == null) throw Exception('Connecte-toi pour suivre ce membre.');
    if (me.id == userId) return false;
    if (following) {
      await FollowService.remove(userId);
      return false;
    }
    return (await FollowService.request(userId)) == 'connected';
  }
}
