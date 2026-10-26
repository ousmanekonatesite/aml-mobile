import 'package:flutter/material.dart';
import '../../services/home_repository.dart';
import '../../widgets_public_media.dart';

class AmlTvScreen extends StatefulWidget {
  const AmlTvScreen({super.key});

  @override
  State<AmlTvScreen> createState() => _AmlTvScreenState();
}

class _AmlTvScreenState extends State<AmlTvScreen> {
  final repo = AmlHomeRepository();
  String selectedCategory = 'Tous';
  bool loading = true;
  List<Map<String, dynamic>> videos = [];

  final List<String> categories = const [
    'Tous', 'En direct', 'Combats', 'Highlights', 'Interviews', 'Coulisses', 'Portraits',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final rows = await repo.publishedVideos();
    if (!mounted) return;
    setState(() { videos = rows; loading = false; });
  }

  List<Map<String, dynamic>> get filteredVideos {
    if (selectedCategory == 'Tous') return videos;
    return videos.where((v) => _category(v) == selectedCategory).toList();
  }

  String _category(Map<String, dynamic> v) {
    final value = v['category_name']?.toString() ?? v['category']?.toString() ?? '';
    return value.isEmpty ? 'AML TV' : value;
  }

  String _mediaUrl(Map<String, dynamic> v) => (v['external_url']?.toString().trim().isNotEmpty == true)
      ? v['external_url'].toString().trim()
      : (v['storage_path']?.toString() ?? '').trim();

  String _duration(dynamic seconds) {
    final value = seconds is num ? seconds.round() : int.tryParse(seconds?.toString() ?? '');
    if (value == null || value <= 0) return '';
    final m = value ~/ 60;
    final s = value % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredVideos;
    final featured = videos.where((v) => v['is_featured'] == true).isNotEmpty ? videos.firstWhere((v) => v['is_featured'] == true) : (videos.isEmpty ? null : videos.first);
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505), elevation: 0,
        title: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF00AEEF), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 25)),
          const SizedBox(width: 10), const Text('AML TV', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF00AEEF), onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          _buildLiveBanner(), const SizedBox(height: 20),
          if (loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Color(0xFF00AEEF))))
          else if (featured != null) _buildFeaturedVideo(featured)
          else _buildEmptyFeatured(),
          const SizedBox(height: 25), _buildCategorySelector(), const SizedBox(height: 20),
          _buildVideoSection(items),
        ]),
      ),
    );
  }

  Widget _buildLiveBanner() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF230000), Color(0xFF001A27)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF00AEEF).withOpacity(.35))),
    child: const Row(children: [
      DecoratedBox(decoration: BoxDecoration(color: Color(0xFF00AEEF), shape: BoxShape.circle), child: SizedBox(width: 12, height: 12)),
      SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('AML TV', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Le meilleur du MMA africain', style: TextStyle(color: Colors.white60, fontSize: 13))])),
      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
    ]),
  );

  Widget _buildFeaturedVideo(Map<String, dynamic> video) {
    final media = _mediaUrl(video);
    final thumb = video['thumbnail_path']?.toString() ?? '';
    return Container(margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (media.isNotEmpty) AmlPublicMedia(url: media, height: 215, borderRadius: const BorderRadius.vertical(top: Radius.circular(22)))
      else if (thumb.isNotEmpty) ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), child: Image.network(thumb, height: 215, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter))
      else const SizedBox(height: 100, child: Center(child: Icon(Icons.video_library_outlined, color: Colors.white24, size: 42))),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_category(video).toUpperCase(), style: const TextStyle(color: Color(0xFF00AEEF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 7), Text(video['title']?.toString() ?? 'Vidéo AML', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        if ((video['description']?.toString() ?? '').trim().isNotEmpty) ...[const SizedBox(height: 7), Text(video['description'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, height: 1.35))],
      ])),
    ]));
  }

  Widget _buildEmptyFeatured() => Container(margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white10)), child: const Column(children: [Icon(Icons.video_library_outlined, color: Colors.white24, size: 42), SizedBox(height: 12), Text('Aucune vidéo AML publiée pour le moment', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w800)), SizedBox(height: 6), Text('Les vidéos officielles apparaîtront ici dès leur publication.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12))]));

  Widget _buildCategorySelector() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final category = categories[index];
          final selected = selectedCategory == category;
          return GestureDetector(
            onTap: () => setState(() => selectedCategory = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF00AEEF) : const Color(0xFF171717),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: selected ? const Color(0xFF00AEEF) : Colors.white10),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoSection(List<Map<String, dynamic>> items) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Text('Dernières vidéos', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))), Text('${items.length} vidéos', style: const TextStyle(color: Colors.white38, fontSize: 12))]),
    const SizedBox(height: 14),
    if (items.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Aucune vidéo dans cette catégorie.', style: TextStyle(color: Colors.white38))))
    else ...items.map(_buildVideoCard),
  ]));

  Widget _buildVideoCard(Map<String, dynamic> video) {
    final thumb = video['thumbnail_path']?.toString() ?? '';
    final duration = _duration(video['duration_seconds']);
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AmlVideoScreen(video: video)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 125,
              height: 85,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: thumb.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(thumb, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF003B55))),
                          const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32)),
                          if (duration.isNotEmpty)
                            Positioned(
                              right: 7,
                              bottom: 7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                color: Colors.black87,
                                child: Text(duration, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        color: const Color(0xFF003B55),
                        child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32)),
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_category(video), style: const TextStyle(color: Color(0xFF00AEEF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(video['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(video['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
          ],
        ),
      ),
    );
  }
}

class AmlVideoScreen extends StatelessWidget {
  final Map<String, dynamic> video;
  const AmlVideoScreen({super.key, required this.video});

  String get media => (video['external_url']?.toString().trim().isNotEmpty == true)
      ? video['external_url'].toString().trim()
      : (video['storage_path']?.toString() ?? '').trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        title: const Text('AML TV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          if (media.isNotEmpty)
            AmlPublicMedia(url: media, height: 230, borderRadius: BorderRadius.zero)
          else
            Container(height: 230, color: const Color(0xFF151515), child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white38, size: 75))),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(video['title']?.toString() ?? 'Vidéo AML', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                if ((video['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(video['description'].toString(), style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.45)),
                ],
                const SizedBox(height: 25),
                const Text('AML TV', style: TextStyle(color: Color(0xFF00AEEF), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 10),
                const Text('Le contenu vidéo officiel de l’African MMA League.', style: TextStyle(color: Colors.white70, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
