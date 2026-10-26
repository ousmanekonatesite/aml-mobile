import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'xp_service.dart';

class WalletSnapshot {
  final int earnedXp;
  final int purchasedCredits;
  const WalletSnapshot({required this.earnedXp, required this.purchasedCredits});
}

class WalletRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<int> xpPerCredit() async {
    final c = client;
    if (c == null) return 100;
    try {
      final row = await c.from('aml_wallet_settings').select('xp_per_credit').eq('id', true).maybeSingle();
      return (row?['xp_per_credit'] as num?)?.toInt() ?? 100;
    } catch (_) { return 100; }
  }

  Future<Map<String, dynamic>> convertXp(int xp) async {
    final c = client;
    if (c == null || c.auth.currentUser == null) throw Exception('Connexion requise.');
    final result = await c.rpc('aml_convert_xp_to_credit', params: {'p_xp': xp});
    if (result is List && result.isNotEmpty) return Map<String, dynamic>.from(result.first as Map);
    if (result is Map) return Map<String, dynamic>.from(result);
    throw Exception('Réponse de conversion invalide.');
  }

  Future<WalletSnapshot> load() async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) {
      return const WalletSnapshot(earnedXp: 0, purchasedCredits: 0);
    }
    try {
      final xp = await XpService.myXp();
      final walletResult = await c.from('wallet_accounts').select('purchased_credits').eq('user_id', user.id).maybeSingle();
      final credits = (walletResult?['purchased_credits'] as num?)?.toInt() ?? 0;
      return WalletSnapshot(earnedXp: xp, purchasedCredits: credits);
    } catch (_) {
      return const WalletSnapshot(earnedXp: 0, purchasedCredits: 0);
    }
  }
}
