import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class CinetPayRepository {
  SupabaseClient? get client => SupabaseService.client;

  Future<String> createPayment({required int amountXof, required int credits}) async {
    final c = client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) {
      throw Exception('Connecte-toi pour acheter des crédits AML.');
    }
    final result = await c.functions.invoke('cinetpay-create-payment', body: {
      'amount': amountXof,
      'credits': credits,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final url = data['payment_url']?.toString();
    if (url == null || url.isEmpty) throw Exception('Lien de paiement indisponible.');
    return url;
  }
}
