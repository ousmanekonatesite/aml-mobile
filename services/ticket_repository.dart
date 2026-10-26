import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class TicketRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<Map<String, dynamic>> buyTicket(String offerId, {int quantity = 1}) async {
    final c = client;
    if (c == null || c.auth.currentUser == null) throw Exception('Connexion requise.');
    final result = await c.rpc('aml_buy_event_ticket', params: {'p_offer_id': offerId, 'p_quantity': quantity});
    if (result is List && result.isNotEmpty) return Map<String, dynamic>.from(result.first as Map);
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('Réponse d’achat invalide.');
  }


  Future<Map<String, dynamic>> redeemTicket(String rawCode, {String mode = 'auto'}) async {
    final c = client;
    if (c == null || c.auth.currentUser == null) throw Exception('Connexion requise.');
    final code = rawCode.trim().replaceFirst(RegExp(r'^AML-TICKET:', caseSensitive: false), '');
    if (code.isEmpty) throw Exception('Code de ticket vide.');
    final result = await c.rpc('aml_redeem_event_ticket', params: {'p_ticket_code': code, 'p_mode': mode});
    if (result is List && result.isNotEmpty) return Map<String, dynamic>.from(result.first as Map);
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('Réponse de validation invalide.');
  }

  Future<List<Map<String, dynamic>>> adminTickets({String? status}) async {
    final c = client;
    if (c == null || c.auth.currentUser == null) throw Exception('Connexion requise.');
    var query = c.from('user_event_tickets').select(
      'id,user_id,event_id,ticket_code,quantity,status,is_inside,entry_count,purchased_at,amount_credits,offer_id,event:events(name,starts_at,venue_name,city)'
    );
    if (status != null && status != 'all') query = query.eq('status', status);
    final rows = await query.order('purchased_at', ascending: false).limit(300);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> upcomingEvents() async {
    final c = client;
    if (c == null) return [];
    final rows = await c
        .from('events')
        .select('id,name,slug,description,venue_name,city,country_code,starts_at,poster_url,cover_url,competition_id,status')
        .inFilter('status', ['scheduled', 'published'])
        .not('starts_at', 'is', null)
        .order('starts_at')
        .limit(30);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> competition(String id) async {
    final c = client;
    if (c == null || id.isEmpty) return null;
    try {
      return await c.from('competitions').select('id,name,logo_url,country_code').eq('id', id).maybeSingle();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> offersForEvent(String eventId) async {
    final c = client;
    if (c == null || eventId.isEmpty) return [];
    try {
      final rows = await c
          .from('event_ticket_offers')
          .select('id,event_id,name,description,price_xof,currency,stock_remaining,sales_status,purchase_url,sort_order')
          .eq('event_id', eventId)
          .eq('sales_status', 'on_sale')
          .order('sort_order')
          .order('price_xof');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> eventsWithOffers() async {
    final events = await upcomingEvents();
    final datedEvents = events.where((event) => DateTime.tryParse(event['starts_at']?.toString() ?? '') != null).toList();
    for (final event in datedEvents) {
      final id = event['id']?.toString() ?? '';
      event['ticket_offers'] = await offersForEvent(id);
    }
    return datedEvents;
  }
}
