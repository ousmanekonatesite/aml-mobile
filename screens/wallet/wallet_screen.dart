import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/wallet_repository.dart';
import '../auth/auth_screen.dart';
import 'credit_purchase_screen.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);

class AmlWalletScreen extends StatefulWidget {
  const AmlWalletScreen({super.key});
  @override
  State<AmlWalletScreen> createState() => _AmlWalletScreenState();
}

class _AmlWalletScreenState extends State<AmlWalletScreen> {
  final repo = WalletRepository();
  WalletSnapshot snapshot = const WalletSnapshot(earnedXp: 0, purchasedCredits: 0);
  bool loading = true;
  int xpRate = 100;
  bool converting = false;

  bool get connected => SupabaseService.client?.auth.currentUser != null;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!connected) { if (mounted) setState(() => loading = false); return; }
    final values = await Future.wait([repo.load(), repo.xpPerCredit()]);
    if (mounted) setState(() { snapshot = values[0] as WalletSnapshot; xpRate = values[1] as int; loading = false; });
  }

  Future<void> _convert(int amount) async {
    setState(() => converting = true);
    try {
      await repo.convertXp(amount);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$amount XP convertis en ${amount ~/ xpRate} crédit(s).')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conversion impossible : ${e.toString().replaceFirst('Exception: ', '')}')));
    } finally { if (mounted) setState(() => converting = false); }
  }

  Future<void> _auth() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlAuthScreen()));
    if (mounted) { setState(() => loading = true); await _load(); }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(backgroundColor: _black, body: Center(child: CircularProgressIndicator(color: _blue)));
    if (!connected) {
      return Scaffold(
        backgroundColor: _black,
        appBar: AppBar(title: const Text('Solde AML', style: TextStyle(fontWeight: FontWeight.w900))),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 70, color: _blue),
          const SizedBox(height: 18),
          const Text('Ton portefeuille AML', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Connecte-toi pour consulter tes XP et tes crédits.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _auth, style: ElevatedButton.styleFrom(backgroundColor: _blue), child: const Text('SE CONNECTER', style: TextStyle(fontWeight: FontWeight.w900)))),
        ]))),
      );
    }

    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(title: const Text('Solde AML', style: TextStyle(fontWeight: FontWeight.w900))),
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          Row(children: [
            Expanded(child: _BalanceCard(icon: Icons.emoji_events_outlined, title: 'XP GAGNÉS', value: snapshot.earnedXp, note: 'Pronostics, défis et récompenses', color: _blue)),
            const SizedBox(width: 10),
            Expanded(child: _BalanceCard(icon: Icons.account_balance_wallet_outlined, title: 'CRÉDITS AML', value: snapshot.purchasedCredits, note: 'Utilisables pour les billets', color: const Color(0xFFFFB800))),
          ]),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _blue.withOpacity(.25))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CONVERTIR MES XP EN CRÉDIT', style: TextStyle(color: _blue, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 6),
            Text('Taux actuel : $xpRate XP = 1 crédit. Le taux est défini par l’administration.', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final amount in [xpRate, xpRate * 5, xpRate * 10]) OutlinedButton(onPressed: converting || snapshot.earnedXp < amount ? null : () => _convert(amount), child: Text('$amount XP → ${amount ~/ xpRate} crédit(s)'))]),
          ])),
          const SizedBox(height: 20),
          const Text('CRÉDITS AML', style: TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Les crédits achetés serviront notamment à payer tes billets. Le paiement sécurisé arrive avec l’étape CinetPay.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
          const SizedBox(height: 14),
          _PackButton(label: 'Pack Starter', price: '1 000 FCFA', credits: '10 000 crédits'),
          _PackButton(label: 'Pack Fan', price: '2 000 FCFA', credits: '20 000 crédits'),
          _PackButton(label: 'Pack Supporter', price: '5 000 FCFA', credits: '55 000 crédits'),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmlCreditPurchaseScreen())), icon: const Icon(Icons.lock_open), label: const Text('ACHETER DES CRÉDITS', style: TextStyle(fontWeight: FontWeight.w900)), style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white))),
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: Colors.white54, size: 20), SizedBox(width: 10),
            Expanded(child: Text('Les montants et packs affichés ici sont une proposition de configuration. Aucun paiement n’est encore déclenché depuis cette version.', style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4))),
          ])),
        ]),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final IconData icon; final String title, note; final int value; final Color color;
  const _BalanceCard({required this.icon, required this.title, required this.note, required this.value, required this.color});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(.25))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 25), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('$value', style: TextStyle(color: color, fontSize: 23, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(note, style: const TextStyle(color: Colors.white38, fontSize: 9, height: 1.25))]));
}

class _PackButton extends StatelessWidget {
  final String label, price, credits;
  const _PackButton({required this.label, required this.price, required this.credits});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(credits, style: const TextStyle(color: _blue, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(price, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
