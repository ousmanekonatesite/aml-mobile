import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class OrderRepository {
  SupabaseClient? get _client => SupabaseService.client;

  Future<String> createOrder({
    required List<Map<String, dynamic>> items,
    required int total,
    required String fullName,
    required String phone,
    required String address,
    required String city,
    String paymentMethod = 'À confirmer',
  }) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) throw StateError('AUTH_REQUIRED');

    // Le serveur recalcule les prix et vérifie le stock. Flutter ne peut pas
    // imposer un prix client ni décrémenter directement le stock.
    final payloadItems = items.map((item) => {
      'product_id': item['product_id'],
      'quantity': item['quantity'],
      'variant': item['variant'],
    }).toList();

    final result = await client.rpc('aml_create_shop_order', params: {
      'p_items': payloadItems,
      'p_shipping_name': fullName.trim(),
      'p_shipping_phone': phone.trim(),
      'p_shipping_address': address.trim(),
      'p_shipping_city': city.trim(),
      'p_payment_method': paymentMethod,
    });

    if (result is! Map) throw StateError('ORDER_CREATE_FAILED');
    final id = result['order_id']?.toString();
    if (id == null || id.isEmpty) throw StateError('ORDER_CREATE_FAILED');
    return id;
  }

  Future<List<Map<String, dynamic>>> getMyOrders() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return [];

    final rows = await client
        .from('orders')
        .select('id,status,total_amount,currency,payment_status,created_at,shipping_city,order_items(product_name,quantity,unit_price,line_total,variant)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }
}
