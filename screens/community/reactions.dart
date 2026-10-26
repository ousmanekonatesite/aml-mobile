import 'package:flutter/material.dart';

/// Réactions disponibles sur une publication (une réaction par membre, modifiable).
class AmlReaction {
  final String key;
  final String emoji;
  final String label;
  const AmlReaction(this.key, this.emoji, this.label);
}

const List<AmlReaction> kReactions = [
  AmlReaction('love', '❤️', 'J’adore'),
  AmlReaction('like', '👍', 'J’aime'),
  AmlReaction('fire', '🔥', 'Feu'),
  AmlReaction('haha', '😂', 'Haha'),
  AmlReaction('wow', '😮', 'Wow'),
  AmlReaction('sad', '😢', 'Triste'),
  AmlReaction('clap', '👏', 'Bravo'),
  AmlReaction('punch', '🥊', 'KO'),
];

AmlReaction? reactionFor(dynamic key) {
  final k = key?.toString();
  if (k == null) return null;
  for (final r in kReactions) {
    if (r.key == k) return r;
  }
  return null;
}

/// Affiche la barre de réactions au-dessus du bouton (appui long ou bouton « + »).
/// Retourne la clé choisie, ou null si fermée.
Future<String?> showReactionPicker(BuildContext context, Rect anchor, {String? current}) {
  final size = MediaQuery.of(context).size;
  const barWidth = 8 * 40.0 + 20;
  final left = anchor.left.clamp(8.0, (size.width - barWidth - 8).clamp(8.0, size.width));
  final top = (anchor.top - 64).clamp(MediaQuery.of(context).padding.top + 8, size.height);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, _, __) => Stack(children: [
      Positioned(
        left: left,
        top: top,
        child: Material(
          color: const Color(0xFF1B1E21),
          elevation: 10,
          borderRadius: BorderRadius.circular(32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final r in kReactions)
                InkResponse(
                  onTap: () => Navigator.pop(dialogContext, r.key),
                  radius: 24,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: current == r.key ? Colors.white12 : Colors.transparent),
                    child: Text(r.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack), alignment: Alignment.bottomLeft, child: child),
    ),
  );
}

/// Résumé des réactions : jusqu'à 3 emojis les plus utilisés + total.
class AmlReactionSummary extends StatelessWidget {
  final Map<String, dynamic> counts;
  const AmlReactionSummary({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.map((e) => MapEntry(e.key, (e.value as num?)?.toInt() ?? 0)).where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (total == 0) return const Text('0', style: TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w700));
    final top = entries.take(3).toList();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 18.0 + (top.length - 1) * 13,
        height: 20,
        child: Stack(children: [
          for (var i = 0; i < top.length; i++)
            Positioned(left: i * 13.0, child: Text(reactionFor(top[i].key)?.emoji ?? '👍', style: const TextStyle(fontSize: 16))),
        ]),
      ),
      const SizedBox(width: 6),
      Text('$total', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w800)),
    ]);
  }
}
