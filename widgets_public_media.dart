import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

const _publicMediaBlue = Color(0xFF00AEEF);

class AmlPublicMedia extends StatefulWidget {
  final String url;
  final double height;
  final BorderRadius borderRadius;
  final bool autoplay;

  const AmlPublicMedia({
    super.key,
    required this.url,
    this.height = 210,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.autoplay = false,
  });

  @override
  State<AmlPublicMedia> createState() => _AmlPublicMediaState();
}

class _AmlPublicMediaState extends State<AmlPublicMedia> {
  VideoPlayerController? _controller;
  String? _imageUrl;
  String? _externalUrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolve(widget.url);
  }

  @override
  void didUpdateWidget(covariant AmlPublicMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve(widget.url);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool _isImage(String value) => RegExp(
        r'\.(jpg|jpeg|png|gif|webp|avif)(\?.*)?$',
        caseSensitive: false,
      ).hasMatch(value);

  bool _isVideo(String value) => RegExp(
        r'\.(mp4|webm|mov|m4v|m3u8)(\?.*)?$',
        caseSensitive: false,
      ).hasMatch(value);

  String? _youtubeId(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (uri.host.contains('youtube.com')) {
      final id = uri.queryParameters['v'];
      if (id?.isNotEmpty == true) return id;
      final shorts = uri.pathSegments.indexOf('shorts');
      if (shorts >= 0 && shorts + 1 < uri.pathSegments.length) {
        return uri.pathSegments[shorts + 1];
      }
      final embed = uri.pathSegments.indexOf('embed');
      if (embed >= 0 && embed + 1 < uri.pathSegments.length) {
        return uri.pathSegments[embed + 1];
      }
    }
    return null;
  }

  Future<void> _resolve(String raw) async {
    final value = raw.trim();
    await _controller?.dispose();
    _controller = null;
    if (mounted) {
      setState(() {
        _imageUrl = null;
        _externalUrl = null;
        _error = null;
        _loading = true;
      });
    }

    if (value.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() { _loading = false; _error = 'Média indisponible.'; });
      return;
    }

    final youtube = _youtubeId(value);
    if (youtube != null && youtube.isNotEmpty) {
      if (mounted) {
        setState(() {
          _imageUrl = 'https://img.youtube.com/vi/$youtube/hqdefault.jpg';
          _externalUrl = value;
          _loading = false;
        });
      }
      return;
    }

    if (_isImage(value)) {
      if (mounted) setState(() { _imageUrl = value; _loading = false; });
      return;
    }

    if (_isVideo(value)) {
      await _initVideo(value);
      return;
    }

    if (uri.host.contains('dropbox.com')) {
      final params = Map<String, String>.from(uri.queryParameters);
      // Dropbox preview URLs are HTML pages. `raw=1` is more likely to
      // return the file stream; keep `dl=1` as a secondary attempt.
      params.remove('dl');
      params['raw'] = '1';
      final rawUrl = uri.replace(queryParameters: params).toString();
      await _initVideo(rawUrl, fallbackUrl: value);
      return;
    }

    if (mounted) {
      setState(() {
        _externalUrl = value;
        _loading = false;
      });
    }
  }

  Future<void> _initVideo(String url, {String? fallbackUrl}) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      // Les vidéos hébergées à distance peuvent mettre plus de 10 s à
      // répondre, notamment sur mobile. Laisser davantage de temps au
      // lecteur natif avant de proposer l'ouverture externe.
      await controller.initialize().timeout(const Duration(seconds: 45));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
      if (widget.autoplay) await controller.play();
    } catch (_) {
      // Libérer le lecteur natif si l'initialisation échoue ou expire.
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _externalUrl = fallbackUrl ?? url;
          _loading = false;
          _error = fallbackUrl == null
              ? 'Cette vidéo ne peut pas être lue directement dans l’application.'
              : 'Ouvre le lien pour regarder cette vidéo.';
        });
      }
    }
  }

  Future<void> _openExternal() async {
    final value = _externalUrl;
    if (value == null || value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.black,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _publicMediaBlue))
            : controller != null && controller.value.isInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(child: FittedBox(fit: BoxFit.cover, alignment: Alignment.topCenter, child: SizedBox(width: controller.value.size.width, height: controller.value.size.height, child: VideoPlayer(controller)))),
                      DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black.withOpacity(.25), shape: BoxShape.circle),
                        child: IconButton.filled(
                          onPressed: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()),
                          icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                        ),
                      ),
                    ],
                  )
                : _imageUrl != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(_imageUrl!, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                          if (_externalUrl != null)
                            Center(child: IconButton.filled(onPressed: _openExternal, icon: const Icon(Icons.play_arrow, color: Colors.white, size: 30))),
                        ],
                      )
                    : _externalUrl != null
                        ? InkWell(
                            onTap: _openExternal,
                            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.open_in_new_rounded, color: _publicMediaBlue, size: 38),
                              const SizedBox(height: 8),
                              Text(_error ?? 'Ouvrir le média', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
                            ])),
                          )
                        : Center(child: Text(_error ?? 'Média indisponible.', style: const TextStyle(color: Colors.white38))),
      ),
    );
  }
}
