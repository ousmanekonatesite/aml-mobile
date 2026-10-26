import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/ticket_repository.dart';
import '../../services/supabase_service.dart';
import '../../utils/ticket_messages.dart';

const _ticketBlue = Color(0xFF00AEEF);

class AmlMyTicketsScreen extends StatefulWidget {
  const AmlMyTicketsScreen({super.key});
  @override State<AmlMyTicketsScreen> createState() => _AmlMyTicketsScreenState();
}

class _AmlMyTicketsScreenState extends State<AmlMyTicketsScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> tickets = [];
  final ticketRepo = TicketRepository();

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    final c = SupabaseService.client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) { setState(() => loading = false); return; }
    try {
      final rows = await c.from('user_event_tickets').select('id,event_id,ticket_code,quantity,status,is_inside,entry_count,purchased_at,event:events(name,starts_at,venue_name,city,poster_url)').eq('user_id', user.id).order('purchased_at', ascending: false);
      tickets = List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      error = 'Impossible de charger les billets. Vérifie que la migration des billets est appliquée dans Supabase.';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _openShop() async {
    final c = SupabaseService.client;
    if (c?.auth.currentUser == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecte-toi pour acheter un billet.'))); return; }
    final offers = await ticketRepo.eventsWithOffers();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _TicketShopScreen(events: offers, onBought: _load)));
    if (mounted) await _load();
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Mes billets', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(tooltip: 'Acheter un billet', icon: const Icon(Icons.add_shopping_cart, color: _ticketBlue), onPressed: _openShop)]),
    body: loading ? const Center(child: CircularProgressIndicator(color: _ticketBlue))
      : error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center)))
      : tickets.isEmpty ? RefreshIndicator(color: _ticketBlue, onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 120), Icon(Icons.confirmation_number_outlined, size: 64, color: _ticketBlue), SizedBox(height: 18), Center(child: Text('Aucun billet pour le moment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))), SizedBox(height: 8), Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 30), child: Text('Tes billets achetés ou attribués apparaîtront ici.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60))))]))
      : RefreshIndicator(color: _ticketBlue, onRefresh: _load, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: tickets.length, itemBuilder: (context, i) {
          final t = tickets[i]; final event = t['event'] is Map ? Map<String,dynamic>.from(t['event']) : <String,dynamic>{};
          final start = DateTime.tryParse(event['starts_at']?.toString() ?? '');
          final date = start == null ? 'Date à confirmer' : '${start.day.toString().padLeft(2,'0')}/${start.month.toString().padLeft(2,'0')}/${start.year}';
          return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(18), border: Border.all(color: _ticketBlue.withOpacity(.35))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event['name']?.toString() ?? 'Événement AML', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('$date • ${event['venue_name'] ?? event['city'] ?? 'Lieu à confirmer'}', style: const TextStyle(color: Colors.white70)), const Divider(height: 24), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [if (['valid', 'used'].contains((t['status'] ?? 'valid').toString())) Container(padding: const EdgeInsets.all(8), color: Colors.white, child: QrImageView(data: 'AML-TICKET:${t['ticket_code'] ?? t['id']}', version: QrVersions.auto, size: 92)) else const Icon(Icons.qr_code_2, color: Colors.white38, size: 32), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Code : ${t['ticket_code'] ?? 'En attente'}', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(['valid', 'used'].contains((t['status'] ?? 'valid').toString()) ? (t['is_inside'] == true ? 'Tu es dans la salle. Présente ce QR à la sortie, puis à nouveau pour rentrer.' : 'Présente ce QR au contrôle. Il reste valable pour sortir et rentrer.') : 'Ce billet n’est plus valide.', style: const TextStyle(color: Colors.white54, fontSize: 11))])), Text('x${t['quantity'] ?? 1}', style: const TextStyle(color: _ticketBlue, fontWeight: FontWeight.w900))]), const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: Chip(label: Text((t['status'] ?? 'valid').toString().toUpperCase()), backgroundColor: _ticketBlue.withOpacity(.14))) ]));
        })),
  );
}


class _TicketShopScreen extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  final Future<void> Function() onBought;
  const _TicketShopScreen({required this.events, required this.onBought});
  @override State<_TicketShopScreen> createState() => _TicketShopScreenState();
}
class _TicketShopScreenState extends State<_TicketShopScreen> {
  final repo = TicketRepository();
  bool buying = false;
  Future<void> buy(Map<String,dynamic> offer) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Confirmer l’achat'), content: Text('Acheter « ${offer['name']} » pour ${offer['price_xof']} crédits AML ?'), actions: [TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Annuler')), FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Acheter'))]));
    if (ok != true || !mounted) return;
    setState(()=>buying=true);
    try { final result = await repo.buyTicket(offer['id'].toString()); if (!mounted) return; await widget.onBought(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Billet acheté ! Code : ${result['ticket_code'] ?? 'créé'}'))); Navigator.pop(context); }
    catch(e) { if (mounted) await showTicketPurchaseError(context, e); }
    finally { if (mounted) setState(()=>buying=false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Acheter un billet')),
      body: buying
          ? const Center(child: CircularProgressIndicator(color: _ticketBlue))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final event in widget.events) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      event['name']?.toString() ?? 'Événement AML',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  for (final offer in (event['ticket_offers'] as List? ?? const []))
                    Card(
                      color: const Color(0xFF111111),
                      child: ListTile(
                        title: Text(offer['name']?.toString() ?? 'Billet'),
                        subtitle: Text(
                          "${offer['price_xof'] ?? 'Prix à confirmer'} crédits AML • Stock : ${offer['stock_remaining'] ?? 'illimité'}",
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.shopping_cart_checkout, color: _ticketBlue),
                          onPressed: buying ? null : () => buy(Map<String, dynamic>.from(offer)),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
