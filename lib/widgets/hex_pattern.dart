import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A sci-fi / HUD-style animated honeycomb overlay for solid-colour surfaces
/// (blue/orange headers, banners).
///
/// A "tech grid" rather than a flat pattern:
///   • a dim base lattice of large hexagons,
///   • a radial energy field that slowly pulses (breathes),
///   • a diagonal scan wave that travels across and lights up cells it passes,
///   • "active" cells with a double ring + glowing vertex nodes,
///   • short connector ticks between neighbours (circuit traces),
///   • a few platform glyphs seated inside bright cells like HUD readouts.
///
/// Layout is deterministic (seeded); only brightness animates, so it stays
/// subtle and cheap. Use [HexBackground] to layer it behind content with
/// matching rounded corners.
class HexPattern extends StatefulWidget {
  const HexPattern({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.11,
    this.radius = 42,
    this.seed = 7,
    this.animate = true,
  });

  final Color color;
  final double opacity;
  final double radius;
  final int seed;
  final bool animate;

  @override
  State<HexPattern> createState() => _HexPatternState();
}

class _HexPatternState extends State<HexPattern>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _HexPainter(
              color: widget.color,
              opacity: widget.opacity,
              radius: widget.radius,
              seed: widget.seed,
              t: _controller.value, // 0..1 loop phase
            ),
          );
        },
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter({
    required this.color,
    required this.opacity,
    required this.radius,
    required this.seed,
    required this.t,
  });

  final Color color;
  final double opacity;
  final double radius;
  final int seed;
  final double t;

  static const _socialIcons = <IconData>[
    Icons.send_rounded, // Telegram
    Icons.play_circle_fill_rounded, // YouTube
    Icons.music_note_rounded, // TikTok
    Icons.facebook_rounded, // Facebook
    Icons.camera_alt_rounded, // Instagram
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = radius * 2;
    final h = math.sqrt(3) * radius;
    final horizStep = radius * 1.5;
    final vertStep = h;

    final rnd = math.Random(seed);

    // Energy origin: top-right. A slow breath modulates overall intensity.
    final origin = Offset(size.width * 0.9, size.height * 0.1);
    final maxDist = size.width * 0.95;
    final breath = 0.80 + 0.20 * math.sin(t * 2 * math.pi);

    // Diagonal scan wave sweeps across the surface, brightening nearby cells.
    // Phase runs top-left -> bottom-right over the loop.
    final scanPos = t; // 0..1
    final diag = size.width + size.height;

    final cells = <_Cell>[];
    int col = 0;
    for (double cx = -w; cx < size.width + w; cx += horizStep) {
      final yOffset = (col.isOdd) ? h / 2 : 0.0;
      for (double cy = -h; cy < size.height + h; cy += vertStep) {
        final center = Offset(cx, cy + yOffset);
        final dist = (center - origin).distance;
        var energy = (1.0 - (dist / maxDist)).clamp(0.0, 1.0) * breath;

        // Scan contribution: how close this cell is to the moving wavefront.
        final cellDiag = (center.dx + center.dy) / diag; // 0..1
        final d = (cellDiag - scanPos).abs();
        final scan = (1.0 - d / 0.12).clamp(0.0, 1.0); // narrow band
        energy = (energy + scan * 0.6).clamp(0.0, 1.0);

        cells.add(_Cell(center, energy, rnd.nextDouble(), col));
      }
      col++;
    }

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    // Pass 1: dim base lattice.
    for (final c in cells) {
      basePaint.color =
          color.withValues(alpha: opacity * (0.22 + 0.5 * c.energy));
      canvas.drawPath(_hexPath(c.center, radius), basePaint);
    }

    // Pass 2: connector traces + start nodes on energised cells.
    final tracePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final c in cells) {
      if (c.energy < 0.25 || c.roll > 0.30) continue;
      tracePaint.color = color.withValues(alpha: opacity * (1.4 * c.energy));
      final dir = Offset(horizStep, (c.col.isEven ? h / 2 : -h / 2));
      final start = c.center + Offset(radius * 0.5, 0);
      final end = c.center + dir * 0.42;
      canvas.drawLine(start, end, tracePaint);
      canvas.drawCircle(
        start,
        1.8,
        Paint()..color = color.withValues(alpha: opacity * 2.0 * c.energy),
      );
    }

    // Pass 3: active cells — double ring + glowing vertex nodes.
    for (final c in cells) {
      final activeChance = 0.10 + 0.45 * c.energy;
      if (c.roll > activeChance) continue;

      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..isAntiAlias = true
        ..color = color.withValues(alpha: opacity * (1.4 + 1.6 * c.energy));
      canvas.drawPath(_hexPath(c.center, radius), ring);

      final inner = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true
        ..color = color.withValues(alpha: opacity * (0.8 + 1.1 * c.energy));
      canvas.drawPath(_hexPath(c.center, radius * 0.62), inner);

      final node = Paint()
        ..isAntiAlias = true
        ..color = color.withValues(alpha: opacity * (2.4 * c.energy + 0.5));
      for (var i = 0; i < 6; i++) {
        final ang = math.pi / 180 * (60 * i);
        final v = Offset(
          c.center.dx + radius * math.cos(ang),
          c.center.dy + radius * math.sin(ang),
        );
        canvas.drawCircle(v, 2.0 + 1.8 * c.energy, node);
      }
    }

    // Pass 4: HUD glyphs in the brightest cells.
    for (final c in cells) {
      if (c.energy < 0.45 || c.roll > 0.14) continue;
      final icon = _socialIcons[(c.roll * 1000).toInt() % _socialIcons.length];
      _drawIcon(
        canvas,
        icon,
        c.center,
        radius * 0.8,
        color.withValues(alpha: opacity * (1.8 + 1.6 * c.energy)),
      );
    }
  }

  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double glyphSize,
    Color glyphColor,
  ) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: glyphSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: glyphColor,
        ),
      ),
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  Path _hexPath(Offset center, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i); // flat-top
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_HexPainter old) =>
      old.t != t ||
      old.color != color ||
      old.opacity != opacity ||
      old.radius != radius ||
      old.seed != seed;
}

class _Cell {
  _Cell(this.center, this.energy, this.roll, this.col);
  final Offset center;
  final double energy;
  final double roll;
  final int col;
}

/// Layers an animated [HexPattern] behind [child], clipped to [borderRadius]
/// so the pattern never spills past the surface's rounded corners.
class HexBackground extends StatelessWidget {
  const HexBackground({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.color = Colors.white,
    this.opacity = 0.11,
    this.radius = 42,
    this.seed = 7,
    this.animate = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color color;
  final double opacity;
  final double radius;
  final int seed;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: HexPattern(
              color: color,
              opacity: opacity,
              radius: radius,
              seed: seed,
              animate: animate,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
