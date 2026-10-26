import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AdminRepository {
  SupabaseClient? get _client => SupabaseService.client;

  Future<bool> isAuthorizedAdmin() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return false;
    try {
      final result = await client.rpc('aml_is_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureAdmin() async {
    if (!await isAuthorizedAdmin()) {
      throw Exception('Accès administrateur refusé.');
    }
  }

  Future<Map<String, dynamic>?> currentStaffProfile() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    final row = await client
        .from('profiles')
        .select('id,display_name,username,role,is_suspended')
        .eq('id', user.id)
        .maybeSingle();
    return row;
  }

  Future<List<Map<String, dynamic>>> adminUsers({String search = ''}) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final result = await client.rpc('aml_admin_list_users', params: {'p_search': search.trim()});
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> updateUserProfile(String userId, String displayName, String username) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.rpc('aml_admin_update_user_profile', params: {
      'p_user_id': userId, 'p_display_name': displayName, 'p_username': username,
    });
  }

  Future<void> deleteUser(String userId) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.rpc('aml_admin_delete_user', params: {'p_user_id': userId});
  }

  Future<void> setUserRole(String userId, String role) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.rpc('aml_admin_set_user_role', params: {'p_user_id': userId, 'p_role': role});
  }

  Future<void> setUserSuspended(String userId, bool suspended) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.rpc('aml_admin_set_user_suspended', params: {'p_user_id': userId, 'p_suspended': suspended});
  }

  Future<void> adjustUserWallet(String userId, int credits, int xp, String reason) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.rpc('aml_admin_adjust_user_balances', params: {
      'p_user_id': userId, 'p_credits': credits, 'p_xp': xp, 'p_reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> recentOrders() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client
        .from('orders')
        .select('id,user_id,status,total_amount,currency,subtotal,shipping_amount,shipping_name,shipping_phone,shipping_address,shipping_city,created_at,payment_status,payment_method,payment_reference')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> updateOrderPaymentStatus(String orderId, String status) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('orders').update({'payment_status': status}).eq('id', orderId);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('orders').update({'status': status}).eq('id', orderId);
  }

  Future<int> count(String table) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return 0;
    final response = await client.from(table).select('id');
    return (response as List).length;
  }

  Future<List<Map<String, dynamic>>> productCategories() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('product_categories').select('id,name,slug').order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveProduct(Map<String, dynamic> data, String? id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    if (id == null) {
      await client.from('products').insert(data);
    } else {
      await client.from('products').update(data).eq('id', id);
    }
  }

  Future<void> deleteProduct(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('products').delete().eq('id', id);
  }

  Future<void> saveProductCategory(Map<String, dynamic> data, String? id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    if (id == null) await client.from('product_categories').insert(data);
    else await client.from('product_categories').update(data).eq('id', id);
  }

  Future<void> deleteProductCategory(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('product_categories').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> recentProducts() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client
        .from('products')
        .select('id,category_id,name,slug,description,price,currency,stock_quantity,cover_image_path,is_active,is_drop,created_at')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }


  Future<List<Map<String, dynamic>>> adminTicketOffers() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('event_ticket_offers').select('id,event_id,name,description,price_xof,currency,stock_remaining,sales_status,purchase_url,sort_order,created_at,updated_at').order('sort_order').order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveTicketOffer(Map<String, dynamic> data, String? id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    if (id == null) {
      await client.from('event_ticket_offers').insert(data);
    } else {
      await client.from('event_ticket_offers').update(data).eq('id', id);
    }
  }

  Future<void> deleteTicketOffer(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('event_ticket_offers').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> adminEvents() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('events').select('id,name,slug,description,venue_name,city,country_code,starts_at,poster_url,cover_url,status,competition_id,created_at').order('starts_at', ascending: false, nullsFirst: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> adminCompetitions() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('competitions').select('id,name,slug,is_aml,is_active').eq('is_active', true).order('name');
    final list = List<Map<String, dynamic>>.from(rows);
    list.sort((a, b) {
      if ((a['is_aml'] == true) != (b['is_aml'] == true)) return a['is_aml'] == true ? -1 : 1;
      return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
    });
    return list;
  }

  Future<void> saveEvent(Map<String, dynamic> data, String? id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    if (id == null) {
      await client.from('events').insert(data);
    } else {
      await client.from('events').update(data).eq('id', id);
    }
  }

  Future<void> deleteEvent(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('events').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> adminFights(String eventId) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('fights').select('id,event_id,fighter_a_id,fighter_b_id,weight_category_id,bout_order,scheduled_rounds,title_bout,status,winner_fighter_id,result,finish_round,finish_time,decision_type').eq('event_id', eventId).order('bout_order', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> adminFighters() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('fighters').select('id,first_name,last_name,nickname,is_active').eq('is_active', true).order('last_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> adminWeightCategories() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('weight_categories').select('id,name').order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveWeightCategory(String name) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('weight_categories').insert({'name': name.trim()});
  }

  Future<void> saveFight(Map<String, dynamic> data, String? id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    if (id == null) {
      await client.from('fights').insert(data);
    } else {
      await client.from('fights').update(data).eq('id', id);
    }
  }

  Future<void> deleteFight(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('fights').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> adminVideos() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client
        .from('videos')
        .select('id,title,slug,description,storage_path,thumbnail_path,external_url,duration_seconds,category_id,event_id,status,is_featured,published_at,created_at')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> adminVideoCategories() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('video_categories').select('id,name,slug').order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveVideo(Map<String, dynamic> data, String? id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    if (id == null) {
      await client.from('videos').insert(data);
    } else {
      await client.from('videos').update(data).eq('id', id);
    }
  }

  Future<void> toggleVideoPublished(String id, bool value) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('videos').update({
      'status': value ? 'published' : 'draft',
      'published_at': value ? DateTime.now().toIso8601String() : null,
    }).eq('id', id);
  }

  Future<void> deleteVideo(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('videos').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> xpRules() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client
        .from('xp_rules')
        .select('code,label,description,points,is_active,sort_order,updated_at')
        .order('sort_order')
        .order('label');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveXpRule({
    required String code,
    required String label,
    required String? description,
    required int points,
    required bool isActive,
  }) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('xp_rules').update({
      'label': label,
      'description': description,
      'points': points,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('code', code);
  }

  Future<List<Map<String, dynamic>>> predictionQuestionsAdmin() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('prediction_questions').select(
      'id,title,question_type,lock_at,status,fight_id,xp_participation,xp_winner,xp_method,xp_round,xp_exact,result_winner_option_id,result_method_option_id,result_round_option_id,settled_at,prediction_options(id,label,option_type,option_value,is_correct)'
    ).order('lock_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> predictionOptionsAdmin(String predictionId) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('prediction_options').select('*').eq('prediction_id', predictionId).order('option_type').order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> savePredictionQuestion(Map<String, dynamic> data, String? id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    if (id == null) {
      await client.from('prediction_questions').insert(data);
    } else {
      await client.from('prediction_questions').update(data).eq('id', id);
    }
  }

  Future<void> deletePredictionQuestion(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('prediction_questions').delete().eq('id', id);
  }

  Future<void> savePredictionOption(Map<String, dynamic> data, String? id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    if (id == null) await client.from('prediction_options').insert(data);
    else await client.from('prediction_options').update(data).eq('id', id);
  }

  Future<void> deletePredictionOption(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('prediction_options').delete().eq('id', id);
  }

  Future<void> updatePredictionXp({
    required String predictionId,
    required int participation,
    required int winner,
    required int method,
    required int round,
    required int exact,
  }) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('prediction_questions').update({
      'xp_participation': participation,
      'xp_winner': winner,
      'xp_method': method,
      'xp_round': round,
      'xp_exact': exact,
    }).eq('id', predictionId);
  }

  Future<void> confirmPredictionResult({
    required String predictionId,
    required String winnerOptionId,
    String? methodOptionId,
    String? roundOptionId,
  }) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.rpc('aml_confirm_prediction_result', params: {
      'p_prediction_id': predictionId,
      'p_winner_option_id': winnerOptionId,
      'p_method_option_id': methodOptionId,
      'p_round_option_id': roundOptionId,
    });
  }


  Future<Map<String, dynamic>> homeSettings() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return const {};
    final row = await client.from('app_home_settings').select('*').eq('id', true).maybeSingle();
    return row == null ? const {} : Map<String, dynamic>.from(row);
  }

  Future<void> saveHomeSettings(Map<String, dynamic> data) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('app_home_settings').upsert({'id': true, ...data, 'updated_at': DateTime.now().toIso8601String()});
  }

  Future<List<Map<String, dynamic>>> homeSectionsAdmin() async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) return [];
    final rows = await client.from('app_home_sections').select('*').order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> saveHomeSection(String id, Map<String, dynamic> data) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('app_home_sections').update({...data, 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<void> createHomeSection(Map<String, dynamic> data) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('app_home_sections').insert({...data, 'updated_at': DateTime.now().toIso8601String()});
  }

  Future<void> deleteHomeSection(String id) async {
    await _ensureAdmin();
    final client = _client;
    if (client == null) throw Exception('Supabase non configuré');
    await client.from('app_home_sections').delete().eq('id', id);
  }

}
