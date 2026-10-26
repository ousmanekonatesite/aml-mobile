import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/cinetpay_repository.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);
const Color _gold = Color(0xFFFFB800);

class AmlCreditPurchaseScreen extends StatefulWidget {
  const AmlCreditPurchaseScreen({super.key});
  @override
  State<AmlCreditPurchaseScreen> createState() => _AmlCreditPurchaseScreenState();
}

class _AmlCreditPurchaseScreenState extends State<AmlCreditPurchaseScreen> {
  final repo = CinetPayRepository();
  bool loading = false;

  Future<void> _pay(int amount, int credits) async {
    setState(() => loading = true);
    try {
      final url = await repo.createPayment(amountXof: amount, credits: credits);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) _message('Impossible d’ouvrir la page de paiement.');
      if (mounted) _message('Après le paiement, reviens dans AML Arena puis actualise ton solde.');
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(title: const Text('Acheter des crédits', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _blue.withOpacity(.22))), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lock_outline, color: _blue, size: 30),
          SizedBox(height: 10),
          Text('Paiement sécurisé', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('Le paiement est traité par CinetPay. Les crédits ne sont ajoutés qu’après confirmation serveur.', style: TextStyle(color: Colors.white60, height: 1.4)),
        ])),
        const SizedBox(height: 18),
        _Pack(label: 'Starter', price: 1000, credits: 10000, onTap: () => _pay(1000, 10000), loading: loading),
        _Pack(label: 'Fan', price: 2000, credits: 20000, onTap: () => _pay(2000, 20000), loading: loading, highlighted: true),
        _Pack(label: 'Supporter', price: 5000, credits: 55000, onTap: () => _pay(5000, 55000), loading: loading),
        const SizedBox(height: 8),
        const Text('Moyens de paiement disponibles selon la configuration de ton compte CinetPay : mobile money et cartes.', style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
      ]),
    );
  }
}

class _Pack extends StatelessWidget {
  final String label; final int price; final int credits; final VoidCallback onTap; final bool loading, highlighted;
  const _Pack({required this.label, required this.price, required this.credits, required this.onTap, required this.loading, this.highlighted = false});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: highlighted ? _blue : Colors.white10)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('$credits crédits AML', style: const TextStyle(color: _blue, fontWeight: FontWeight.w800))])), ElevatedButton(onPressed: loading ? null : onTap, style: ElevatedButton.styleFrom(backgroundColor: highlighted ? _blue : _gold, foregroundColor: Colors.black), child: Text('$price FCFA', style: const TextStyle(fontWeight: FontWeight.w900)))]));
}
