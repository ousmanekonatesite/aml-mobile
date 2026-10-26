import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../widgets_url_media_preview.dart';
import '../../widgets_face_avatar.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);

class AmlExternalFightersAdminScreen extends StatefulWidget {
  const AmlExternalFightersAdminScreen({super.key});

  @override
  State<AmlExternalFightersAdminScreen> createState() =>
      _AmlExternalFightersAdminScreenState();
}

class _AmlExternalFightersAdminScreenState
    extends State<AmlExternalFightersAdminScreen> {
  bool loading = true;
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> competitions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = SupabaseService.client;
    if (c == null) return;
    try {
      final a = await c
          .from('external_fighters')
          .select(
            'id,competition_id,first_name,last_name,nickname,slug,photo_url,country_code,rights_status,rights_holder,license_reference,rights_expires_at',
          )
          .order('last_name');
      final b = await c
          .from('competitions')
          .select('id,name,short_name')
          .order('name');
      if (!mounted) return;
      setState(() {
        rows = List<Map<String, dynamic>>.from(a);
        competitions = List<Map<String, dynamic>>.from(b);
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  String comp(String? id) {
    final x = competitions.where((e) => e['id']?.toString() == id).toList();
    if (x.isEmpty) return 'Organisation';
    return (x.first['short_name'] ?? x.first['name'] ?? 'Organisation')
        .toString();
  }

  String _rights(String s) => {
        'authorized': 'Autorisé',
        'pending': 'En attente',
        'expired': 'Expiré',
        'denied': 'Refusé',
      }[s] ?? s;

  Future<void> _edit([Map<String, dynamic>? fighter]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (_) => _ExternalForm(
        fighter: fighter,
        competitions: competitions,
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        title: const Text(
          'Fighters externes',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: _blue),
            )
          : RefreshIndicator(
              color: _blue,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final f = rows[i];
                  final photo = f['photo_url']?.toString();
                  final rights =
                      f['rights_status']?.toString() ?? 'pending';

                  return Card(
                    color: _surface,
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      leading: AmlFaceAvatar(radius: 25, image: photo != null && photo.isNotEmpty
                            ? NetworkImage(photo)
                            : null, child: photo == null || photo.isEmpty
                            ? const Icon(Icons.sports_mma, color: _blue)
                            : null),
                      title: Text(
                        '${f['first_name'] ?? ''} ${f['last_name'] ?? ''}'
                            .trim(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${comp(f['competition_id']?.toString())}\nDroits : ${_rights(rights)}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        onPressed: () => _edit(f),
                        icon: const Icon(Icons.edit, color: _blue),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _blue,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _ExternalForm extends StatefulWidget {
  final Map<String, dynamic>? fighter;
  final List<Map<String, dynamic>> competitions;

  const _ExternalForm({
    this.fighter,
    required this.competitions,
  });

  @override
  State<_ExternalForm> createState() => _ExternalFormState();
}

class _ExternalFormState extends State<_ExternalForm> {
  late final TextEditingController first;
  late final TextEditingController last;
  late final TextEditingController nick;
  late final TextEditingController slug;
  late final TextEditingController country;
  late final TextEditingController photo;
  late final TextEditingController holder;
  late final TextEditingController license;

  String? competitionId;
  String? status;
  DateTime? expires;
  bool saving = false;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final f = widget.fighter ?? {};
    first = TextEditingController(text: '${f['first_name'] ?? ''}');
    last = TextEditingController(text: '${f['last_name'] ?? ''}');
    nick = TextEditingController(text: '${f['nickname'] ?? ''}');
    slug = TextEditingController(text: '${f['slug'] ?? ''}');
    country = TextEditingController(text: '${f['country_code'] ?? ''}');
    photo = TextEditingController(text: '${f['photo_url'] ?? ''}');
    holder = TextEditingController(text: '${f['rights_holder'] ?? ''}');
    license = TextEditingController(text: '${f['license_reference'] ?? ''}');
    competitionId = f['competition_id']?.toString();
    status = f['rights_status']?.toString() ?? 'pending';
    expires = DateTime.tryParse(f['rights_expires_at']?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final x in [
      first,
      last,
      nick,
      slug,
      country,
      photo,
      holder,
      license,
    ]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (f == null) return;

    final c = SupabaseService.client;
    if (c == null) return;

    try {
      final bytes = await f.readAsBytes();
      final path =
          'external/${widget.fighter?['id'] ?? DateTime.now().microsecondsSinceEpoch}_${f.name}';

      await c.storage.from('fighter-media').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      photo.text = c.storage.from('fighter-media').getPublicUrl(path);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload impossible : $e')),
        );
      }
    }
  }

  Future<void> save() async {
    final c = SupabaseService.client;
    if (c == null ||
        competitionId == null ||
        first.text.trim().isEmpty ||
        last.text.trim().isEmpty ||
        slug.text.trim().isEmpty) {
      return;
    }

    setState(() => saving = true);

    final data = {
      'competition_id': competitionId,
      'first_name': first.text.trim(),
      'last_name': last.text.trim(),
      'nickname': nick.text.trim().isEmpty ? null : nick.text.trim(),
      'slug': slug.text.trim().toLowerCase(),
      'country_code': country.text.trim().isEmpty
          ? null
          : country.text.trim().toUpperCase(),
      'photo_url': photo.text.trim().isEmpty ? null : photo.text.trim(),
      'rights_status': status,
      'rights_holder':
          holder.text.trim().isEmpty ? null : holder.text.trim(),
      'license_reference':
          license.text.trim().isEmpty ? null : license.text.trim(),
      'rights_expires_at': expires?.toIso8601String(),
    };

    try {
      if (widget.fighter == null) {
        await c.from('external_fighters').insert(data);
      } else {
        await c
            .from('external_fighters')
            .update(data)
            .eq('id', widget.fighter!['id']);
      }
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
            Text(
              widget.fighter == null
                  ? 'Nouveau fighter externe'
                  : 'Modifier le fighter externe',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: competitionId,
              decoration: const InputDecoration(labelText: 'Organisation'),
              items: widget.competitions
                  .map(
                    (e) => DropdownMenuItem(
                      value: e['id'].toString(),
                      child: Text((e['short_name'] ?? e['name']).toString()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => competitionId = v),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: first,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: last,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                ),
              ],
            ),
            TextField(
              controller: nick,
              decoration: const InputDecoration(labelText: 'Surnom'),
            ),
            TextField(
              controller: slug,
              decoration: const InputDecoration(labelText: 'Slug'),
            ),
            TextField(
              controller: country,
              decoration: const InputDecoration(labelText: 'Pays (code)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: photo,
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        const InputDecoration(labelText: 'URL photo autorisée'),
                  ),
                ),
                IconButton(
                  onPressed: _pick,
                  icon: const Icon(Icons.photo_library, color: _blue),
                ),
              ],
            ),
            if (photo.text.trim().startsWith('http')) AmlUrlMediaPreview(url: photo.text.trim(), compact: true),
            const SizedBox(height: 6),
            const Text(
              'Droits médias',
              style: TextStyle(color: _blue, fontWeight: FontWeight.w900),
            ),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'Statut des droits'),
              items: const [
                DropdownMenuItem(
                  value: 'pending',
                  child: Text('En attente'),
                ),
                DropdownMenuItem(
                  value: 'authorized',
                  child: Text('Autorisé'),
                ),
                DropdownMenuItem(
                  value: 'expired',
                  child: Text('Expiré'),
                ),
                DropdownMenuItem(
                  value: 'denied',
                  child: Text('Refusé'),
                ),
              ],
              onChanged: (v) => setState(() => status = v),
            ),
            TextField(
              controller: holder,
              decoration:
                  const InputDecoration(labelText: 'Détenteur des droits'),
            ),
            TextField(
              controller: license,
              decoration:
                  const InputDecoration(labelText: 'Référence de licence'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                expires == null
                    ? 'Date d’expiration : non renseignée'
                    : 'Expiration : ${expires!.day.toString().padLeft(2, '0')}/${expires!.month.toString().padLeft(2, '0')}/${expires!.year}',
              ),
              trailing: const Icon(Icons.calendar_month, color: _blue),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: expires ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(
                    const Duration(days: 3650),
                  ),
                  lastDate: DateTime.now().add(
                    const Duration(days: 3650),
                  ),
                );
                if (d != null) setState(() => expires = d);
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(backgroundColor: _blue),
                child: saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'ENREGISTRER',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
