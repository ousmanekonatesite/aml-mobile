import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileRepository {
  SupabaseClient? get client => SupabaseService.client;

  static String? _healedFor;

  Future<Map<String, dynamic>?> _selectMine(SupabaseClient c, String userId) => c
      .from('profiles')
      .select('id,username,first_name,last_name,phone,city,profile_type,avatar_url,role,is_verified')
      .eq('id', userId)
      .maybeSingle();

  /// Profil du membre connecté. Si les informations saisies à l'inscription n'ont pas
  /// encore été enregistrées (confirmation e-mail), elles sont reprises automatiquement
  /// depuis les données du compte : plus besoin de modifier son profil après la première connexion.
  Future<Map<String, dynamic>?> loadMine() async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return null;
    try {
      var row = await _selectMine(c, user.id);
      final incomplete = row == null ||
          (row['username'] ?? '').toString().isEmpty ||
          (row['first_name'] ?? '').toString().isEmpty;
      if (incomplete && await _healFromMetadata(user)) {
        row = await _selectMine(c, user.id);
      }
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _healFromMetadata(User user) async {
    if (_healedFor == user.id) return false;
    _healedFor = user.id;
    final m = user.userMetadata ?? const <String, dynamic>{};
    final username = (m['username'] ?? '').toString().trim();
    if (username.isEmpty) return false;
    try {
      await upsertProfile(
        firstName: (m['first_name'] ?? '').toString(),
        lastName: (m['last_name'] ?? '').toString(),
        username: username,
        phone: (m['phone'] ?? '').toString(),
        city: (m['city'] ?? '').toString(),
        profileType: (m['profile_type'] ?? 'fan').toString(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Photo choisie à l'inscription quand la session n'existait pas encore (confirmation e-mail).
  Future<void> applyPendingAvatar(String email) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('pending_avatar_path');
      final owner = prefs.getString('pending_avatar_email');
      if (path == null || owner != email.trim().toLowerCase()) return;
      final file = File(path);
      if (await file.exists()) {
        final url = await uploadAvatar(await file.readAsBytes(), 'jpg');
        if (url != null && url.isNotEmpty) {
          await c.from('profiles').update({'avatar_url': url}).eq('id', user.id);
        }
      }
      await prefs.remove('pending_avatar_path');
      await prefs.remove('pending_avatar_email');
    } catch (_) {}
  }

  Future<int> unreadNotifications() async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return 0;
    try {
      final rows = await c
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> upsertProfile({
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    required String city,
    required String profileType,
    String? avatarUrl,
  }) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return;

    await c.rpc('aml_upsert_my_profile', params: {
      'p_first_name': firstName.trim(),
      'p_last_name': lastName.trim(),
      'p_username': username.trim(),
      'p_phone': phone.trim(),
      'p_city': city.trim(),
      'p_profile_type': profileType.trim(),
      'p_avatar_url': avatarUrl?.trim(),
    });
  }

  Future<String?> uploadAvatar(List<int> bytes, String extension) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return null;

    final path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await c.storage.from('avatars').uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(upsert: false, contentType: 'image/jpeg'),
    );
    return '${c.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
