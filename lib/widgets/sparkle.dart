import 'package:flutter/material.dart';

/// A four-point sparkle star, used as a small decorative accent on the
/// launch and auth screens. Hidden from screen readers.
class Sparkle extends StatelessWidget {
  const Sparkle({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _SparklePainter(color),
    ),
  );
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2, d = w * 0.12;
    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx + d, cy - d, w, cy)
      ..quadraticBezierTo(cx + d, cy + d, cx, h)
      ..quadraticBezierTo(cx - d, cy + d, 0, cy)
      ..quadraticBezierTo(cx - d, cy - d, cx, 0)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.25), 4, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}
