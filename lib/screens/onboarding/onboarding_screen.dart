import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_mark.dart';
import '../splash/splash_screen.dart' show kLaunchGradient;

/// Launch screen: brand mark on the blue gradient, a hero illustration, the
/// headline, and the two entry actions (Get Started / I already have an
/// account). Shown once on first launch; either action marks it as seen.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const Color _ink = Color(0xFF111111);

  Future<void> _go(WidgetRef ref, BuildContext context, String route) async {
    await ref.read(authProvider.notifier).completeOnboarding();
    if (context.mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: kLaunchGradient),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 14),
                const BrandMark(logoHeight: 40, fontSize: 21),
                const Expanded(child: Center(child: _Hero())),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Column(
                    children: [
                      const Text(
                        'Promotion, done for you.\nAnytime, anywhere',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 28,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () => _go(ref, context, '/register'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Get Started'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () => _go(ref, context, '/login'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.neutral100,
                            foregroundColor: AppColors.neutral900,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Text('I already have an account'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'By continuing you agree to our Terms of Service\n'
                        'and Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.neutral500,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero artwork: the full-colour logo shown as-is, with sparkles. Stands in for the reference's 3D object.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The logo exactly as designed, no tile or background behind it.
          Image.asset(
            'assets/images/logo.png',
            width: 225,
            height: 225,
            fit: BoxFit.contain,
          ),
          const Positioned(
            top: 4,
            right: 8,
            child: _Sparkle(size: 46, color: Colors.white),
          ),
          const Positioned(
            top: 70,
            left: 0,
            child: _Sparkle(size: 20, color: AppColors.accentLight),
          ),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size, required this.color});
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
