import 'supabase_service.dart';

/// Source unique du solde XP : le registre `xp_transactions`, lu via la fonction
/// `aml_my_xp()` (même base que le classement). Tous les écrans doivent passer par ici.
class XpService {
  static Future<int> myXp() async {
    final c = SupabaseService.client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return 0;
    try {
      final result = await c.rpc('aml_my_xp');
      if (result is num) return result.toInt();
      return int.tryParse(result.toString()) ?? 0;
    } catch (_) {
      try {
        final rows = await c.from('xp_transactions').select('amount').eq('user_id', user.id);
        return List<Map<String, dynamic>>.from(rows)
            .fold<int>(0, (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0));
      } catch (_) {
        return 0;
      }
    }
  }
}
