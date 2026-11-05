import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../widgets/brand_mark.dart';

/// Shared blue -> white vertical gradient used by the splash and launch
/// screens. Deep brand blue at the top fading to white at the bottom.
const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    AppColors.primaryHover,
    AppColors.primary,
    Color(0xFF6FAEFF),
    Color(0xFFD6E8FF),
    Colors.white,
  ],
  stops: [0.0, 0.28, 0.52, 0.78, 1.0],
);

/// Launch-screen gradient: same colours, but it reaches pure white by ~60% of
/// the height so the headline and buttons sit on a clean white area.
const LinearGradient kLaunchGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    AppColors.primaryHover,
    AppColors.primary,
    Color(0xFF6FAEFF),
    Color(0xFFD6E8FF),
    Colors.white,
  ],
  stops: [0.0, 0.16, 0.32, 0.47, 0.6],
);

/// Purely cosmetic splash. The router's redirect guard decides where to go
/// once auth/onboarding state is restored (AuthState.initialized).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: kBrandGradient),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
              ),
              child: const BrandMark(logoHeight: 64, fontSize: 34),
            ),
          ),
        ),
      ),
    );
  }
}
