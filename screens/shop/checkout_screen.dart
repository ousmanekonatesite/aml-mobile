import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/order_repository.dart';
import '../../services/supabase_service.dart';
import '../../services/wallet_repository.dart';

class AmlCheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int total;

  const AmlCheckoutScreen({super.key, required this.items, required this.total});

  @override
  State<AmlCheckoutScreen> createState() => _AmlCheckoutScreenState();
}

class _AmlCheckoutScreenState extends State<AmlCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Abidjan');
  final _repository = OrderRepository();
  bool _loading = false;
  String _paymentMethod = 'À confirmer';
  int _credits = 0;

  @override
  void initState() {
    super.initState();
    WalletRepository().load().then((w) { if (mounted) setState(() => _credits = w.purchasedCredits); });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (SupabaseService.client?.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecte-toi pour passer une commande.')));
      return;
    }
    if (_paymentMethod == 'credits' && _credits < widget.total) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Crédits insuffisants : il te manque ${widget.total - _credits} crédits. Recharge ou convertis tes XP dans « Solde AML ».')));
      return;
    }
    setState(() => _loading = true);
    try {
      final id = await _repository.createOrder(
        items: widget.items,
        total: widget.total,
        fullName: _name.text,
        phone: _phone.text,
        address: _address.text,
        city: _city.text,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      if (_paymentMethod == 'credits') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Commande payée avec ${widget.total} crédits AML.')));
      }
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().contains('INSUFFICIENT_CREDITS') ? 'Crédits insuffisants pour cette commande.' : e.toString().contains('INSUFFICIENT_STOCK') ? 'Stock insuffisant pour un des articles.' : 'Impossible de créer la commande pour le moment. $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: amlBlue),
      filled: true,
      fillColor: amlSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: amlBlack,
      appBar: AppBar(title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w900))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
          children: [
            const Text('LIVRAISON', style: TextStyle(color: amlGold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 12),
            TextFormField(controller: _name, decoration: _decoration('Nom complet', Icons.person_outline), validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null),
            const SizedBox(height: 11),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: _decoration('Téléphone', Icons.phone_outlined), validator: (v) => v == null || v.trim().length < 8 ? 'Téléphone invalide' : null),
            const SizedBox(height: 11),
            TextFormField(controller: _city, decoration: _decoration('Ville', Icons.location_city_outlined), validator: (v) => v == null || v.trim().isEmpty ? 'Ville requise' : null),
            const SizedBox(height: 11),
            TextFormField(controller: _address, maxLines: 3, decoration: _decoration('Adresse / point de livraison', Icons.location_on_outlined), validator: (v) => v == null || v.trim().length < 5 ? 'Adresse requise' : null),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              dropdownColor: amlSurface2,
              decoration: _decoration('Mode de paiement', Icons.payment_outlined),
              items: [
                DropdownMenuItem(value: 'credits', child: Text('Mes crédits AML (solde : $_credits)')),
                const DropdownMenuItem(value: 'À confirmer', child: Text('À confirmer avec AML')),
                const DropdownMenuItem(value: 'Paiement à la livraison', child: Text('Paiement à la livraison')),
              ],
              onChanged: _loading ? null : (value) => setState(() => _paymentMethod = value ?? 'À confirmer'),
            ),
            const SizedBox(height: 8),
            Text(
              _paymentMethod == 'credits'
                  ? (_credits >= widget.total ? 'Montant débité : ${widget.total} crédits (1 crédit = 1 FCFA). La commande est payée immédiatement.' : 'Solde insuffisant : il te manque ${widget.total - _credits} crédits.')
                  : '',
              style: TextStyle(color: _paymentMethod == 'credits' && _credits < widget.total ? Colors.redAccent : Colors.white38, fontSize: 10, height: 1.35),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: amlSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RÉCAPITULATIF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  ...widget.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [Expanded(child: Text('${item['product_name']} × ${item['quantity']}', style: const TextStyle(color: Colors.white70, fontSize: 12))), Text('${item['total_price']} FCFA', style: const TextStyle(fontWeight: FontWeight.w800))]),
                  )),
                  const Divider(color: Colors.white12),
                  Row(children: [const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900))), Text(_formatXof(widget.total), style: const TextStyle(color: amlGold, fontSize: 17, fontWeight: FontWeight.w900))]),
                  const SizedBox(height: 8),
                  const Text('Le moyen de paiement sera confirmé selon le dispositif AML disponible.', style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: amlBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _loading ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('CONFIRMER LA COMMANDE', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatXof(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(text[i]);
  }
  return '${buffer.toString()} FCFA';
}
