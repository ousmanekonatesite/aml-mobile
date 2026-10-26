import 'package:flutter/material.dart';
import '../../services/admin_repository.dart';
import '../../widgets_url_media_preview.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);

class AmlTvAdminScreen extends StatefulWidget {
  const AmlTvAdminScreen({super.key});

  @override
  State<AmlTvAdminScreen> createState() => _AmlTvAdminScreenState();
}

class _AmlTvAdminScreenState extends State<AmlTvAdminScreen> {
  final AdminRepository repo = AdminRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.adminVideos();
  }

  void reload() => setState(() => future = repo.adminVideos());

  Future<void> _edit([Map<String, dynamic>? video]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      builder: (_) => _VideoForm(repo: repo, video: video),
    );
    if (changed == true) reload();
  }

  String _slug(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _blue));
        }
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString(), onRetry: reload);
        }
        final videos = snapshot.data ?? [];
        return Scaffold(
          backgroundColor: _black,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une vidéo'),
          ),
          body: RefreshIndicator(
            color: _blue,
            onRefresh: () async => reload(),
            child: videos.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 70),
                      Icon(Icons.video_library_outlined, size: 64, color: _blue),
                      SizedBox(height: 18),
                      Text('Aucune vidéo', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      SizedBox(height: 8),
                      Text('Ajoute les métadonnées de tes vidéos AML. Les fichiers peuvent rester sur Dropbox.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: videos.length,
                    itemBuilder: (_, index) {
                      final v = videos[index];
                      final published = v['status']?.toString() == 'published';
                      final featured = v['is_featured'] == true;
                      return Card(
                        color: _surface,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: _Thumbnail(url: v['thumbnail_path']?.toString()),
                          title: Text(v['title']?.toString() ?? 'Sans titre', style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _Chip(text: published ? 'PUBLIÉE' : 'BROUILLON', active: published),
                                if (featured) const _Chip(text: 'VEDETTE', active: true),
                                if ((v['external_url']?.toString() ?? '').isNotEmpty) const _Chip(text: 'LIEN EXTERNE', active: false),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _edit(v);
                              } else if (value == 'toggle') {
                                await repo.toggleVideoPublished(v['id'].toString(), !published);
                                reload();
                              } else if (value == 'delete') {
                                final ok = await _confirmDelete(v['title']?.toString() ?? 'cette vidéo');
                                if (ok == true) {
                                  await repo.deleteVideo(v['id'].toString());
                                  reload();
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                              PopupMenuItem(value: 'toggle', child: Text(published ? 'Mettre en brouillon' : 'Publier')),
                              const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete(String title) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la vidéo ?'),
        content: Text('« $title » sera supprimée du catalogue AML TV. Le fichier Dropbox ne sera pas supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
  }
}

class _VideoForm extends StatefulWidget {
  final AdminRepository repo;
  final Map<String, dynamic>? video;
  const _VideoForm({required this.repo, this.video});

  @override
  State<_VideoForm> createState() => _VideoFormState();
}

class _VideoFormState extends State<_VideoForm> {
  final title = TextEditingController();
  final description = TextEditingController();
  final videoUrl = TextEditingController();
  final thumbnailUrl = TextEditingController();
  final duration = TextEditingController();
  String? categoryId;
  List<Map<String, dynamic>> categories = [];
  bool published = false;
  bool featured = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final v = widget.video;
    title.text = v?['title']?.toString() ?? '';
    description.text = v?['description']?.toString() ?? '';
    videoUrl.text = v?['external_url']?.toString() ?? '';
    thumbnailUrl.text = v?['thumbnail_path']?.toString() ?? '';
    duration.text = v?['duration_seconds']?.toString() ?? '';
    published = v?['status']?.toString() == 'published';
    categoryId = v?['category_id']?.toString();
    _loadCategories();
    featured = v?['is_featured'] == true;
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await widget.repo.adminVideoCategories();
      if (mounted) setState(() => categories = rows);
    } catch (_) {}
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    videoUrl.dispose();
    thumbnailUrl.dispose();
    duration.dispose();
    super.dispose();
  }

  String _slug(String value) {
    final normalized = value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final id = widget.video?['id']?.toString();
    final suffix = id != null && id.length >= 6 ? id.substring(0, 6) : null;
    return suffix == null || normalized.isEmpty ? normalized : '$normalized-$suffix';
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || videoUrl.text.trim().isEmpty) {
      setState(() => error = 'Le titre et le lien vidéo sont obligatoires.');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      await widget.repo.saveVideo({
        'title': title.text.trim(),
        'description': description.text.trim().isEmpty ? null : description.text.trim(),
        'external_url': videoUrl.text.trim(),
        'thumbnail_path': thumbnailUrl.text.trim().isEmpty ? null : thumbnailUrl.text.trim(),
        'duration_seconds': int.tryParse(duration.text.trim()),
        'slug': _slug(title.text.trim()),
        'category_id': categoryId,
        'status': published ? 'published' : 'draft',
        'published_at': published ? DateTime.now().toIso8601String() : null,
        'is_featured': featured,
      }, widget.video?['id']?.toString());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { saving = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.video == null ? 'Nouvelle vidéo AML TV' : 'Modifier la vidéo', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _field(title, 'Titre *', Icons.title),
          DropdownButtonFormField<String>(
            value: categories.any((c) => c['id']?.toString() == categoryId) ? categoryId : null,
            decoration: InputDecoration(labelText: 'Catégorie', prefixIcon: const Icon(Icons.category_outlined), filled: true, fillColor: _black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
            items: categories.map((c) => DropdownMenuItem<String>(value: c['id']?.toString(), child: Text(c['name']?.toString() ?? 'Catégorie'))).toList(),
            onChanged: (value) => setState(() => categoryId = value),
          ),
          const SizedBox(height: 12),
          _field(description, 'Description', Icons.notes_outlined, maxLines: 3),
          _field(videoUrl, 'Lien vidéo / Dropbox *', Icons.link, keyboard: TextInputType.url),
          if (videoUrl.text.trim().isNotEmpty) AmlUrlMediaPreview(url: videoUrl.text.trim()),
          _field(thumbnailUrl, 'Lien miniature', Icons.image_outlined, keyboard: TextInputType.url),
          if (thumbnailUrl.text.trim().isNotEmpty) AmlUrlMediaPreview(url: thumbnailUrl.text.trim(), compact: true),
          _field(duration, 'Durée en secondes', Icons.timer_outlined, keyboard: TextInputType.number),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: published, onChanged: (v) => setState(() => published = v), activeColor: _blue, title: const Text('Publier sur AML TV'), subtitle: const Text('La vidéo sera visible par les fans.', style: TextStyle(color: Colors.white54))),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: featured, onChanged: (v) => setState(() => featured = v), activeColor: _blue, title: const Text('Vidéo vedette'), subtitle: const Text('Afficher comme contenu principal.', style: TextStyle(color: Colors.white54))),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(saving ? 'Enregistrement...' : 'Enregistrer'))),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {int maxLines = 1, TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, maxLines: maxLines, keyboardType: keyboard, onChanged: (_) { if (keyboard == TextInputType.url) setState(() {}); }, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), filled: true, fillColor: _black, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
  );
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  const _Thumbnail({this.url});
  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return Container(width: 58, height: 58, decoration: BoxDecoration(color: _black, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.play_circle_outline, color: _blue));
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url!, width: 58, height: 58, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, __, ___) => Container(width: 58, height: 58, color: _black, child: const Icon(Icons.broken_image_outlined, color: Colors.white38))));
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool active;
  const _Chip({required this.text, required this.active});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: active ? _blue.withOpacity(.16) : Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: active ? _blue : Colors.white54)));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 48), const SizedBox(height: 12), const Text('Impossible de charger AML TV', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)), const SizedBox(height: 16), FilledButton(onPressed: onRetry, child: const Text('Réessayer'))])));
}
