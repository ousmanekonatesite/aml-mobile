import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

const _previewBlue = Color(0xFF00AEEF);

class AmlUrlMediaPreview extends StatefulWidget {
  final String url;
  final double maxHeight;
  final bool compact;
  const AmlUrlMediaPreview({super.key, required this.url, this.maxHeight = 260, this.compact = false});

  @override
  State<AmlUrlMediaPreview> createState() => _AmlUrlMediaPreviewState();
}

class _AmlUrlMediaPreviewState extends State<AmlUrlMediaPreview> {
  String? imageUrl;
  String? videoUrl;
  String? title;
  bool loading = false;
  String? error;
  VideoPlayerController? controller;

  @override
  void initState() {
    super.initState();
    _resolve(widget.url);
  }

  @override
  void didUpdateWidget(covariant AmlUrlMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve(widget.url);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  bool _isImage(String url) => RegExp(r'\.(jpg|jpeg|png|gif|webp|avif)(\?.*)?$', caseSensitive: false).hasMatch(url);
  bool _isVideo(String url) => RegExp(r'\.(mp4|webm|mov|m4v|m3u8)(\?.*)?$', caseSensitive: false).hasMatch(url);

  String? _youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    if (uri.host.contains('youtube.com')) {
      if (uri.queryParameters['v']?.isNotEmpty == true) return uri.queryParameters['v'];
      final i = uri.pathSegments.indexOf('shorts');
      if (i >= 0 && i + 1 < uri.pathSegments.length) return uri.pathSegments[i + 1];
      final e = uri.pathSegments.indexOf('embed');
      if (e >= 0 && e + 1 < uri.pathSegments.length) return uri.pathSegments[e + 1];
    }
    return null;
  }

  Future<void> _resolve(String raw) async {
    final url = raw.trim();
    controller?.dispose();
    controller = null;
    if (mounted) setState(() { imageUrl = null; videoUrl = null; title = null; error = null; loading = false; });
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) return;

    final yt = _youtubeId(url);
    if (yt != null && yt.isNotEmpty) {
      if (mounted) setState(() { imageUrl = 'https://img.youtube.com/vi/$yt/hqdefault.jpg'; title = 'Vidéo YouTube'; });
      return;
    }
    if (_isImage(url)) {
      if (mounted) setState(() => imageUrl = url);
      return;
    }
    if (_isVideo(url)) {
      await _initVideo(url);
      return;
    }
    if (uri.host.contains('dropbox.com')) {
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['dl'] = '1';
      await _initVideo(uri.replace(queryParameters: qp).toString());
      return;
    }

    if (mounted) setState(() => loading = true);
    try {
      final response = await http.get(uri, headers: {'User-Agent': 'AML-Mobile/1.0'}).timeout(const Duration(seconds: 7));
      final html = response.body;
      String? meta(String key) {
        final a = RegExp('<meta[^>]+(?:property|name)=["\\\']$key["\\\'][^>]+content=["\\\']([^"\\\']+)["\\\'][^>]*>', caseSensitive: false).firstMatch(html);
        final b = RegExp('<meta[^>]+content=["\\\']([^"\\\']+)["\\\'][^>]+(?:property|name)=["\\\']$key["\\\'][^>]*>', caseSensitive: false).firstMatch(html);
        return a?.group(1) ?? b?.group(1);
      }
      final rawImage = meta('og:image') ?? meta('twitter:image');
      final rawVideo = meta('og:video:secure_url') ?? meta('og:video') ?? meta('twitter:player:stream');
      final pageTitle = meta('og:title') ?? RegExp('<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html)?.group(1)?.trim();
      String absolutize(String value) {
        final parsed = Uri.tryParse(value);
        if (parsed?.hasScheme == true) return value;
        return uri.resolve(value).toString();
      }
      if (rawVideo != null && rawVideo.isNotEmpty) {
        await _initVideo(absolutize(rawVideo));
      }
      if (mounted) {
        setState(() {
          imageUrl = rawImage == null || rawImage.isEmpty ? null : absolutize(rawImage);
          title = pageTitle;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Aucun aperçu disponible pour ce lien.'; });
    }
  }

  Future<void> _initVideo(String url) async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize().timeout(const Duration(seconds: 10));
      if (!mounted) { await c.dispose(); return; }
      setState(() { controller = c; videoUrl = url; loading = false; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Vidéo détectée, mais sa lecture n’est pas accessible depuis ce lien.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(minHeight: 2, color: _previewBlue));
    final c = controller;
    if (c != null && c.value.isInitialized) {
      return _Frame(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: Stack(alignment: Alignment.center, children: [VideoPlayer(c), IconButton.filled(onPressed: () { setState(() => c.value.isPlaying ? c.pause() : c.play()); }, icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow))])));
    }
    if (imageUrl != null) {
      return _Frame(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(imageUrl!, width: double.infinity, height: widget.compact ? 130 : widget.maxHeight, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, __, ___) => const SizedBox.shrink())));
    }
    if (error != null && !widget.compact) return Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: const TextStyle(color: Colors.white38, fontSize: 11)));
    return const SizedBox.shrink();
  }
}

class _Frame extends StatelessWidget {
  final Widget child;
  const _Frame({required this.child});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 8), clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: child);
}
