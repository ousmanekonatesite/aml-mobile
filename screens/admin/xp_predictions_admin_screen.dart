import 'package:flutter/material.dart';
import '../../services/admin_repository.dart';
import '../../services/supabase_service.dart';

const _blue = Color(0xFF00AEEF);
const _surface = Color(0xFF111111);

class AmlXpPredictionsAdminScreen extends StatefulWidget {
  const AmlXpPredictionsAdminScreen({super.key});
  @override
  State<AmlXpPredictionsAdminScreen> createState() => _AmlXpPredictionsAdminScreenState();
}

class _AmlXpPredictionsAdminScreenState extends State<AmlXpPredictionsAdminScreen> {
  final repo = AdminRepository();
  bool loading = true;
  List<Map<String, dynamic>> rules = [];
  List<Map<String, dynamic>> questions = [];
  int xpPerCredit = 100;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final r = await repo.xpRules();
      final q = await repo.predictionQuestionsAdmin();
      var rate = 100;
      try { final row = await SupabaseService.client?.from('aml_wallet_settings').select('xp_per_credit').eq('id', true).maybeSingle(); rate = (row?['xp_per_credit'] as num?)?.toInt() ?? 100; } catch (_) {}
      if (mounted) setState(() { rules = r; questions = q; xpPerCredit = rate; loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editWalletRate() async {
    final controller = TextEditingController(text: '$xpPerCredit');
    final value = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(backgroundColor: _surface, title: const Text('Taux de conversion XP → crédit'), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'XP nécessaires pour 1 crédit')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())), child: const Text('Enregistrer'))]));
    controller.dispose();
    if (value == null || value <= 0) return;
    try { await SupabaseService.client!.from('aml_wallet_settings').upsert({'id': true, 'xp_per_credit': value, 'updated_at': DateTime.now().toUtc().toIso8601String(), 'updated_by': SupabaseService.client!.auth.currentUser!.id}); await _load(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Taux de conversion enregistré.'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $e'))); }
  }

  Future<void> _editRule(Map<String, dynamic> rule) async {
    final controller = TextEditingController(text: '${rule['points'] ?? 0}');
    var active = rule['is_active'] == true;
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: _surface,
          title: Text(rule['label']?.toString() ?? 'Règle XP'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Points XP')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setDialog(() => active = v), title: const Text('Règle active')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, int.tryParse(controller.text.trim()) ?? 0), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await repo.saveXpRule(code: rule['code'].toString(), label: rule['label'].toString(), description: rule['description']?.toString(), points: value < 0 ? 0 : value, isActive: active);
      await _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  String _typeLabel(dynamic t) => switch (t?.toString()) {
        'winner' => 'Vainqueur',
        'method' => 'Méthode',
        'round' => 'Round',
        _ => 'Option',
      };

  /// Tendances : valeurs ajoutées aux pronostics réels (participants et choix par option).
  Future<void> _editTrends(Map<String, dynamic> q) async {
    final client = SupabaseService.client;
    if (client == null) return;
    final id = q['id'].toString();
    List<Map<String, dynamic>> options = [];
    final real = <String, int>{};
    var participantsBoost = 0;
    try {
      options = List<Map<String, dynamic>>.from(await client
          .from('prediction_options')
          .select('id,label,option_type,trend_boost')
          .eq('prediction_id', id)
          .order('option_type')
          .order('created_at'));
      final row = await client.from('prediction_questions').select('trend_participants').eq('id', id).maybeSingle();
      participantsBoost = (row?['trend_participants'] as num?)?.toInt() ?? 0;
      final stats = await client.rpc('aml_prediction_stats', params: {'p_prediction_id': id});
      if (stats is Map) {
        for (final group in ['winner', 'method', 'round']) {
          for (final r in List<Map<String, dynamic>>.from(stats[group] ?? const [])) {
            real[r['id'].toString()] = (r['real_count'] as num?)?.toInt() ?? 0;
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chargement impossible : $e')));
      return;
    }
    if (!mounted) return;
    final participants = TextEditingController(text: '$participantsBoost');
    final controllers = {for (final o in options) o['id'].toString(): TextEditingController(text: '${o['trend_boost'] ?? 0}')};
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Tendances du pronostic'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ces valeurs s’ajoutent aux pronostics réels des utilisateurs pour calculer les pourcentages affichés dans l’application.', style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
              const SizedBox(height: 12),
              TextField(controller: participants, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Participants ajoutés')),
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_typeLabel(o['option_type'])} · ${o['label']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('${real[o['id'].toString()] ?? 0} réel(s) des utilisateurs', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ])),
                    SizedBox(width: 86, child: TextField(controller: controllers[o['id'].toString()], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ajout'))),
                  ]),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok == true) {
      final boosts = {for (final e in controllers.entries) e.key: int.tryParse(e.value.text.trim()) ?? 0};
      try {
        await client.rpc('aml_admin_set_prediction_trends', params: {
          'p_prediction_id': id,
          'p_participants': int.tryParse(participants.text.trim()) ?? 0,
          'p_boosts': boosts,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tendances enregistrées.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $e')));
      }
    }
    participants.dispose();
    for (final c in controllers.values) { c.dispose(); }
  }

  Future<void> _editPredictionXp(Map<String, dynamic> q) async {
    final fields = <String, TextEditingController>{
      'xp_participation': TextEditingController(text: '${q['xp_participation'] ?? 0}'),
      'xp_winner': TextEditingController(text: '${q['xp_winner'] ?? 0}'),
      'xp_method': TextEditingController(text: '${q['xp_method'] ?? 0}'),
      'xp_round': TextEditingController(text: '${q['xp_round'] ?? 0}'),
      'xp_exact': TextEditingController(text: '${q['xp_exact'] ?? 0}'),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Points XP du pronostic'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields.entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: e.value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: e.key.replaceFirst('xp_', '').replaceAll('_', ' '))))).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Enregistrer'))],
      ),
    );
    if (ok == true) {
      int n(String key) => int.tryParse(fields[key]!.text.trim()) ?? 0;
      try {
        await repo.updatePredictionXp(predictionId: q['id'].toString(), participation: n('xp_participation'), winner: n('xp_winner'), method: n('xp_method'), round: n('xp_round'), exact: n('xp_exact'));
        await _load();
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    }
    for (final controller in fields.values) { controller.dispose(); }
  }

  Future<void> _editQuestion([Map<String, dynamic>? q]) async {
    final title = TextEditingController(text: q?['title']?.toString() ?? '');
    final fight = TextEditingController(text: q?['fight_id']?.toString() ?? '');
    final lock = TextEditingController(text: q?['lock_at']?.toString() ?? '');
    String type = q?['question_type']?.toString() ?? 'winner';
    String status = q?['status']?.toString() ?? 'draft';
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          backgroundColor: _surface,
          title: Text(q == null ? 'Nouveau pronostic' : 'Modifier le pronostic'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Question / titre')),
            TextField(controller: fight, decoration: const InputDecoration(labelText: 'ID du combat (fight_id)')),
            DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Type de question'), items: const [DropdownMenuItem(value: 'winner', child: Text('Vainqueur')), DropdownMenuItem(value: 'method', child: Text('Méthode')), DropdownMenuItem(value: 'round', child: Text('Round')), DropdownMenuItem(value: 'mixed', child: Text('Mixte'))], onChanged: (v) => setDialog(() => type = v ?? 'winner')),
            DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Statut'), items: const [DropdownMenuItem(value: 'draft', child: Text('Brouillon')), DropdownMenuItem(value: 'open', child: Text('Ouvert')), DropdownMenuItem(value: 'closed', child: Text('Fermé'))], onChanged: (v) => setDialog(() => status = v ?? 'draft')),
            TextField(controller: lock, decoration: const InputDecoration(labelText: 'Date/heure de clôture ISO (optionnel)')),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')), ElevatedButton(onPressed: title.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, {'title': title.text.trim(), 'fight_id': fight.text.trim().isEmpty ? null : fight.text.trim(), 'question_type': type, 'status': status, 'lock_at': lock.text.trim().isEmpty ? null : lock.text.trim()}), child: const Text('Enregistrer'))],
        ),
      ),
    );
    title.dispose(); fight.dispose(); lock.dispose();
    if (data == null) return;
    try {
      await repo.savePredictionQuestion(data, q?['id']?.toString());
      await _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _manageOptions(Map<String, dynamic> q) async {
    final id = q['id'].toString();
    while (mounted) {
      final options = await repo.predictionOptionsAdmin(id);
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _surface,
          title: Text('Options — ${q['title'] ?? 'Pronostic'}'),
          content: SizedBox(width: 460, child: options.isEmpty ? const Text('Aucune option. Ajoute les choix proposés aux utilisateurs.') : ListView.builder(shrinkWrap: true, itemCount: options.length, itemBuilder: (_, i) {
            final o = options[i];
            return ListTile(title: Text(o['label']?.toString() ?? 'Option'), subtitle: Text('${o['option_type']} • ${o['option_value'] ?? ''}'), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white54), onPressed: () => Navigator.pop(dialogContext, 'delete:${o['id']}')));
          })),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, 'add'), child: const Text('Ajouter une option'))],
        ),
      );
      if (action == null) break;
      if (action == 'add') { await _addOption(id); continue; }
      if (action.startsWith('delete:')) {
        try { await repo.deletePredictionOption(action.substring(7)); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
      }
    }
  }

  Future<void> _addOption(String predictionId) async {
    final label = TextEditingController();
    final value = TextEditingController();
    String type = 'winner';
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Nouvelle option'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: label, decoration: const InputDecoration(labelText: 'Libellé')),
          TextField(controller: value, decoration: const InputDecoration(labelText: 'Valeur métier (optionnel)')),
          DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Type'), items: const [DropdownMenuItem(value: 'winner', child: Text('Vainqueur')), DropdownMenuItem(value: 'method', child: Text('Méthode')), DropdownMenuItem(value: 'round', child: Text('Round'))], onChanged: (v) => setDialog(() => type = v ?? 'winner')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')), ElevatedButton(onPressed: label.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, {'prediction_id': predictionId, 'label': label.text.trim(), 'option_type': type, 'option_value': value.text.trim().isEmpty ? null : value.text.trim(), 'is_correct': false}), child: const Text('Ajouter'))],
      )),
    );
    label.dispose(); value.dispose();
    if (data != null) await repo.savePredictionOption(data, null);
  }

  Future<void> _confirm(Map<String, dynamic> q) async {
    final options = List<Map<String, dynamic>>.from(q['prediction_options'] ?? const []);
    final winners = options.where((o) => o['option_type'] == 'winner').toList();
    final methods = options.where((o) => o['option_type'] == 'method').toList();
    final rounds = options.where((o) => o['option_type'] == 'round').toList();
    String? winner; String? method; String? round;
    final result = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) {
      Widget select(String label, List<Map<String, dynamic>> values, String? value, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label), items: values.map((o) => DropdownMenuItem(value: o['id'].toString(), child: Text(o['label']?.toString() ?? 'Option'))).toList(), onChanged: onChanged);
      return AlertDialog(backgroundColor: _surface, title: const Text('Confirmer le résultat'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(q['title']?.toString() ?? 'Pronostic', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 12), select('Vainqueur', winners, winner, (v) => setDialog(() => winner = v)), if (methods.isNotEmpty) select('Méthode', methods, method, (v) => setDialog(() => method = v)), if (rounds.isNotEmpty) select('Round', rounds, round, (v) => setDialog(() => round = v))])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')), ElevatedButton(onPressed: winner == null ? null : () => Navigator.pop(dialogContext, true), child: const Text('CONFIRMER'))]);
    }));
    if (result != true || winner == null) return;
    try { await repo.confirmPredictionResult(predictionId: q['id'].toString(), winnerOptionId: winner!, methodOptionId: method, roundOptionId: round); await _load(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    return RefreshIndicator(
      color: _blue,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('XP & PRONOSTICS', style: TextStyle(color: _blue, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: .8)),
                    SizedBox(height: 4),
                    Text('Paramétrage des règles et gestion des données métier.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _editQuestion(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouveau'),
                style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(color: _surface, child: ListTile(leading: const Icon(Icons.currency_exchange, color: _blue), title: const Text('Conversion XP → crédit AML', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('$xpPerCredit XP = 1 crédit'), trailing: const Icon(Icons.edit_outlined), onTap: _editWalletRate)),
          _sectionTitle('RÈGLES XP'),
          const SizedBox(height: 8),
          if (rules.isEmpty)
            _emptyBox('Aucune règle XP configurée.')
          else
            ...rules.map(_ruleCard),
          const SizedBox(height: 24),
          _sectionTitle('PRONOSTICS'),
          const SizedBox(height: 6),
          const Text(
            'Les questions, options, points et résultats sont gérés depuis cette interface. Les statistiques utilisateurs restent calculées automatiquement à partir des données enregistrées.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 10),
          if (questions.isEmpty)
            _emptyBox('Aucun pronostic. Crée une question puis ajoute ses options.')
          else
            ...questions.map(_questionCard),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.1),
      );

  Widget _emptyBox(String text) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );

  Widget _ruleCard(Map<String, dynamic> rule) {
    final active = rule['is_active'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? _blue.withValues(alpha: .22) : Colors.white10)),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: _blue.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.bolt_rounded, color: _blue)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rule['label']?.toString() ?? rule['code'].toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(rule['description']?.toString() ?? rule['code'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 6),
              Row(children: [
                _statusChip(active ? 'ACTIVE' : 'INACTIVE', active),
                const SizedBox(width: 7),
                Text(rule['code']?.toString() ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${rule['points'] ?? 0}', style: const TextStyle(color: _blue, fontSize: 19, fontWeight: FontWeight.w900)),
            const Text('XP', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800)),
            IconButton(visualDensity: VisualDensity.compact, tooltip: 'Modifier', onPressed: () => _editRule(rule), icon: const Icon(Icons.edit_outlined, color: _blue, size: 19)),
          ]),
        ],
      ),
    );
  }

  Widget _questionCard(Map<String, dynamic> q) {
    final status = q['status']?.toString() ?? 'draft';
    final settled = q['settled_at'] != null || status == 'closed';
    final options = List<Map<String, dynamic>>.from(q['prediction_options'] ?? const []);
    final type = q['question_type']?.toString() ?? 'winner';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: settled ? _blue.withValues(alpha: .20) : Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(q['title']?.toString() ?? 'Pronostic', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, height: 1.2))),
          _statusChip(status.toUpperCase(), settled ? true : status == 'open'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _miniInfo(Icons.category_outlined, type),
          const SizedBox(width: 10),
          _miniInfo(Icons.list_alt_outlined, '${options.length} options'),
          if (q['fight_id'] != null) ...[const SizedBox(width: 10), _miniInfo(Icons.sports_mma, 'Combat lié')],
        ]),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 11),
          Wrap(spacing: 6, runSpacing: 6, children: options.map((o) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(9)), child: Text(o['label']?.toString() ?? 'Option', style: const TextStyle(fontSize: 10, color: Colors.white70)))).toList()),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: settled ? null : () => _editQuestion(q), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Modifier')),
          OutlinedButton.icon(onPressed: () => _manageOptions(q), icon: const Icon(Icons.list_alt_outlined, size: 16), label: const Text('Options')),
          OutlinedButton.icon(onPressed: () => _editTrends(q), icon: const Icon(Icons.trending_up, size: 16), label: const Text('Tendances')),
          OutlinedButton.icon(onPressed: settled ? null : () => _editPredictionXp(q), icon: const Icon(Icons.bolt_rounded, size: 16), label: const Text('XP')),
          OutlinedButton.icon(onPressed: settled ? null : () => _confirm(q), icon: Icon(settled ? Icons.check_circle : Icons.verified_outlined, size: 16), label: Text(settled ? 'Résultat confirmé' : 'Confirmer')),
          IconButton(tooltip: 'Supprimer', onPressed: settled ? null : () async { try { await repo.deletePredictionQuestion(q['id'].toString()); await _load(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }, icon: const Icon(Icons.delete_outline, color: Colors.white54)),
        ]),
      ]),
    );
  }

  Widget _statusChip(String label, bool positive) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: (positive ? _blue : Colors.white24).withValues(alpha: .12), borderRadius: BorderRadius.circular(20), border: Border.all(color: (positive ? _blue : Colors.white38).withValues(alpha: .35))),
        child: Text(label, style: TextStyle(color: positive ? _blue : Colors.white54, fontSize: 9, fontWeight: FontWeight.w900)),
      );

  Widget _miniInfo(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: Colors.white38), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10))]);

}
