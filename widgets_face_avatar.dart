import 'package:flutter/material.dart';

/// Avatar rond qui cadre le HAUT de l'image : les visages ne sont plus coupés
/// (CircleAvatar recadre au centre, ce qui tronque les têtes des portraits).
class AmlFaceAvatar extends StatelessWidget {
  final double radius;
  final Color? backgroundColor;
  final ImageProvider? image;
  final Widget? child;
  const AmlFaceAvatar({super.key, this.radius = 20, this.backgroundColor, this.image, this.child});

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: backgroundColor ?? const Color(0xFF1B1B1B), shape: BoxShape.circle),
      child: image != null
          ? Image(
              image: image!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.75),
              errorBuilder: (_, __, ___) => child ?? const Icon(Icons.person, color: Colors.white38),
            )
          : child,
    );
  }
}
