import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Drapeau d'un pays à partir de son code ISO (CI, SN, FR…).
/// Image de drapeau en priorité, emoji calculé en secours (jamais de globe générique).
class AmlFlag extends StatelessWidget {
  final String? code;
  final double height;
  const AmlFlag({super.key, this.code, this.height = 14});

  static String emoji(String? code) {
    final cc = (code ?? '').trim().toUpperCase();
    if (cc.length != 2) return '';
    return String.fromCharCodes(cc.codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
  }

  @override
  Widget build(BuildContext context) {
    final cc = (code ?? '').trim().toUpperCase();
    if (cc.length != 2) return const SizedBox.shrink();
    final width = height * 4 / 3;
    final fallback = Text(emoji(cc), style: TextStyle(fontSize: height));
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: CachedNetworkImage(
        imageUrl: 'https://flagcdn.com/w80/${cc.toLowerCase()}.png',
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => SizedBox(width: width, height: height),
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
