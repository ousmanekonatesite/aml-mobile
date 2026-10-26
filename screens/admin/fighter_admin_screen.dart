import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets_url_media_preview.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);

class AmlFighterAdminScreen extends StatefulWidget {
  const AmlFighterAdminScreen({super.key});
  @override
  State<AmlFighterAdminScreen> createState() => _AmlFighterAdminScreenState();
}

class _AmlFighterAdminScreenState extends State<AmlFighterAdminScreen> {
  List<Map<String, dynamic>> fighters = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final client = SupabaseService.client;
    if (client == null) {
      setState(() { loading = false; error = SupabaseService.configurationMessage; });
      return;
    }
    try {
      final rows = await client.from('fighters').select('id,first_name,last_name,nickname,slug,country_code,city,fighting_style,is_active,is_verified,photo_url').order('created_at', ascending: false);
      if (!mounted) return;
      setState(() { fighters = List<Map<String, dynamic>>.from(rows); loading = false; error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = 'Impossible de charger les fighters : $e'; });
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? fighter]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (_) => _FighterForm(fighter: fighter),
    );
    if (changed == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> fighter) async {
    final client = SupabaseService.client;
    if (client == null) return;
    await client.from('fighters').update({'is_active': !(fighter['is_active'] == true)}).eq('id', fighter['id']);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        title: const Text('Fighters AML', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: () => _openEditor(), icon: const Icon(Icons.add))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))))
              : RefreshIndicator(color: _blue, onRefresh: _load, child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: fighters.length,
                  itemBuilder: (_, i) {
                    final f = fighters[i];
                    final name = '${f['first_name'] ?? ''} ${f['last_name'] ?? ''}'.trim();
                    return Card(
                      color: _surface,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: _blue.withOpacity(.12), child: const Icon(Icons.sports_mma, color: _blue)),
                        title: Text(name.isEmpty ? 'Fighter AML' : name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${f['nickname'] ?? ''}\n${f['country_code'] ?? '—'} • ${f['city'] ?? '—'} • ${f['is_active'] == true ? 'Actif' : 'Inactif'}', style: const TextStyle(color: Colors.white54)),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) { if (v == 'edit') _openEditor(f); if (v == 'toggle') _toggle(f); },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                            PopupMenuItem(value: 'toggle', child: Text(f['is_active'] == true ? 'Désactiver' : 'Activer')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openEditor(), backgroundColor: _blue, label: const Text('Nouveau fighter', style: TextStyle(fontWeight: FontWeight.w900)), icon: const Icon(Icons.add)),
    );
  }
}

class _FighterForm extends StatefulWidget {
  final Map<String, dynamic>? fighter;
  const _FighterForm({this.fighter});
  @override State<_FighterForm> createState() => _FighterFormState();
}

class _FighterFormState extends State<_FighterForm> {
  late final TextEditingController first, last, nick, slug, city, style, photo, dob, debut, heightCm, weightKg, reachCm;
  final Map<String, TextEditingController> stat = {};
  final Map<String, TextEditingController> social = {};
  static const _statFields = <List<String>>[
    ['wins', 'Victoires'], ['losses', 'Défaites'], ['draws', 'Nuls'], ['no_contests', 'No contest'],
    ['ko_tko_wins', 'Victoires KO/TKO'], ['submission_wins', 'Victoires soumission'], ['decision_wins', 'Victoires décision'],
    ['ko_tko_losses', 'Défaites KO/TKO'], ['submission_losses', 'Défaites soumission'], ['decision_losses', 'Défaites décision'],
    ['total_rounds', 'Rounds combattus'],
  ];
  static const _socialFields = <List<String>>[
    ['instagram', 'Instagram'], ['facebook', 'Facebook'], ['x', 'X / Twitter'], ['tiktok', 'TikTok'], ['youtube', 'YouTube'],
  ];
  bool verified = false, active = true, saving = false, countriesLoading = true;
  List<Map<String, dynamic>> countries = [], weights = [], clubs = [];
  String? selectedCountryCode, weightId, clubId;

  @override
  void initState() {
    super.initState();
    final f = widget.fighter ?? {};
    String t(String k) => '${f[k] ?? ''}';
    first = TextEditingController(text: t('first_name'));
    last = TextEditingController(text: t('last_name'));
    nick = TextEditingController(text: t('nickname'));
    slug = TextEditingController(text: t('slug'));
    city = TextEditingController(text: t('city'));
    style = TextEditingController(text: '${f['fighting_style'] ?? 'MMA'}');
    photo = TextEditingController(text: t('photo_url'));
    dob = TextEditingController(text: t('date_of_birth'));
    debut = TextEditingController(text: t('professional_debut'));
    heightCm = TextEditingController(text: t('height_cm'));
    weightKg = TextEditingController(text: t('weight_kg'));
    reachCm = TextEditingController(text: t('reach_cm'));
    for (final s in _statFields) { stat[s[0]] = TextEditingController(text: '0'); }
    for (final s in _socialFields) { social[s[0]] = TextEditingController(); }
    final cc = t('country_code').trim();
    selectedCountryCode = cc.isEmpty ? null : cc.toUpperCase();
    weightId = f['weight_category_id']?.toString();
    clubId = f['club_id']?.toString();
    verified = f['is_verified'] == true;
    active = f['is_active'] != false;
    _loadCountries();
    _loadExtras();
  }

  Future<void> _loadCountries() async {
    try {
      final rows = await SupabaseService.client!.from('countries').select('code,name,flag_emoji').order('name');
      if (!mounted) return;
      final loaded = List<Map<String, dynamic>>.from(rows);
      setState(() { countries = loaded; countriesLoading = false; });
      if (selectedCountryCode != null && !countries.any((c) => c['code'].toString().toUpperCase() == selectedCountryCode)) {
        setState(() => selectedCountryCode = null);
      }
    } catch (_) { if (mounted) setState(() => countriesLoading = false); }
  }

  Future<void> _loadExtras() async {
    final client = SupabaseService.client;
    if (client == null) return;
    try { weights = List<Map<String, dynamic>>.from(await client.from('weight_categories').select('id,name').order('name')); } catch (_) {}
    try { clubs = List<Map<String, dynamic>>.from(await client.from('clubs').select('id,name').order('name')); } catch (_) {}
    final id = widget.fighter?['id']?.toString();
    if (id != null) {
      try {
        final s = await client.from('fighter_stats').select('*').eq('fighter_id', id).maybeSingle();
        if (s != null) { for (final f in _statFields) { stat[f[0]]!.text = '${s[f[0]] ?? 0}'; } }
      } catch (_) {}
      try {
        final rows = await client.from('fighter_social_links').select('platform,url').eq('fighter_id', id);
        for (final r in List<Map<String, dynamic>>.from(rows)) { social[r['platform'].toString()]?.text = '${r['url'] ?? ''}'; }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [first, last, nick, slug, city, style, photo, dob, debut, heightCm, weightKg, reachCm, ...stat.values, ...social.values]) { c.dispose(); }
    super.dispose();
  }

  num? _num(String v) => num.tryParse(v.trim().replaceAll(',', '.'));

  Future<void> _pickDate(TextEditingController c) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(c.text.trim()) ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => c.text = picked.toIso8601String().substring(0, 10));
  }

  Future<void> _addNamed(String table, String title) async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom')),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Créer'))],
      ),
    );
    final value = name.text.trim();
    name.dispose();
    if (ok != true || value.isEmpty) return;
    try {
      final created = await SupabaseService.client!.from(table).insert({'name': value}).select('id,name').single();
      await _loadExtras();
      if (!mounted) return;
      setState(() { if (table == 'clubs') { clubId = created['id'].toString(); } else { weightId = created['id'].toString(); } });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Création impossible : $e')));
    }
  }

  Future<void> save() async {
    if (first.text.trim().isEmpty || last.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le prénom et le nom sont obligatoires.')));
      return;
    }
    if (slug.text.trim().isEmpty) {
      final source = '${first.text.trim()}-${last.text.trim()}'.toLowerCase();
      slug.text = source.replaceAll(RegExp(r"[^a-z0-9]+"), '-').replaceAll(RegExp(r"^-|-$"), '');
    }
    final client = SupabaseService.client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supabase n’est pas configuré.')));
      return;
    }
    setState(() => saving = true);
    final data = <String, dynamic>{
      'first_name': first.text.trim(), 'last_name': last.text.trim(), 'nickname': nick.text.trim().isEmpty ? null : nick.text.trim(),
      'slug': slug.text.trim().toLowerCase(), 'city': city.text.trim().isEmpty ? null : city.text.trim(),
      'country_code': selectedCountryCode,
      'fighting_style': style.text.trim().isEmpty ? 'MMA' : style.text.trim(),
      'photo_url': photo.text.trim().isEmpty ? null : photo.text.trim(), 'is_verified': verified, 'is_active': active,
      'date_of_birth': dob.text.trim().isEmpty ? null : dob.text.trim(),
      'professional_debut': debut.text.trim().isEmpty ? null : debut.text.trim(),
      'height_cm': _num(heightCm.text), 'weight_kg': _num(weightKg.text), 'reach_cm': _num(reachCm.text),
      'weight_category_id': weightId, 'club_id': clubId,
    };
    try {
      final String fighterId;
      if (widget.fighter == null) {
        final inserted = await client.from('fighters').insert(data).select('id').single();
        fighterId = inserted['id'].toString();
      } else {
        await client.from('fighters').update(data).eq('id', widget.fighter!['id']);
        fighterId = widget.fighter!['id'].toString();
      }
      String? warning;
      try {
        final stats = <String, dynamic>{'fighter_id': fighterId, 'updated_at': DateTime.now().toUtc().toIso8601String()};
        for (final f in _statFields) { final v = int.tryParse(stat[f[0]]!.text.trim()) ?? 0; stats[f[0]] = v < 0 ? 0 : v; }
        await client.from('fighter_stats').upsert(stats, onConflict: 'fighter_id');
      } catch (e) { warning = 'le bilan professionnel n’a pas pu l’être ($e)'; }
      try {
        for (final f in _socialFields) {
          final url = social[f[0]]!.text.trim();
          if (url.isEmpty) {
            await client.from('fighter_social_links').delete().eq('fighter_id', fighterId).eq('platform', f[0]);
          } else {
            await client.from('fighter_social_links').upsert({'fighter_id': fighterId, 'platform': f[0], 'url': url}, onConflict: 'fighter_id,platform');
          }
        }
      } catch (e) { warning ??= 'les réseaux sociaux n’ont pas pu l’être ($e)'; }
      if (mounted) {
        if (warning != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profil enregistré, mais $warning')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enregistrement impossible : $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 4),
    child: Text(text, style: const TextStyle(color: _blue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
  );

  Widget _numField(String label, TextEditingController c, {bool decimal = false}) => TextField(
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(labelText: label),
  );

  Widget _dateField(String label, TextEditingController c) => TextField(
    controller: c,
    readOnly: true,
    onTap: () => _pickDate(c),
    decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
  );

  Widget _pair(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, bottom + 18),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.fighter == null ? 'Nouveau fighter' : 'Modifier le fighter', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        _section('PROFIL'),
        _pair(TextField(controller: first, decoration: const InputDecoration(labelText: 'Prénom')), TextField(controller: last, decoration: const InputDecoration(labelText: 'Nom'))),
        TextField(controller: nick, decoration: const InputDecoration(labelText: 'Surnom')),
        TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug public')),
        _pair(
          countriesLoading
              ? const InputDecorator(decoration: InputDecoration(labelText: 'Pays'), child: LinearProgressIndicator())
              : DropdownButtonFormField<String>(
                  value: countries.any((c) => c['code'].toString().toUpperCase() == selectedCountryCode) ? selectedCountryCode : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pays'),
                  items: countries.map((c) => DropdownMenuItem<String>(value: c['code'].toString().toUpperCase(), child: Text('${c['flag_emoji'] ?? ''} ${c['name']}', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => selectedCountryCode = v),
                ),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'Ville')),
        ),
        _pair(_dateField('Date de naissance', dob), _dateField('Début professionnel', debut)),
        TextField(controller: photo, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL photo officielle'), onChanged: (_) => setState(() {})),
        if (photo.text.trim().isNotEmpty) AmlUrlMediaPreview(url: photo.text.trim(), compact: true),
        _section('PHYSIQUE & CATÉGORIE'),
        _pair(_numField('Taille (cm)', heightCm, decimal: true), _numField('Poids (kg)', weightKg, decimal: true)),
        _numField('Allonge (cm)', reachCm, decimal: true),
        DropdownButtonFormField<String>(
          value: weights.any((w) => w['id'].toString() == weightId) ? weightId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Catégorie de poids'),
          items: weights.map((w) => DropdownMenuItem<String>(value: w['id'].toString(), child: Text('${w['name']}'))).toList(),
          onChanged: (v) => setState(() => weightId = v),
        ),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _addNamed('weight_categories', 'Nouvelle catégorie de poids'), icon: const Icon(Icons.add, size: 16), label: const Text('Nouvelle catégorie'))),
        DropdownButtonFormField<String>(
          value: clubs.any((c) => c['id'].toString() == clubId) ? clubId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Club / équipe'),
          items: clubs.map((c) => DropdownMenuItem<String>(value: c['id'].toString(), child: Text('${c['name']}'))).toList(),
          onChanged: (v) => setState(() => clubId = v),
        ),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _addNamed('clubs', 'Nouveau club'), icon: const Icon(Icons.add, size: 16), label: const Text('Nouveau club'))),
        TextField(controller: style, decoration: const InputDecoration(labelText: 'Style de combat')),
        _section('CARTE PROFESSIONNELLE — BILAN DE COMPÉTITION'),
        _pair(_numField('Victoires', stat['wins']!), _numField('Défaites', stat['losses']!)),
        _pair(_numField('Nuls', stat['draws']!), _numField('No contest', stat['no_contests']!)),
        _pair(_numField('Victoires KO/TKO', stat['ko_tko_wins']!), _numField('Victoires soumission', stat['submission_wins']!)),
        _pair(_numField('Victoires décision', stat['decision_wins']!), _numField('Rounds combattus', stat['total_rounds']!)),
        _pair(_numField('Défaites KO/TKO', stat['ko_tko_losses']!), _numField('Défaites soumission', stat['submission_losses']!)),
        _numField('Défaites décision', stat['decision_losses']!),
        _section('RÉSEAUX SOCIAUX'),
        for (final f in _socialFields) TextField(controller: social[f[0]], keyboardType: TextInputType.url, decoration: InputDecoration(labelText: f[1], hintText: 'https://…')),
        _section('STATUT'),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: verified, onChanged: (v) => setState(() => verified = v), title: const Text('Fighter vérifié')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setState(() => active = v), title: const Text('Fighter actif')),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: saving ? null : save, style: ElevatedButton.styleFrom(backgroundColor: _blue), child: saving ? const CircularProgressIndicator(color: Colors.white) : const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.w900)))),
      ])),
    );
  }
}
