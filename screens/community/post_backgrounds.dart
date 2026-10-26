import 'package:flutter/material.dart';

/// Fonds colorés disponibles pour les publications sans image.
/// La clé est enregistrée avec la publication ; les couleurs restent côté application.
class AmlPostBackground {
  final String key;
  final String label;
  final List<Color> colors;
  final Color text;
  const AmlPostBackground(this.key, this.label, this.colors, {this.text = Colors.white});
}

const List<AmlPostBackground> kPostBackgrounds = [
  AmlPostBackground('aml_blue', 'AML', [Color(0xFF00AEEF), Color(0xFF004E7A)]),
  AmlPostBackground('sunset', 'Sunset', [Color(0xFFFF512F), Color(0xFFDD2476)]),
  AmlPostBackground('violet', 'Violet', [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
  AmlPostBackground('emerald', 'Émeraude', [Color(0xFF11998E), Color(0xFF38EF7D)]),
  AmlPostBackground('gold', 'Or', [Color(0xFFF7971E), Color(0xFFFFD200)], text: Color(0xFF1B1B1B)),
  AmlPostBackground('rose', 'Rose', [Color(0xFFEC008C), Color(0xFFFC6767)]),
  AmlPostBackground('ocean', 'Océan', [Color(0xFF2193B0), Color(0xFF6DD5ED)]),
  AmlPostBackground('fire', 'Feu', [Color(0xFFED213A), Color(0xFF93291E)]),
  AmlPostBackground('royal', 'Royal', [Color(0xFF141E30), Color(0xFF243B55)]),
  AmlPostBackground('night', 'Nuit', [Color(0xFF232526), Color(0xFF414345)]),
];

AmlPostBackground? postBackgroundFor(dynamic key) {
  final k = key?.toString();
  if (k == null || k.isEmpty) return null;
  for (final b in kPostBackgrounds) {
    if (b.key == k) return b;
  }
  return null;
}

/// Taille de police adaptée à la longueur du texte.
double postBackgroundFontSize(int length) => length <= 60 ? 28 : (length <= 140 ? 22 : 18);

/// Rendu d'un texte sur fond coloré (carte de publication).
class AmlBackgroundPostText extends StatelessWidget {
  final String text;
  final AmlPostBackground background;
  const AmlBackgroundPostText({super.key, required this.text, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: background.colors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: background.text, fontSize: postBackgroundFontSize(text.length), fontWeight: FontWeight.w800, height: 1.28),
      ),
    );
  }
}
