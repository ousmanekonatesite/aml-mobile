import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);

/// Conditions d'attribution automatique disponibles pour un badge.
const Map<String, String> kBadgeCriteria = {
  'profile_complete': 'Profil complété (nom, pseudo, ville)',
  'posts': 'Publications dans la communauté',
  'comments': 'Commentaires',
  'predictions': 'Pronostics envoyés',
  'correct_predictions': 'Pronostics justes',
  'connections': 'Abonnés mutuels',
  'tickets': 'Billets achetés',
  'orders': 'Commandes boutique',
  'xp': 'XP cumulés',
  'manual': 'Manuel (aucune attribution automatique)',
};

/// Configuration des badges : créer, modifier, activer, supprimer et recalculer.
class AmlBadgesAdminScreen extends StatefulWidget {
  const AmlBadgesAdminScreen({super.key});
  @override
  State<AmlBadgesAdminScreen> createState() => _AmlBadgesAdminScreenState();
}

class _AmlBadgesAdminScreenState extends State<AmlBadgesAdminScreen> {
  List<Map<String, dynamic>> badges = [];
  final Map<String, int> holders = {};
  bool loading = true;
  bool recalculating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    final client = SupabaseService.client;
    if (client == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final rows = await client.from('badges').select('*').order('sort_order').order('name');
      badges = List<Map<String, dynamic>>.from(rows);
      holders.clear();
      try {
        final ub = await client.from('user_badges').select('badge_id').limit(5000);
        for (final r in List<Map<String, dynamic>>.from(ub)) {
          final id = r['badge_id'].toString();
          holders[id] = (holders[id] ?? 0) + 1;
        }
      } catch (_) {}
    } catch (e) {
      _toast('Chargement impossible : $e');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _toggle(Map<String, dynamic> badge, bool value) async {
    try {
      await SupabaseService.client!.from('badges').update({'is_active': value, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', badge['id']);
      setState(() => badge['is_active'] = value);
    } catch (e) {
      _toast('Modification impossible : $e');
    }
  }

  Future<void> _openForm([Map<String, dynamic>? badge]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BadgeForm(badge: badge),
    );
    if (saved == true) _load();
  }

  Future<void> _recalculate() async {
    setState(() => recalculating = true);
    try {
      final result = await SupabaseService.client!.rpc('aml_admin_recalculate_badges');
      _toast('Badges recalculés : ${result ?? 0} nouveau(x) badge(s) attribué(s).');
      await _load();
    } catch (e) {
      _toast('Recalcul impossible : $e');
    } finally {
      if (mounted) setState(() => recalculating = false);
    }
  }

  String _condition(Map<String, dynamic> b) {
    final type = b['criteria_type']?.toString() ?? 'manual';
    final label = kBadgeCriteria[type] ?? type;
    if (type == 'manual') return label;
    if (type == 'profile_complete') return label;
    return '$label ≥ ${b['criteria_value'] ?? 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau badge', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : RefreshIndicator(
              color: _blue,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  Row(children: [
                    const Expanded(child: Text('BADGES', style: TextStyle(color: _blue, fontWeight: FontWeight.w900, letterSpacing: 1))),
                    OutlinedButton.icon(
                      onPressed: recalculating ? null : _recalculate,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(recalculating ? 'Calcul…' : 'Recalculer'),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  const Text('Les badges sont attribués automatiquement dès que la condition est remplie, avec un bonus d’XP. « Recalculer » les attribue aussitôt aux membres qui remplissent déjà la condition.', style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 14),
                  if (badges.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Aucun badge. Crée le premier avec le bouton ci-dessous.', style: TextStyle(color: Colors.white54)))),
                  ...badges.map(_tile),
                ],
              ),
            ),
    );
  }

  Widget _tile(Map<String, dynamic> b) {
    final active = b['is_active'] != false;
    final emoji = (b['icon_emoji'] ?? '').toString();
    final count = holders[b['id'].toString()] ?? 0;
    return Opacity(
      opacity: active ? 1 : .5,
      child: InkWell(
        onTap: () => _openForm(b),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _blue.withOpacity(.12), shape: BoxShape.circle),
              child: emoji.isNotEmpty ? Text(emoji, style: const TextStyle(fontSize: 24)) : const Icon(Icons.workspace_premium, color: _blue),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b['name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
              if ((b['description'] ?? '').toString().isNotEmpty) Text('${b['description']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${_condition(b)} • +${b['xp_reward'] ?? 0} XP • $count membre(s)', style: const TextStyle(color: _blue, fontSize: 11)),
            ])),
            Switch(value: active, onChanged: (v) => _toggle(b, v)),
          ]),
        ),
      ),
    );
  }
}

class _BadgeForm extends StatefulWidget {
  final Map<String, dynamic>? badge;
  const _BadgeForm({this.badge});
  @override
  State<_BadgeForm> createState() => _BadgeFormState();
}

class _BadgeFormState extends State<_BadgeForm> {
  late final TextEditingController name, description, emoji, iconUrl, threshold, xp, order;
  String criteria = 'posts';
  bool active = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.badge ?? {};
    String t(String k, [String d = '']) => '${b[k] ?? d}';
    name = TextEditingController(text: t('name'));
    description = TextEditingController(text: t('description'));
    emoji = TextEditingController(text: t('icon_emoji'));
    iconUrl = TextEditingController(text: t('icon_url'));
    threshold = TextEditingController(text: t('criteria_value', '1'));
    xp = TextEditingController(text: t('xp_reward', '10'));
    order = TextEditingController(text: t('sort_order', '100'));
    final c = b['criteria_type']?.toString();
    criteria = kBadgeCriteria.containsKey(c) ? c! : 'posts';
    active = b['is_active'] != false;
  }

  @override
  void dispose() {
    for (final c in [name, description, emoji, iconUrl, threshold, xp, order]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le nom du badge est obligatoire.')));
      return;
    }
    final client = SupabaseService.client;
    if (client == null) return;
    setState(() => saving = true);
    int n(TextEditingController c, int d, {int min = 0}) {
      final v = int.tryParse(c.text.trim()) ?? d;
      return v < min ? min : v;
    }
    final data = <String, dynamic>{
      'name': name.text.trim(),
      'description': description.text.trim().isEmpty ? null : description.text.trim(),
      'icon_emoji': emoji.text.trim().isEmpty ? null : emoji.text.trim(),
      'icon_url': iconUrl.text.trim().isEmpty ? null : iconUrl.text.trim(),
      'criteria_type': criteria,
      'criteria_value': (criteria == 'manual' || criteria == 'profile_complete') ? 1 : n(threshold, 1, min: 1),
      'xp_reward': n(xp, 0),
      'sort_order': n(order, 100),
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      if (widget.badge == null) {
        await client.from('badges').insert(data);
      } else {
        await client.from('badges').update(data).eq('id', widget.badge!['id']);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final text = e.toString().contains('badges_name_key') || e.toString().contains('duplicate')
          ? 'Un badge porte déjà ce nom.'
          : 'Enregistrement impossible : $e';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer ce badge ?'),
        content: const Text('Le badge sera retiré à tous les membres qui l’ont obtenu. Les XP déjà gagnés sont conservés.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer'))],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client!.from('badges').delete().eq('id', widget.badge!['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression impossible : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsValue = criteria != 'manual' && criteria != 'profile_complete';
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.badge == null ? 'Nouveau badge' : 'Modifier le badge', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom du badge')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Description (condition affichée au membre)')),
          Row(children: [
            SizedBox(width: 90, child: TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: iconUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Image (URL, facultatif)'))),
          ]),
          DropdownButtonFormField<String>(
            value: criteria,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Condition d’attribution'),
            items: kBadgeCriteria.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => criteria = v ?? 'posts'),
          ),
          if (needsValue) TextField(controller: threshold, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valeur à atteindre (ex. 10)')),
          Row(children: [
            Expanded(child: TextField(controller: xp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bonus XP'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ordre d’affichage'))),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setState(() => active = v), title: const Text('Badge actif')),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: _blue), child: saving ? const CircularProgressIndicator(color: Colors.white) : const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.w900)))),
          if (widget.badge != null) Center(child: TextButton(onPressed: _delete, child: const Text('Supprimer ce badge', style: TextStyle(color: Colors.redAccent)))),
        ]),
      ),
    );
  }
}
