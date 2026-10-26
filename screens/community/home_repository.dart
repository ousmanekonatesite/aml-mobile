import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'media_rights.dart';

class AmlHomeRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<List<Map<String, dynamic>>> rankings() async {
    final c = client;
    if (c == null) return [];
    try {
      final rows = await c.from('rankings').select('*').order('rank').limit(5);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      try {
        final rows = await c.from('rankings').select('*').limit(5);
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
      final rows = await c.from('fights').select('''
        id,event_id,fighter_a_id,fighter_b_id,external_fighter_a_id,external_fighter_b_id,
        external_winner_fighter_id,winner_fighter_id,result,finish_round,finish_time,decision_type,
        weight_category_id,bout_order,status,title_bout
      ''').not('winner_fighter_id', 'is', null).order('bout_order', ascending: false).limit(10);
      return _hydrateResults(List<Map<String, dynamic>>.from(rows), c);
    } catch (_) {
      try {
        final rows = await c.from('fights').select('''
          id,event_id,fighter_a_id,fighter_b_id,external_fighter_a_id,external_fighter_b_id,
          external_winner_fighter_id,winner_fighter_id,result,finish_round,finish_time,decision_type,
          weight_category_id,bout_order,status,title_bout
        ''').not('external_winner_fighter_id', 'is', null).order('bout_order', ascending: false).limit(10);
        return _hydrateResults(List<Map<String, dynamic>>.from(rows), c);
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> _hydrateResults(List<Map<String, dynamic>> fights, SupabaseClient c) async {
    if (fights.isEmpty) return [];
    final eventIds = fights.map((f) => f['event_id']?.toString()).whereType<String>().where((x) => x.isNotEmpty).toSet().toList();
    final amlIds = <String>{};
    final externalIds = <String>{};
    for (final f in fights) {
      for (final k in ['fighter_a_id','fighter_b_id','winner_fighter_id']) {
        final v = f[k]?.toString(); if (v != null && v.isNotEmpty) amlIds.add(v);
      }
      for (final k in ['external_fighter_a_id','external_fighter_b_id','external_winner_fighter_id']) {
        final v = f[k]?.toString(); if (v != null && v.isNotEmpty) externalIds.add(v);
      }
    }
    final events = <String, Map<String,dynamic>>{};
    final aml = <String, Map<String,dynamic>>{};
    final ext = <String, Map<String,dynamic>>{};
    if (eventIds.isNotEmpty) {
      try { for (final r in List<Map<String,dynamic>>.from(await c.from('events').select('id,name,city,starts_at').inFilter('id', eventIds))) events[r['id'].toString()] = r; } catch (_) {}
    }
    if (amlIds.isNotEmpty) {
      try { for (final r in List<Map<String,dynamic>>.from(await c.from('fighters').select('id,first_name,last_name,name,nickname,photo_url').inFilter('id', amlIds.toList()))) aml[r['id'].toString()] = r; } catch (_) {}
    }
    if (externalIds.isNotEmpty) {
      try {
        final rows = List<Map<String,dynamic>>.from(
          await c
              .from('external_fighters')
              .select('id,first_name,last_name,nickname,photo_url,country_code,rights_status,rights_expires_at')
              .inFilter('id', externalIds.toList()),
        );
        for (final fighter in rows) {
          redactExternalFighterPhoto(fighter);
          ext[fighter['id'].toString()] = fighter;
        }
      } catch (_) {}
    }
    return fights.map((f) {
      final a = aml[f['fighter_a_id']?.toString()] ?? ext[f['external_fighter_a_id']?.toString()];
      final b = aml[f['fighter_b_id']?.toString()] ?? ext[f['external_fighter_b_id']?.toString()];
      final winner = aml[f['winner_fighter_id']?.toString()] ?? ext[f['external_winner_fighter_id']?.toString()];
      return {...f, 'event': events[f['event_id']?.toString()] ?? {}, 'fighter_a': a ?? {}, 'fighter_b': b ?? {}, 'winner': winner ?? {}};
    }).toList();
  }
}

