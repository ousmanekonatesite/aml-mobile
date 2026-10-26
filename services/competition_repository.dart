import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CompetitionRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<List<Map<String, dynamic>>> active() async {
    final c = client;
    if (c == null) return [];
    try {
      final rows = await c
          .from('competitions')
          .select('id,name,slug,logo_url,country_code,is_aml')
          .eq('is_active', true)
          .order('name');
      final competitions = List<Map<String, dynamic>>.from(rows);
      bool isAml(Map<String, dynamic> c) {
        if (c['is_aml'] == true) return true;
        final slug = (c['slug'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final name = (c['name'] ?? '').toString().toLowerCase();
        return slug == 'aml' || slug.contains('africanmma') || name.contains('african mma league');
      }
      competitions.sort((a, b) {
        if (isAml(a) != isAml(b)) return isAml(a) ? -1 : 1;
        return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
      });
      return competitions;
    } catch (_) {
      return [];
    }
  }

} 
