import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const int kMaxPostVideoSeconds = 180; // 3 minutes
const int kMaxPostVideoBytes = 50 * 1024 * 1024; // limite de stockage Supabase par défaut

String formatVideoDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Durée réelle d'un fichier vidéo local (null si illisible).
Future<int?> probeVideoSeconds(String path) async {
  final c = VideoPlayerController.file(File(path));
  try {
    await c.initialize().timeout(const Duration(seconds: 20));
    return c.value.duration.inSeconds;
  } catch (_) {
    return null;
  } finally {
    await c.dispose();
  }
}

/// Vignette d'une vidéo dans le fil : un tap ouvre le lecteur plein écran.
class AmlVideoTile extends StatelessWidget {
  final int? seconds;
  final VoidCallback onTap;
  const AmlVideoTile({super.key, this.seconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B2A3C), Color(0xFF05090C)])),
            ),
            Center(
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.16), border: Border.all(color: Colors.white54, width: 2)),
                child: const Icon(Icons.play_arrow_rounded, size: 42),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.videocam_rounded, size: 14), SizedBox(width: 4), Text('Vidéo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))]),
              ),
            ),
            if (seconds != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                  child: Text(formatVideoDuration(seconds!), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Lecteur plein écran avec lecture/pause et barre de progression.
class AmlVideoPlayerScreen extends StatefulWidget {
  final String url;
  const AmlVideoPlayerScreen({super.key, required this.url});
  @override
  State<AmlVideoPlayerScreen> createState() => _AmlVideoPlayerScreenState();
}

class _AmlVideoPlayerScreenState extends State<AmlVideoPlayerScreen> {
  VideoPlayerController? controller;
  bool failed = false;
  bool showControls = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    controller = c;
    try {
      await c.initialize().timeout(const Duration(seconds: 45));
      c.addListener(_tick);
      await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller?.removeListener(_tick);
    controller?.dispose();
    super.dispose();
  }

  String _time(Duration d) => formatVideoDuration(d.inSeconds);

  Future<void> _toggle() async {
    final c = controller;
    if (c == null) return;
    final finished = c.value.position >= c.value.duration && c.value.duration > Duration.zero;
    if (finished) {
      await c.seekTo(Duration.zero);
      await c.play();
    } else if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: failed
          ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Impossible de lire cette vidéo pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))))
          : !ready
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00AEEF)))
              : GestureDetector(
                  onTap: () => setState(() => showControls = !showControls),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(children: [
                    Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))),
                    if (showControls) ...[
                      Center(
                        child: IconButton(
                          iconSize: 72,
                          onPressed: _toggle,
                          icon: Icon(c.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white.withOpacity(.92)),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 26,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          VideoProgressIndicator(c, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 8), colors: const VideoProgressColors(playedColor: Color(0xFF00AEEF), bufferedColor: Colors.white30, backgroundColor: Colors.white12)),
                          Row(children: [
                            Text(_time(c.value.position), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            const Spacer(),
                            Text(_time(c.value.duration), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          ]),
                        ]),
                      ),
                    ],
                  ]),
                ),
    );
  }
}
