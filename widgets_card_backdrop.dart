import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fond léger des cartes de combat : halos bleus, fines diagonales et filigrane octogonal AML.
/// Il remplace l'effet « carte vide » sans gêner la lecture du contenu.
class AmlCardBackdrop extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final bool bordered;

  const AmlCardBackdrop({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color = const Color(0xFF111111),
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: Colors.white.withOpacity(.07)) : null,
      ),
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _AmlBackdropPainter()))),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

class _AmlBackdropPainter extends CustomPainter {
  static const Color _blue = Color(0xFF00AEEF);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Halos de couleur dans deux coins.
    canvas.drawRect(
      rect,
      Paint()..shader = RadialGradient(center: Alignment.topRight, radius: 1.05, colors: [_blue.withOpacity(.11), Colors.transparent]).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()..shader = RadialGradient(center: Alignment.bottomLeft, radius: .95, colors: [const Color(0xFF0A4C6A).withOpacity(.20), Colors.transparent]).createShader(rect),
    );

    // Fines diagonales.
    final line = Paint()
      ..color = Colors.white.withOpacity(.025)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }

    // Filigrane : octogone de l'octogone AML (deux contours).
    final center = Offset(size.width * .5, size.height * .52);
    for (final factor in [.62, .42]) {
      final radius = size.shortestSide * factor;
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final angle = math.pi / 8 + i * math.pi / 4;
        final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _blue.withOpacity(factor > .5 ? .07 : .05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
