import 'package:flutter/material.dart';

/// Base colours for skeleton placeholders. [kSkeletonBase] is the darker
/// surface, [kSkeletonLight] a lighter block sitting on top of it.
const Color kSkeletonBase = Color(0xFFE8ECF2);
const Color kSkeletonLight = Color(0xFFF2F5F9);

/// Sweeps a soft band of light across its child to signal loading.
///
/// Every [Shimmer] reads the same wall clock, so several of them on one screen
/// stay perfectly in step even when they start at different times. With
/// "reduce motion" on, the placeholder is shown still.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final Duration period;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return widget.child;
    final periodMs = widget.period.inMilliseconds;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Shared clock phase (0..1) keeps all shimmers in sync.
        final t = (DateTime.now().millisecondsSinceEpoch % periodMs) / periodMs;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0x00FFFFFF),
              Color(0xB3FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideTransform(-1 + 2 * t),
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Moves the gradient horizontally by [slide] times the box width.
class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.slide);
  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}

/// A rounded placeholder block. Put it inside a [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.color = kSkeletonLight,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final double radius;
  final Color color;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}
