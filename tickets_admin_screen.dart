import 'package:flutter/material.dart';
import '../../services/admin_repository.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);

class AmlTicketsAdminScreen extends StatefulWidget {
  const AmlTicketsAdminScreen({super.key});
  @override State<AmlTicketsAdminScreen> createState() => _AmlTicketsAdminScreenState();
}

class _AmlTicketsAdminScreenState extends State<AmlTicketsAdminScreen> {
  final repo = AdminRepository();
  late Future<List<Map<String, dynamic>>> future;
  List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    future = repo.adminTicketOffers();
    _loadEvents();
  }

  void reload() => setState(() => future = repo.adminTicketOffers());

  Future<void> _loadEvents() async {
    try {
      final result = await repo.adminEvents();
      if (mounted) setState(() => events = result);
    } catch (_) {}
  }

  String eventName(String? id) {
    for (final event in events) {
      if (event['id']?.toString() == id) {
        return event['name']?.toString() ?? 'Événement';
      }
    }
    return 'Événement';
  }

  Future<void> edit([Map<String, dynamic>? offer]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (_) => _TicketForm(
        repo: repo,
        events: events,
        offer: offer,
      ),
    );
    if (ok == true) reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black,
        title: const Text('Billetterie AML', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () => edit(),
            icon: const Icon(Icons.add, color: _blue),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle offre', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snapshot.error}', textAlign: TextAlign.center),
            ));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune offre de billet renseignée.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: _blue,
            onRefresh: () async => reload(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final offer = rows[index];
                return Card(
                  color: _surface,
                  child: ListTile(
                    title: Text(
                      offer['name']?.toString() ?? 'Billet',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${eventName(offer['event_id']?.toString())}\n${offer['price_xof'] ?? 'Prix à renseigner'} ${offer['currency'] ?? 'XOF'} • ${offer['sales_status'] ?? 'draft'}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') await edit(offer);
                        if (value == 'delete') {
                          await repo.deleteTicketOffer(offer['id'].toString());
                          reload();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
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

class _TicketForm extends StatefulWidget {
  final AdminRepository repo;
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic>? offer;

  const _TicketForm({required this.repo, required this.events, this.offer});

  @override State<_TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends State<_TicketForm> {
  late final TextEditingController name;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController stock;
  late final TextEditingController url;
  late final TextEditingController order;
  String? eventId;
  String? status;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.offer ?? {};
    name = TextEditingController(text: o['name']?.toString() ?? '');
    description = TextEditingController(text: o['description']?.toString() ?? '');
    price = TextEditingController(text: o['price_xof']?.toString() ?? '');
    stock = TextEditingController(text: o['stock_remaining']?.toString() ?? '');
    url = TextEditingController(text: o['purchase_url']?.toString() ?? '');
    order = TextEditingController(text: o['sort_order']?.toString() ?? '0');
    eventId = o['event_id']?.toString();
    status = o['sales_status']?.toString() ?? 'draft';
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    stock.dispose();
    url.dispose();
    order.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (eventId == null || name.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      await widget.repo.saveTicketOffer({
        'event_id': eventId,
        'name': name.text.trim(),
        'description': description.text.trim().isEmpty ? null : description.text.trim(),
        'price_xof': price.text.trim().isEmpty ? null : num.tryParse(price.text.trim()),
        'currency': 'XOF',
        'stock_remaining': stock.text.trim().isEmpty ? null : int.tryParse(stock.text.trim()),
        'sales_status': status,
        'purchase_url': url.text.trim().isEmpty ? null : url.text.trim(),
        'sort_order': int.tryParse(order.text.trim()) ?? 0,
      }, widget.offer?['id']?.toString());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enregistrement impossible : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottom + 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.offer == null ? 'Nouvelle offre' : 'Modifier l’offre', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: eventId,
              decoration: const InputDecoration(labelText: 'Événement'),
              items: widget.events.map((event) => DropdownMenuItem<String>(
                value: event['id'].toString(),
                child: Text(event['name']?.toString() ?? 'Événement'),
              )).toList(),
              onChanged: (value) => setState(() => eventId = value),
            ),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom du billet')),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
            Row(children: [
              Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix XOF'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock'))),
            ]),
            TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Lien officiel d’achat')),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Brouillon')),
                DropdownMenuItem(value: 'on_sale', child: Text('En vente')),
                DropdownMenuItem(value: 'sold_out', child: Text('Épuisé')),
                DropdownMenuItem(value: 'closed', child: Text('Fermé')),
              ],
              onChanged: (value) => setState(() => status = value ?? 'draft'),
            ),
            TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ordre')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(backgroundColor: _blue),
                child: saving ? const CircularProgressIndicator(color: Colors.white) : const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
