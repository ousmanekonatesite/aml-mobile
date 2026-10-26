import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'xp_service.dart';
import 'media_rights.dart';

class PredictionRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<List<Map<String, dynamic>>> upcoming({String? fightId}) async {
    final items = await _upcomingRaw(fightId: fightId);
    if (items.isNotEmpty || fightId == null || fightId.isEmpty) return items;
    // Combat sans pronostic : le serveur le crée automatiquement (vainqueur, méthode, round).
    try {
      await client?.rpc('aml_ensure_fight_prediction', params: {'p_fight_id': fightId});
      return await _upcomingRaw(fightId: fightId);
    } catch (_) {
      return items;
    }
  }

  Future<List<Map<String, dynamic>>> _upcomingRaw({String? fightId}) async {
    final c = client;
    if (c == null) return const [];

    final questions = await c
        .from('prediction_questions')
        .select(
          'id,title,question_type,lock_at,status,fight_id,'
          'xp_participation,xp_winner,xp_method,xp_round,xp_exact,'
          'prediction_options(id,label,option_type,option_value,is_correct)',
        )
        .eq('status', 'open')
        .order('lock_at');

    var items = List<Map<String, dynamic>>.from(questions);
    if (fightId != null && fightId.isNotEmpty) {
      items = items.where((item) => item['fight_id']?.toString() == fightId).toList();
    }
    if (items.isEmpty) return items;

    final fightIds = items
        .map((e) => e['fight_id'])
        .whereType<String>()
        .toList();
    if (fightIds.isEmpty) return items;

    final fights = await c
        .from('fights')
        .select(
          'id,scheduled_rounds,title_bout,bout_order,'
          'fighter_a_id,fighter_b_id,'
          'external_fighter_a_id,external_fighter_b_id,event_id',
        )
        .inFilter('id', fightIds);

    final fightMap = <String, Map<String, dynamic>>{};
    final externalIds = <String>{};
    final internalIds = <String>{};
    final eventIds = <String>{};

    for (final raw in fights) {
      final fight = Map<String, dynamic>.from(raw);
      fightMap[fight['id'].toString()] = fight;
      final a = fight['external_fighter_a_id']?.toString();
      final b = fight['external_fighter_b_id']?.toString();
      final event = fight['event_id']?.toString();
      if (a != null) externalIds.add(a);
      if (b != null) externalIds.add(b);
      final ia = fight['fighter_a_id']?.toString();
      final ib = fight['fighter_b_id']?.toString();
      if (ia != null) internalIds.add(ia);
      if (ib != null) internalIds.add(ib);
      if (event != null) eventIds.add(event);
    }

    final externalMap = <String, Map<String, dynamic>>{};
    if (externalIds.isNotEmpty) {
      final fighters = await c
          .from('external_fighters')
          .select(
            'id,first_name,last_name,nickname,photo_url,country_code,weight_category,rights_status,rights_expires_at',
          )
          .inFilter('id', externalIds.toList());
      for (final raw in fighters) {
        final fighter = Map<String, dynamic>.from(raw);
        redactExternalFighterPhoto(fighter);
        externalMap[fighter['id'].toString()] = fighter;
      }
    }

    // Combattants AML (table fighters) : avant, seuls les combattants externes étaient chargés,
    // donc aucune photo ni aucun nom n'apparaissait sur les pronostics des combats AML.
    final internalMap = <String, Map<String, dynamic>>{};
    if (internalIds.isNotEmpty) {
      try {
        final fighters = await c
            .from('fighters')
            .select('id,first_name,last_name,nickname,photo_url,country_code')
            .inFilter('id', internalIds.toList());
        for (final raw in fighters) {
          final fighter = Map<String, dynamic>.from(raw);
          internalMap[fighter['id'].toString()] = fighter;
        }
      } catch (_) {}
    }

    final eventMap = <String, Map<String, dynamic>>{};
    final competitionIds = <String>{};
    if (eventIds.isNotEmpty) {
      final events = await c
          .from('events')
          .select('id,name,city,starts_at,competition_id')
          .inFilter('id', eventIds.toList());
      for (final raw in events) {
        final event = Map<String, dynamic>.from(raw);
        eventMap[event['id'].toString()] = event;
        final competition = event['competition_id']?.toString();
        if (competition != null) competitionIds.add(competition);
      }
    }

    final competitionMap = <String, Map<String, dynamic>>{};
    if (competitionIds.isNotEmpty) {
      final competitions = await c
          .from('competitions')
          .select('id,name,slug,short_name,is_aml,logo_url')
          .inFilter('id', competitionIds.toList());
      for (final raw in competitions) {
        final competition = Map<String, dynamic>.from(raw);
        competitionMap[competition['id'].toString()] = competition;
      }
    }

    for (final item in items) {
      final fight = fightMap[item['fight_id']?.toString()];
      if (fight == null) continue;

      final a = internalMap[fight['fighter_a_id']?.toString()] ?? externalMap[fight['external_fighter_a_id']?.toString()];
      final b = internalMap[fight['fighter_b_id']?.toString()] ?? externalMap[fight['external_fighter_b_id']?.toString()];
      final event = eventMap[fight['event_id']?.toString()];
      final competition = event == null
          ? null
          : competitionMap[event['competition_id']?.toString()];

      item['fight'] = {
        ...fight,
        'fighter_a': a,
        'fighter_b': b,
        'event': event,
        'competition': competition,
      };
      item['event'] = event;
      item['competition'] = competition;
    }

    final user = c.auth.currentUser;
    if (user != null) {
      final predictionIds = items.map((e) => e['id'].toString()).toList();
      final mine = await c
          .from('user_predictions')
          .select(
            'prediction_id,winner_option_id,method_option_id,round_option_id,submitted_at,xp_awarded',
          )
          .eq('user_id', user.id)
          .inFilter('prediction_id', predictionIds);

      final mineMap = <String, Map<String, dynamic>>{};
      for (final raw in mine) {
        final row = Map<String, dynamic>.from(raw);
        mineMap[row['prediction_id'].toString()] = row;
      }
      for (final item in items) {
        item['my_prediction'] = mineMap[item['id'].toString()];
      }
    }

    return items;
  }

  Future<void> submit({
    required String predictionId,
    String? winnerOptionId,
    String? methodOptionId,
    String? roundOptionId,
  }) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) {
      throw Exception('Connecte-toi pour faire un pronostic.');
    }

    try {
      await c.rpc('submit_aml_prediction', params: {
        'p_prediction_id': predictionId,
        'p_winner_option_id': winnerOptionId,
        'p_method_option_id': methodOptionId,
        'p_round_option_id': roundOptionId,
      });
    } on PostgrestException catch (e) {
      final message = e.message;
      if (message.contains('ALREADY_PREDICTED')) {
        throw Exception('Tu as déjà pronostiqué ce combat.');
      }
      if (message.contains('PREDICTION_LOCKED') ||
          message.contains('PREDICTION_CLOSED')) {
        throw Exception('Les pronostics pour ce combat sont fermés.');
      }
      if (message.contains('AUTH_REQUIRED')) {
        throw Exception('Connecte-toi pour faire un pronostic.');
      }
      if (message.contains('NO_PICK')) {
        throw Exception('Choisis au moins une option.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> stats(String predictionId) async {
    final c = client;
    if (c == null) return const {};
    try {
      final result = await c.rpc('aml_prediction_stats', params: {'p_prediction_id': predictionId});
      if (result is Map) return Map<String, dynamic>.from(result);
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<int> myXp() => XpService.myXp();

  Future<List<Map<String, dynamic>>> leaderboard({int limit = 20}) async {
    final c = client;
    if (c == null) return const [];
    try {
      final rows = await c.rpc(
        'aml_xp_leaderboard',
        params: {'p_limit': limit},
      );
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return const [];
    }
  }
}
