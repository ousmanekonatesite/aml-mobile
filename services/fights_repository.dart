import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'media_rights.dart';

class FightsRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<List<Map<String, dynamic>>> upcoming({String? competitionId, String? eventId}) async {
    final c = client;
    if (c == null) return [];

    try {
      // On charge d'abord les combats sans jointure profonde. Cela évite qu'une
      // relation Supabase mal détectée fasse disparaître toute la fight card.
      var request = c.from('fights').select('''
        id,event_id,fighter_a_id,fighter_b_id,external_fighter_a_id,external_fighter_b_id,
        weight_category_id,bout_order,scheduled_rounds,title_bout,status,
        winner_fighter_id,external_winner_fighter_id,result,finish_round,decision_type
      ''');

      List<dynamic> rows = await request
          .inFilter('status', ['scheduled', 'live', 'finished'])
          .order('bout_order')
          .limit(100);

      var fights = List<Map<String, dynamic>>.from(rows);
      if (fights.isEmpty) return [];

      final eventIds = fights
          .map((f) => f['event_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final eventsById = <String, Map<String, dynamic>>{};
      if (eventIds.isNotEmpty) {
        final eventRows = await c.from('events').select('id,name,city,starts_at,competition_id,status').inFilter('id', eventIds);
        for (final row in List<Map<String, dynamic>>.from(eventRows)) {
          eventsById[row['id'].toString()] = row;
        }
      }

      // Compétition « effective » d'un combat : celle de sa carte, sinon AML quand
      // les deux combattants sont des athlètes AML (cartes créées sans compétition).
      final catalog = await _competitionCatalog();
      String? effectiveCompetitionId(Map<String, dynamic> fight) {
        final explicit = eventsById[fight['event_id']?.toString()]?['competition_id']?.toString();
        if (explicit != null && explicit.isNotEmpty) return explicit;
        final internal = fight['fighter_a_id'] != null || fight['fighter_b_id'] != null;
        return internal ? catalog.amlId : null;
      }

      if (eventId != null && eventId.isNotEmpty) {
        fights = fights.where((f) => f['event_id']?.toString() == eventId).toList();
      } else if (competitionId != null && competitionId.isNotEmpty) {
        fights = fights.where((f) => effectiveCompetitionId(f) == competitionId).toList();
      }
      if (fights.isEmpty) return [];

      final weightIds = fights
          .map((f) => f['weight_category_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final weightsById = <String, Map<String, dynamic>>{};
      if (weightIds.isNotEmpty) {
        try {
          final weightRows = await c.from('weight_categories').select('id,name').inFilter('id', weightIds);
          for (final row in List<Map<String, dynamic>>.from(weightRows)) {
            weightsById[row['id'].toString()] = row;
          }
        } catch (_) {}
      }

      final amlIds = <String>{};
      final externalIds = <String>{};
      for (final fight in fights) {
        for (final key in ['fighter_a_id', 'fighter_b_id']) {
          final id = fight[key]?.toString();
          if (id != null && id.isNotEmpty) amlIds.add(id);
        }
        for (final key in ['external_fighter_a_id', 'external_fighter_b_id']) {
          final id = fight[key]?.toString();
          if (id != null && id.isNotEmpty) externalIds.add(id);
        }
      }

      final amlById = <String, Map<String, dynamic>>{};
      if (amlIds.isNotEmpty) {
        try {
          final fighterRows = await c.from('fighters').select('id,first_name,last_name,nickname,photo_url,country_code').inFilter('id', amlIds.toList());
          for (final row in List<Map<String, dynamic>>.from(fighterRows)) {
            amlById[row['id'].toString()] = row;
          }
        } catch (_) {}
      }

      final externalById = <String, Map<String, dynamic>>{};
      if (externalIds.isNotEmpty) {
        try {
          final fighterRows = await c.from('external_fighters').select('id,first_name,last_name,nickname,photo_url,country_code,weight_category,fighting_style,rights_status,rights_expires_at').inFilter('id', externalIds.toList());
          for (final row in List<Map<String, dynamic>>.from(fighterRows)) {
            redactExternalFighterPhoto(row);
            externalById[row['id'].toString()] = row;
          }
        } catch (_) {}
      }

      for (final fight in fights) {
        final event = eventsById[fight['event_id']?.toString()];
        final competition = catalog.byId[effectiveCompetitionId(fight)];
        final fighterA = amlById[fight['fighter_a_id']?.toString()] ?? externalById[fight['external_fighter_a_id']?.toString()];
        final fighterB = amlById[fight['fighter_b_id']?.toString()] ?? externalById[fight['external_fighter_b_id']?.toString()];
        fight['events'] = event ?? <String, dynamic>{};
        fight['competition'] = competition ?? <String, dynamic>{};
        fight['weight_category'] = weightsById[fight['weight_category_id']?.toString()] ?? <String, dynamic>{};
        fight['fighter_a'] = fighterA;
        fight['fighter_b'] = fighterB;
      }

      fights.sort((a, b) {
        final eventA = eventsById[a['event_id']?.toString()] ?? const <String, dynamic>{};
        final eventB = eventsById[b['event_id']?.toString()] ?? const <String, dynamic>{};
        final dateA = DateTime.tryParse((eventA['starts_at'] ?? '').toString());
        final dateB = DateTime.tryParse((eventB['starts_at'] ?? '').toString());
        if (dateA != null && dateB != null) {
          final dateOrder = dateB.compareTo(dateA);
          if (dateOrder != 0) return dateOrder;
        } else if (dateA != null) {
          return -1;
        } else if (dateB != null) {
          return 1;
        }
        return ((a['bout_order'] as num?)?.toInt() ?? 999).compareTo(((b['bout_order'] as num?)?.toInt() ?? 999));
      });
      return fights;
    } catch (_) {
      return [];
    }
  }

  Future<_CompetitionCatalog> _competitionCatalog() async {
    final c = client;
    if (c == null) return _CompetitionCatalog({}, null);
    try {
      final rows = await c.from('competitions').select('id,name,slug,logo_url,country_code,is_aml');
      final byId = <String, Map<String, dynamic>>{};
      String? amlId;
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final id = row['id'].toString();
        byId[id] = row;
        final slug = (row['slug'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final name = (row['name'] ?? '').toString().toLowerCase();
        final aml = row['is_aml'] == true || slug == 'aml' || slug.contains('africanmma') || name.contains('african mma league');
        if (aml && amlId == null) amlId = id;
      }
      return _CompetitionCatalog(byId, amlId);
    } catch (_) {
      return _CompetitionCatalog({}, null);
    }
  }

  /// Cartes (événements) avec leur compétition et le nombre de combats.
  /// Tri : les plus récentes d'abord (les cartes sans date en dernier).
  Future<List<Map<String, dynamic>>> events({String? competitionId}) async {
    final c = client;
    if (c == null) return [];
    try {
      final catalog = await _competitionCatalog();
      final rows = await c
          .from('events')
          .select('id,name,city,venue_name,starts_at,poster_url,cover_url,status,competition_id')
          .inFilter('status', ['published', 'live', 'finished'])
          .order('starts_at', ascending: false, nullsFirst: false);
      final events = List<Map<String, dynamic>>.from(rows);
      if (events.isEmpty) return [];
      final ids = events.map((e) => e['id'].toString()).toList();
      final fightRows = await c
          .from('fights')
          .select('event_id,fighter_a_id,fighter_b_id,title_bout')
          .inFilter('event_id', ids)
          .inFilter('status', ['scheduled', 'live', 'finished']);
      final counts = <String, int>{};
      final internal = <String>{};
      final titles = <String, int>{};
      for (final f in List<Map<String, dynamic>>.from(fightRows)) {
        final id = f['event_id']?.toString();
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
        if (f['fighter_a_id'] != null || f['fighter_b_id'] != null) internal.add(id);
        if (f['title_bout'] == true) titles[id] = (titles[id] ?? 0) + 1;
      }
      for (final e in events) {
        final id = e['id'].toString();
        var comp = e['competition_id']?.toString();
        if ((comp == null || comp.isEmpty) && internal.contains(id)) comp = catalog.amlId;
        e['effective_competition_id'] = comp;
        e['competition'] = catalog.byId[comp] ?? <String, dynamic>{};
        e['fight_count'] = counts[id] ?? 0;
        e['title_fight_count'] = titles[id] ?? 0;
      }
      if (competitionId == null || competitionId.isEmpty) return events;
      return events.where((e) => e['effective_competition_id']?.toString() == competitionId).toList();
    } catch (_) {
      return [];
    }
  }
}

class _CompetitionCatalog {
  final Map<String, Map<String, dynamic>> byId;
  final String? amlId;
  _CompetitionCatalog(this.byId, this.amlId);
}
