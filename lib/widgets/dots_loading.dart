import 'package:flutter/material.dart';

/// A compact three-dot "typing" style loading indicator.
///
/// Used in place of [CircularProgressIndicator] inside buttons so a loading
/// action reads as three pulsing dots. Defaults to white to sit on filled
/// (primary) buttons; pass [color] for outlined/secondary buttons.
class DotsLoading extends StatefulWidget {
  const DotsLoading({
    super.key,
    this.color = Colors.white,
    this.dotSize = 7,
    this.spacing = 5,
  });

  final Color color;
  final double dotSize;
  final double spacing;

  @override
  State<DotsLoading> createState() => _DotsLoadingState();
}

class _DotsLoadingState extends State<DotsLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the footprint close to the old 22px spinner so button height
    // doesn't jump when toggling the loading state.
    return SizedBox(
      height: widget.dotSize * 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Stagger each dot's phase across the cycle.
              final t = (_controller.value - i * 0.18) % 1.0;
              // Ease the opacity up then back down.
              final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
              final opacity = 0.3 + 0.7 * wave.clamp(0.0, 1.0);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
