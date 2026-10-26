import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/ticket_repository.dart';

const Color _ticketBlue = Color(0xFF00AEEF);
const Color _ticketBlack = Color(0xFF050505);
const Color _ticketSurface = Color(0xFF111111);

class AmlTicketControlScreen extends StatefulWidget {
  const AmlTicketControlScreen({super.key});
  @override
  State<AmlTicketControlScreen> createState() => _AmlTicketControlScreenState();
}

class _AmlTicketControlScreenState extends State<AmlTicketControlScreen> {
  final TicketRepository repo = TicketRepository();
  final TextEditingController code = TextEditingController();
  final MobileScannerController scanner = MobileScannerController();
  String status = 'all';
  bool scanning = false;
  String scanMode = 'auto';
  bool validating = false;
  bool detected = false;
  String? message;
  bool? lastSuccess;
  late Future<List<Map<String, dynamic>>> tickets;

  @override
  void initState() {
    super.initState();
    tickets = repo.adminTickets();
  }

  @override
  void dispose() {
    code.dispose();
    scanner.dispose();
    super.dispose();
  }

  void reload() => setState(() => tickets = repo.adminTickets(status: status));

  Future<void> validate(String value) async {
    if (validating) return;
    final raw = value.trim();
    if (raw.isEmpty) return;
    setState(() { validating = true; message = null; lastSuccess = null; });
    try {
      final result = await repo.redeemTicket(raw, mode: scanMode);
      if (!mounted) return;
      setState(() {
        final action = (result['scan_action'] ?? 'entry').toString();
        final people = (result['quantity'] as num?)?.toInt() ?? 1;
        final who = people > 1 ? ' ($people personnes)' : '';
        if (result['duplicate'] == true) {
          message = 'Billet déjà scanné à l’instant : ${action == 'exit' ? 'sortie' : 'entrée'} déjà prise en compte.';
        } else if (action == 'exit') {
          message = 'SORTIE enregistrée$who. Le billet pourra rentrer en étant scanné à nouveau.';
        } else {
          message = 'ENTRÉE validée$who — entrée n°${result['entry_count'] ?? 1}.';
        }
        lastSuccess = true;
        code.clear();
      });
      reload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = e.toString().replaceFirst('Exception: ', '');
        lastSuccess = false;
      });
    } finally {
      if (mounted) setState(() => validating = false);
    }
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (detected || validating) return;
    final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    detected = true;
    await scanner.stop();
    await validate(value);
    if (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      detected = false;
      if (scanning) await scanner.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ticketBlack,
      appBar: AppBar(
        backgroundColor: _ticketBlack,
        title: const Text('Contrôle des billets', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(tooltip: 'Actualiser', onPressed: reload, icon: const Icon(Icons.refresh, color: _ticketBlue))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 270,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: _ticketSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _ticketBlue.withOpacity(.5))),
            child: scanning
                ? Stack(fit: StackFit.expand, children: [
                    MobileScanner(controller: scanner, onDetect: onDetect),
                    Align(alignment: Alignment.bottomCenter, child: Container(color: Colors.black87, padding: const EdgeInsets.all(10), child: const Text('Place le QR du billet dans le cadre', textAlign: TextAlign.center))),
                  ])
                : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.qr_code_scanner, color: _ticketBlue, size: 56), SizedBox(height: 8), Text('Scanner QR désactivé')])),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () async {
                if (scanning) { await scanner.stop(); setState(() => scanning = false); }
                else { setState(() => scanning = true); }
              },
              icon: Icon(scanning ? Icons.stop : Icons.camera_alt),
              label: Text(scanning ? 'ARRÊTER LE SCAN' : 'OUVRIR LE SCANNER'),
              style: ElevatedButton.styleFrom(backgroundColor: _ticketBlue, foregroundColor: Colors.black),
            )),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final m in const [['auto', 'Auto (entrée / sortie)'], ['entry', 'Entrée'], ['exit', 'Sortie']])
              ChoiceChip(label: Text(m[1]), selected: scanMode == m[0], onSelected: (_) => setState(() => scanMode = m[0])),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: 'Ou saisir le code du billet', suffixIcon: IconButton(icon: const Icon(Icons.check_circle, color: _ticketBlue), onPressed: validating ? null : () => validate(code.text)), border: const OutlineInputBorder()),
            onSubmitted: validate,
          ),
          if (validating) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: _ticketBlue))),
          if (message != null) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (lastSuccess == true ? Colors.green : Colors.red).withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Text(message!, style: TextStyle(color: lastSuccess == true ? Colors.greenAccent : Colors.redAccent))),
          const SizedBox(height: 24),
          const Text('Registre des billets', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Filtrer par statut'), items: const [DropdownMenuItem(value: 'all', child: Text('Tous')), DropdownMenuItem(value: 'valid', child: Text('Valides')), DropdownMenuItem(value: 'used', child: Text('Utilisés')), DropdownMenuItem(value: 'cancelled', child: Text('Annulés')), DropdownMenuItem(value: 'refunded', child: Text('Remboursés'))], onChanged: (v) { if (v != null) setState(() { status = v; tickets = repo.adminTickets(status: v); }); }),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: tickets,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _ticketBlue)));
              if (snap.hasError) return Text('Impossible de charger les billets : ${snap.error}', style: const TextStyle(color: Colors.redAccent));
              final rows = snap.data ?? [];
              if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(18), child: Text('Aucun billet pour ce filtre.', style: TextStyle(color: Colors.white60)));
              final inside = rows.where((t) => t['is_inside'] == true).fold<int>(0, (sum, t) => sum + ((t['quantity'] as num?)?.toInt() ?? 1));
              return Column(children: [Padding(padding: const EdgeInsets.only(bottom: 8), child: Align(alignment: Alignment.centerLeft, child: Text('Dans la salle : $inside personne(s)', style: const TextStyle(color: _ticketBlue, fontWeight: FontWeight.w800)))), ...rows.map((t) {
                final event = t['event'] is Map ? Map<String, dynamic>.from(t['event']) : <String, dynamic>{};
                return Card(color: _ticketSurface, child: ListTile(
                  leading: Icon(t['is_inside'] == true ? Icons.login : (t['status'] == 'valid' || t['status'] == 'used') ? Icons.confirmation_number : Icons.block, color: t['is_inside'] == true ? Colors.greenAccent : (t['status'] == 'valid' || t['status'] == 'used') ? _ticketBlue : Colors.white54),
                  title: Text(t['ticket_code']?.toString() ?? 'Sans code', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${event['name'] ?? 'Événement'}\n${t['is_inside'] == true ? 'Dans la salle' : ((t['entry_count'] as num?)?.toInt() ?? 0) > 0 ? 'Sorti (${t['entry_count']} entrée(s))' : (t['status'] == 'valid' || t['status'] == 'used') ? 'Pas encore entré' : '${t['status']}'} • ${t['amount_credits'] ?? 0} crédits', style: const TextStyle(color: Colors.white60)),
                  isThreeLine: true,
                ));
              })]);
            },
          ),
        ],
      ),
    );
  }
}
