import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'media_rights.dart';

class AmlHomeRepository {
  SupabaseClient? get client => SupabaseService.client;

  /// Classement officiel des combattants avec leurs noms et catégories de poids,
  /// uniquement la date de classement la plus récente (par catégorie si filtrée).
  Future<List<Map<String, dynamic>>> rankingsConfigured({String? categoryId, int limit = 5}) async {
    final c = client;
    if (c == null) return [];
    try {
      var query = c.from('rankings').select('rank,fighter_id,category_id,ranking_date');
      if (categoryId != null && categoryId.isNotEmpty) query = query.eq('category_id', categoryId);
      final raw = await query.order('ranking_date', ascending: false).order('rank').limit(300);
      var rows = List<Map<String, dynamic>>.from(raw);
      if (rows.isEmpty) return [];
      final latest = <String, String>{};
      for (final r in rows) {
        final cat = r['category_id'].toString();
        final d = r['ranking_date'].toString();
        if (!latest.containsKey(cat) || d.compareTo(latest[cat]!) > 0) latest[cat] = d;
      }
      rows = rows.where((r) => r['ranking_date'].toString() == latest[r['category_id'].toString()]).toList()
        ..sort((a, b) => ((a['rank'] as num?)?.toInt() ?? 999).compareTo((b['rank'] as num?)?.toInt() ?? 999));
      rows = rows.take(limit).toList();
      final fighterIds = rows.map((r) => r['fighter_id'].toString()).toSet().toList();
      final catIds = rows.map((r) => r['category_id'].toString()).toSet().toList();
      final fighters = <String, Map<String, dynamic>>{};
      final cats = <String, String>{};
      final fr = await c.from('fighters').select('id,first_name,last_name,nickname').inFilter('id', fighterIds);
      for (final f in List<Map<String, dynamic>>.from(fr)) { fighters[f['id'].toString()] = f; }
      final cr = await c.from('weight_categories').select('id,name').inFilter('id', catIds);
      for (final k in List<Map<String, dynamic>>.from(cr)) { cats[k['id'].toString()] = (k['name'] ?? '').toString(); }
      return rows.map((r) {
        final f = fighters[r['fighter_id'].toString()] ?? const <String, dynamic>{};
        final name = '${f['first_name'] ?? ''} ${f['last_name'] ?? ''}'.trim();
        return <String, dynamic>{
          'rank': r['rank'],
          'fighter_name': name.isEmpty ? (f['nickname'] ?? '').toString() : name,
          'division': cats[r['category_id'].toString()] ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> rankings() async {
    final c = client;
    if (c == null) return [];

    try {
      final rows = await c
          .from('rankings')
          .select('*')
          .order('rank')
          .limit(5);

      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      try {
        final rows = await c
            .from('rankings')
            .select('*')
            .limit(5);

        return List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> recentResults() async {
    final c = client;
    if (c == null) return [];

    try {
      final rows = await c
          .from('fights')
          .select('''
            id,
            event_id,
            fighter_a_id,
            fighter_b_id,
            external_fighter_a_id,
            external_fighter_b_id,
            external_winner_fighter_id,
            winner_fighter_id,
            result,
            finish_round,
            finish_time,
            decision_type,
            weight_category_id,
            bout_order,
            status,
            title_bout
          ''')
          .not('winner_fighter_id', 'is', null)
          .order('bout_order', ascending: false)
          .limit(10);

      return _hydrateResults(
        List<Map<String, dynamic>>.from(rows),
        c,
      );
    } catch (_) {
      try {
        final rows = await c
            .from('fights')
            .select('''
              id,
              event_id,
              fighter_a_id,
              fighter_b_id,
              external_fighter_a_id,
              external_fighter_b_id,
              external_winner_fighter_id,
              winner_fighter_id,
              result,
              finish_round,
              finish_time,
              decision_type,
              weight_category_id,
              bout_order,
              status,
              title_bout
            ''')
            .not('external_winner_fighter_id', 'is', null)
            .order('bout_order', ascending: false)
            .limit(10);

        return _hydrateResults(
          List<Map<String, dynamic>>.from(rows),
          c,
        );
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> _hydrateResults(
    List<Map<String, dynamic>> fights,
    SupabaseClient c,
  ) async {
    if (fights.isEmpty) return [];

    final eventIds = fights
        .map((f) => f['event_id']?.toString())
        .whereType<String>()
        .where((x) => x.isNotEmpty)
        .toSet()
        .toList();

    final amlIds = <String>{};
    final externalIds = <String>{};

    for (final f in fights) {
      for (final k in [
        'fighter_a_id',
        'fighter_b_id',
        'winner_fighter_id',
      ]) {
        final v = f[k]?.toString();

        if (v != null && v.isNotEmpty) {
          amlIds.add(v);
        }
      }

      for (final k in [
        'external_fighter_a_id',
        'external_fighter_b_id',
        'external_winner_fighter_id',
      ]) {
        final v = f[k]?.toString();

        if (v != null && v.isNotEmpty) {
          externalIds.add(v);
        }
      }
    }

    final events = <String, Map<String, dynamic>>{};
    final aml = <String, Map<String, dynamic>>{};
    final ext = <String, Map<String, dynamic>>{};

    // ------------------------------------------------------------
    // EVENTS
    // ------------------------------------------------------------

    if (eventIds.isNotEmpty) {
      try {
        final rows = List<Map<String, dynamic>>.from(
          await c
              .from('events')
              .select('id,name,city,starts_at')
              .inFilter('id', eventIds),
        );

        for (final event in rows) {
          events[event['id'].toString()] = event;
        }
      } catch (_) {}
    }

    // ------------------------------------------------------------
    // AML FIGHTERS
    // ------------------------------------------------------------

    if (amlIds.isNotEmpty) {
      try {
        final rows = List<Map<String, dynamic>>.from(
          await c
              .from('fighters')
              .select(
                'id,first_name,last_name,nickname,photo_url',
              )
              .inFilter('id', amlIds.toList()),
        );

        for (final fighter in rows) {
          aml[fighter['id'].toString()] = fighter;
        }
      } catch (_) {}
    }

    // ------------------------------------------------------------
    // EXTERNAL FIGHTERS
    // ------------------------------------------------------------

    if (externalIds.isNotEmpty) {
      try {
        final rows = List<Map<String, dynamic>>.from(
          await c
              .from('external_fighters')
              .select(
                'id,first_name,last_name,nickname,photo_url,'
                'country_code,rights_status,rights_expires_at',
              )
              .inFilter('id', externalIds.toList()),
        );

        for (final fighter in rows) {
          // Respect the AML media-rights rules.
          redactExternalFighterPhoto(fighter);

          ext[fighter['id'].toString()] = fighter;
        }
      } catch (_) {}
    }

    // ------------------------------------------------------------
    // BUILD FINAL RESULTS
    // ------------------------------------------------------------

    return fights.map((f) {
      final a =
          aml[f['fighter_a_id']?.toString()] ??
          ext[f['external_fighter_a_id']?.toString()];

      final b =
          aml[f['fighter_b_id']?.toString()] ??
          ext[f['external_fighter_b_id']?.toString()];

      final winner =
          aml[f['winner_fighter_id']?.toString()] ??
          ext[f['external_winner_fighter_id']?.toString()];

      return {
        ...f,
        'event': events[f['event_id']?.toString()] ?? {},
        'fighter_a': a ?? {},
        'fighter_b': b ?? {},
        'winner': winner ?? {},
      };
    }).toList();
  }

  Future<Map<String, dynamic>> homeSettings() async {
    final c = client;
    if (c == null) return const {};
    try {
      final row = await c.from('app_home_settings').select('*').eq('id', true).maybeSingle();
      return row == null ? const {} : Map<String, dynamic>.from(row);
    } catch (_) { return const {}; }
  }

  Future<List<Map<String, dynamic>>> homeSections() async {
    final c = client;
    if (c == null) return const [];
    try {
      final rows = await c.from('app_home_sections').select('section_key,title,action_label,description,image_url,content,is_visible,sort_order').eq('is_visible', true).order('sort_order');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) { return const []; }
  }

  Future<List<Map<String, dynamic>>> publishedVideos() async {
    final c = client;
    if (c == null) return const [];
    try {
      final rows = List<Map<String, dynamic>>.from(await c
          .from('videos')
          .select('id,title,description,storage_path,thumbnail_path,external_url,duration_seconds,category_id,status,is_featured,published_at,created_at')
          .eq('status', 'published')
          .order('is_featured', ascending: false)
          .order('published_at', ascending: false)
          .limit(50));
      if (rows.isEmpty) return const [];
      final categoryIds = rows
          .map((row) => row['category_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (categoryIds.isNotEmpty) {
        try {
          final categories = List<Map<String, dynamic>>.from(
            await c.from('video_categories').select('id,name,slug').inFilter('id', categoryIds),
          );
          final byId = <String, Map<String, dynamic>>{
            for (final category in categories) category['id'].toString(): category,
          };
          for (final row in rows) {
            final category = byId[row['category_id']?.toString()];
            if (category != null) row['category_name'] = category['name'];
          }
        } catch (_) {}
      }
      return rows;
    } catch (_) {
      return const [];
    }
  }

}
