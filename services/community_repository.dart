import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'follow_service.dart';

class CommunityRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<Map<String, dynamic>?> _publicProfile(String userId) async {
    final c = client;
    if (c == null) return null;
    try {
      final rows = await c.rpc('aml_public_profile', params: {'p_user_id': userId});
      if (rows is List && rows.isNotEmpty) return Map<String, dynamic>.from(rows.first as Map);
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>> uploadCommunityImage({required Uint8List bytes, required String fileName}) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi pour envoyer une image.');
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await c.storage.from('community-media').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: 'image/jpeg', upsert: false),
    );
    return {
      'url': c.storage.from('community-media').getPublicUrl(path),
      'storage_path': path,
    };
  }

  /// Envoie une vidéo (3 minutes et 50 Mo maximum, contrôlés par l'application et le stockage).
  Future<Map<String, String>> uploadCommunityVideo({required File file, required String fileName}) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi pour envoyer une vidéo.');
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final lower = safeName.toLowerCase();
    final type = lower.endsWith('.mov') ? 'video/quicktime' : lower.endsWith('.webm') ? 'video/webm' : lower.endsWith('.3gp') ? 'video/3gpp' : 'video/mp4';
    final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await c.storage.from('community-media').upload(path, file, fileOptions: FileOptions(contentType: type, upsert: false));
    return {
      'url': c.storage.from('community-media').getPublicUrl(path),
      'storage_path': path,
      'type': 'video',
    };
  }

  List<Map<String, dynamic>> _jsonList(dynamic value) {
    if (value is! List) return [];
    return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> posts() async {
    final c = client;
    if (c == null) return [];
    final raw = await c.rpc('aml_community_feed', params: {'p_limit': 30, 'p_post_id': null});
    return _jsonList(raw);
  }

  Future<Map<String, dynamic>> postById(String postId) async {
    final c = client;
    if (c == null) throw Exception('Supabase non disponible.');
    final raw = await c.rpc('aml_community_feed', params: {'p_limit': 1, 'p_post_id': postId});
    final rows = _jsonList(raw);
    if (rows.isEmpty) throw Exception('Publication introuvable.');
    return rows.first;
  }

  Future<Map<String, dynamic>> createPost(String content, {List<Map<String, String>> media = const [], String? backgroundKey}) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi pour publier.');
    final inserted = await c.from('posts').insert({
      'author_id': user.id,
      'content': content.trim(),
      if (backgroundKey != null && backgroundKey.isNotEmpty && media.isEmpty) 'background_key': backgroundKey,
    }).select('id').single();
    final postId = inserted['id'].toString();
    if (media.isNotEmpty) {
      await c.from('post_media').insert(media.map((m) => {
        'post_id': postId,
        'media_url': m['url'],
        'storage_path': m['storage_path'],
        'media_type': m['type'] == 'video' ? 'video' : 'image',
        if (m['type'] == 'video' && m['duration_seconds'] != null) 'duration_seconds': int.tryParse(m['duration_seconds']!),
      }).toList());
    }
    return postById(postId);
  }

  /// Réaction d'un membre sur une publication (null = retirer sa réaction).
  Future<void> setReaction(String postId, String? reaction) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi pour réagir à une publication.');
    if (reaction == null) {
      await c.from('post_reactions').delete().eq('post_id', postId).eq('user_id', user.id);
      return;
    }
    await c.from('post_reactions').upsert({
      'post_id': postId,
      'user_id': user.id,
      'reaction': reaction,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'post_id,user_id');
  }

  Future<bool> toggleLike(String postId, bool currentlyLiked) async {
    await setReaction(postId, currentlyLiked ? null : 'love');
    return !currentlyLiked;
  }

  Future<List<Map<String, dynamic>>> comments(String postId) async {
    final c = client;
    if (c == null) return [];
    final raw = await c.rpc('aml_post_comments', params: {'p_post_id': postId});
    final rows = _jsonList(raw);
    if (rows.isEmpty) return rows;

    // The RPC returns the comment rows, but depending on the database version
    // it may not include the related profile object. Enrich every comment from
    // the existing profiles table so replies always display the real author.
    final authorIds = rows
        .map((r) => r['author_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (authorIds.isEmpty) return rows;

    try {
      final profiles = await c
          .from('profiles')
          .select('id,first_name,last_name,username,display_name,avatar_url')
          .inFilter('id', authorIds);
      final byId = <String, Map<String, dynamic>>{
        for (final p in List<Map<String, dynamic>>.from(profiles))
          p['id'].toString(): p,
      };
      for (final row in rows) {
        final id = row['author_id']?.toString();
        final profile = id == null ? null : byId[id];
        if (profile != null) row['author_profile'] = profile;
      }
    } catch (_) {
      // Keep the comments usable if profile enrichment is temporarily blocked
      // by an RLS/schema difference. The UI still has its safe fallback.
    }
    return rows;
  }

  Future<Map<String, dynamic>> addComment(
    String postId,
    String content, {
    String? parentCommentId,
    List<Map<String, String>> media = const [],
  }) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi pour commenter.');
    dynamic result;
    try {
      result = await c.rpc('aml_add_comment', params: {
        'p_post_id': postId,
        'p_body': content.trim(),
        'p_parent_comment_id': parentCommentId,
      });
    } catch (e) {
      // Compatibility with databases where the RPC has not been deployed yet.
      final message = e.toString();
      if (!message.contains('aml_add_comment') && !message.contains('PGRST202')) rethrow;
      result = await c.from('comments').insert({
        'post_id': postId,
        'author_id': user.id,
        'body': content.trim(),
        'parent_comment_id': parentCommentId,
      }).select('*').single();
    }
    final created = Map<String, dynamic>.from(result as Map);
    final commentId = created['id'].toString();
    if (media.isNotEmpty) {
      await c.from('comment_media').insert(media.map((m) => {
        'comment_id': commentId,
        'media_url': m['url'],
        'storage_path': m['storage_path'],
        'media_type': 'image',
      }).toList());
    }
    if (media.isNotEmpty) {
      final rows = await comments(postId);
      return rows.firstWhere((x) => x['id'].toString() == commentId, orElse: () => created);
    }
    return created;
  }

  /// Suivi validé : none -> demande envoyée, pending_out -> annule, pending_in -> accepte.
  /// Retourne le nouvel état (none | pending_out | connected).
  Future<String> followAction(String authorId, String status) async {
    final c = client; final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi pour suivre ce membre.');
    if (authorId == user.id) return 'none';
    switch (status) {
      case 'pending_out':
        await FollowService.cancel(authorId);
        return 'none';
      case 'pending_in':
        final st = await FollowService.status(authorId);
        final id = st['request_id']?.toString();
        if (id == null) return st['status']?.toString() ?? 'none';
        await FollowService.respond(id, true);
        return 'connected';
      case 'connected':
        return 'connected';
      default:
        return FollowService.request(authorId);
    }
  }

  Future<bool> toggleFollow(String authorId, bool following) async =>
      (await followAction(authorId, following ? 'connected' : 'none')) == 'connected';

  Future<bool> toggleBookmark(String postId, bool saved) async {
    final c = client; final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi pour enregistrer une publication.');
    if (saved) {
      await c.from('bookmarks').delete().eq('user_id', user.id).eq('post_id', postId);
      return false;
    }
    await c.from('bookmarks').insert({'user_id': user.id, 'post_id': postId});
    return true;
  }

  Future<void> deletePost(String postId) async {
    final c = client; final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi.');
    await c.from('posts').delete().eq('id', postId).eq('author_id', user.id);
  }

  Future<void> deleteComment(String commentId) async {
    final c = client; final user = c?.auth.currentUser;
    if (c == null || user == null) throw Exception('Connecte-toi.');
    await c.from('comments').delete().eq('id', commentId).eq('author_id', user.id);
  }
}
