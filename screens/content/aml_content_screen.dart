import 'package:flutter/material.dart';
import '../../services/aml_content_repository.dart';
import '../../widgets_public_media.dart';

const Color _blue = Color(0xFF00AEEF);
const Color _black = Color(0xFF050505);
const Color _surface = Color(0xFF111111);

class AmlContentScreen extends StatefulWidget {
  const AmlContentScreen({super.key});

  @override
  State<AmlContentScreen> createState() => _AmlContentScreenState();
}

class _AmlContentScreenState extends State<AmlContentScreen> {
  final repo = AmlContentRepository();
  String filter = 'Tous';
  bool loading = true;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await repo.published();
    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });
  }

  List<Map<String, dynamic>> get filtered => filter == 'Tous'
      ? items
      : items.where((e) => e['content_type'] == filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black,
        title: const Text('AML Infos', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        color: _blue,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF003B55), Color(0xFF001B27)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _blue.withOpacity(.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined, color: _blue, size: 30),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('CONTENU OFFICIEL AML', style: TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.1)),
                    SizedBox(height: 5),
                    Text('Actualités, événements et informations publiées par AML.', style: TextStyle(fontWeight: FontWeight.w700)),
                  ])),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['Tous', 'news', 'event', 'photo', 'video'].map((value) {
                  final selected = filter == value;
                  final label = {'Tous':'Tout','news':'Actualités','event':'Événements','photo':'Photos','video':'Vidéos'}[value]!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => filter = value),
                      selectedColor: _blue,
                      backgroundColor: _surface,
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w800),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _blue)))
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 55, 20, 55),
                child: Column(children: [
                  Icon(Icons.article_outlined, size: 52, color: Colors.white24),
                  SizedBox(height: 14),
                  Text('Aucun contenu publié pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
                ]),
              )
            else
              ...filtered.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'AML';
    final excerpt = item['excerpt']?.toString() ?? '';
    final source = item['source_url']?.toString() ?? '';
    final type = item['content_type']?.toString() ?? 'news';
    final imageUrl = item['image_url']?.toString() ?? '';
    final icon = type == 'video' ? Icons.play_circle_outline : type == 'photo' ? Icons.photo_library_outlined : type == 'event' ? Icons.event_outlined : Icons.article_outlined;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (type == 'video' && source.isNotEmpty)
            AmlPublicMedia(url: source, height: 190, borderRadius: const BorderRadius.vertical(top: Radius.circular(18)))
          else if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Image.network(
                imageUrl,
                height: 165,
                width: double.infinity,
                fit: BoxFit.cover, alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => Container(height: 165, color: _surface, child: const Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 42)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: _blue, size: 20), const SizedBox(width: 8), Text(type.toUpperCase(), style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1))]),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.15)),
          if (excerpt.isNotEmpty) ...[const SizedBox(height: 8), Text(excerpt, style: const TextStyle(color: Colors.white70, height: 1.4))],
          if (source.isNotEmpty) ...[const SizedBox(height: 12), Text(source, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700))],
        ]),
            ),
      ]),
    );
  }
}
