import 'supabase_service.dart';

/// Suivi validé : une demande de suivi doit être acceptée par l'autre membre.
/// Une fois acceptée, les deux membres se suivent (abonnés mutuels) et peuvent
/// s'écrire en privé et être notifiés de leurs publications.
class FollowService {
  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];

  static Exception _friendly(Object e) {
    final t = e.toString();
    if (t.contains('AUTH_REQUIRED')) return Exception('Connecte-toi pour suivre ce membre.');
    if (t.contains('USER_NOT_FOUND')) return Exception('Ce membre est introuvable.');
    if (t.contains('INVALID_TARGET')) return Exception('Action impossible sur ton propre profil.');
    if (t.contains('REQUEST_NOT_FOUND')) return Exception('Cette demande n’existe plus.');
    return Exception('Action impossible pour le moment. Réessaie dans un instant.');
  }

  /// {status: none | pending_out | pending_in | connected, request_id?}
  static Future<Map<String, dynamic>> status(String otherId) async {
    final c = SupabaseService.client;
    if (c == null || c.auth.currentUser == null) return {'status': 'none'};
    try {
      final r = await c.rpc('aml_follow_status', params: {'p_other': otherId});
      if (r is Map) return Map<String, dynamic>.from(r);
    } catch (_) {}
    return {'status': 'none'};
  }

  /// Retourne `pending_out` (demande envoyée) ou `connected` (l'autre avait déjà demandé).
  static Future<String> request(String targetId) async {
    final c = SupabaseService.client;
    if (c == null || c.auth.currentUser == null) throw Exception('Connecte-toi pour suivre ce membre.');
    try {
      final r = await c.rpc('aml_follow_request', params: {'p_target': targetId});
      return r.toString();
    } catch (e) {
      throw _friendly(e);
    }
  }

  static Future<void> cancel(String targetId) async {
    try {
      await SupabaseService.client!.rpc('aml_cancel_follow_request', params: {'p_target': targetId});
    } catch (e) {
      throw _friendly(e);
    }
  }

  static Future<String> respond(String requestId, bool accept) async {
    try {
      final r = await SupabaseService.client!.rpc('aml_respond_follow_request', params: {'p_request_id': requestId, 'p_accept': accept});
      return r.toString();
    } catch (e) {
      throw _friendly(e);
    }
  }

  static Future<void> remove(String otherId) async {
    try {
      await SupabaseService.client!.rpc('aml_remove_connection', params: {'p_other': otherId});
    } catch (e) {
      throw _friendly(e);
    }
  }

  static Future<List<Map<String, dynamic>>> incoming() async {
    final c = SupabaseService.client;
    if (c == null || c.auth.currentUser == null) return [];
    try {
      return _list(await c.rpc('aml_follow_requests_incoming'));
    } catch (_) {
      return [];
    }
  }

  /// Abonnés mutuels : les seuls membres avec qui on peut échanger en privé.
  static Future<List<Map<String, dynamic>>> connections() async {
    final c = SupabaseService.client;
    if (c == null || c.auth.currentUser == null) return [];
    try {
      return _list(await c.rpc('aml_connections'));
    } catch (_) {
      return [];
    }
  }
}
