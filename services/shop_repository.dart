import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class ShopRepository {
  Future<List<Map<String, dynamic>>> getProducts() async {
    final client = SupabaseService.client;
    if (client == null) return [];

    final rows = await client
        .from('products')
        .select('*, product_categories(name, slug)')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    final products = List<Map<String, dynamic>>.from(rows);
    return products.map((row) => _normalize(client, row)).toList();
  }

  Map<String, dynamic> _normalize(SupabaseClient client, Map<String, dynamic> row) {
    final category = row['product_categories'];
    final categoryName = category is Map<String, dynamic>
        ? (category['name'] ?? 'Accessoires').toString()
        : 'Accessoires';
    final path = row['cover_image_path']?.toString().trim();

    String? imageUrl;
    if (path != null && path.isNotEmpty) {
      // Admin accepts either a complete public URL or a path inside the
      // public `products` Storage bucket. Do not feed full URLs to getPublicUrl.
      imageUrl = path.startsWith('https://') || path.startsWith('http://')
          ? path
          : client.storage.from('products').getPublicUrl(path);
    }

    return {
      ...row,
      'category_name': categoryName,
      'image_url': imageUrl,
    };
  }
}
