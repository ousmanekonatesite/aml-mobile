import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/order_repository.dart';

class AmlOrdersScreen extends StatefulWidget {
  const AmlOrdersScreen({super.key});

  @override
  State<AmlOrdersScreen> createState() => _AmlOrdersScreenState();
}

class _AmlOrdersScreenState extends State<AmlOrdersScreen> {
  final _repository = OrderRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getMyOrders();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'PAYÉE';
      case 'processing': return 'EN PRÉPARATION';
      case 'shipped': return 'EXPÉDIÉE';
      case 'delivered': return 'LIVRÉE';
      case 'cancelled': return 'ANNULÉE';
      default: return 'EN ATTENTE';
    }
  }

  Color _statusColor(String status) {
    if (status == 'delivered') return const Color(0xFF61D982);
    if (status == 'cancelled') return const Color(0xFFFF6B6B);
    return amlBlue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: amlBlack,
      appBar: AppBar(title: const Text('Mes commandes', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: amlBlue));
          if (snapshot.hasError) return Center(child: Text('Impossible de charger les commandes.', style: const TextStyle(color: Colors.white54)));
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.receipt_long_outlined, size: 56, color: Colors.white24), SizedBox(height: 14), Text('Aucune commande', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('Tes achats AML apparaîtront ici.', style: TextStyle(color: Colors.white54))])));
          }
          return RefreshIndicator(
            color: amlBlue,
            onRefresh: () async => setState(() => _future = _repository.getMyOrders()),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (_, index) {
                final order = orders[index];
                final status = (order['status'] ?? 'pending').toString();
                final items = order['order_items'] is List ? List<Map<String, dynamic>>.from(order['order_items']) : <Map<String, dynamic>>[];
                final date = DateTime.tryParse((order['created_at'] ?? '').toString());
                final dateLabel = date == null ? '' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: amlSurface, borderRadius: BorderRadius.circular(19), border: Border.all(color: Colors.white10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Expanded(child: Text('Commande #${order['id'].toString().substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w900))), Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontSize: 9, fontWeight: FontWeight.w900)))]),
                      const SizedBox(height: 7),
                      Text('$dateLabel • ${order['shipping_city'] ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      const SizedBox(height: 12),
                      ...items.take(4).map((item) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Expanded(child: Text('${item['product_name'] ?? 'Produit'} × ${item['quantity'] ?? 1}', style: const TextStyle(color: Colors.white70, fontSize: 11))), Text('${item['total_price'] ?? 0} FCFA', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))]))),
                      const Divider(color: Colors.white10),
                      Row(children: [const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900))), Text('${order['total_amount'] ?? 0} ${order['currency'] ?? 'XOF'}', style: const TextStyle(color: amlGold, fontSize: 15, fontWeight: FontWeight.w900))]),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
