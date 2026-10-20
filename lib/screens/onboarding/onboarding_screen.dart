import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/hex_pattern.dart';

/// Two-slide walkthrough. Only the hero (top) swipes; the white sheet, dots
/// and Skip / Next are fixed chrome — swiping or Next just changes the hero
/// and the copy inside the sheet.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Brand colours drive everything so onboarding follows the logo/theme.
  static const Color _navy = AppColors.primaryHover; // deep logo blue panel
  static const Color _brand = AppColors.primary; // controls/accents

  final _controller = PageController();
  int _page = 0;

  static const _slides = <_SlideData>[
    _SlideData(
      hero: _Hero.logo,
      title: 'Find the right creators',
      body:
          'Browse real channels with audience size, views and price — all in '
          'one place, before you spend a birr.',
    ),
    _SlideData(
      hero: _Hero.rocket,
      title: 'Request, approve, go live',
      body:
          'Send a promotion in a tap. Once the creator and admin approve, it '
          'runs and gets marked fulfilled.',
    ),
  ];

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _finish() =>
      ref.read(authProvider.notifier).completeOnboarding();

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];

    return Scaffold(
      backgroundColor: _navy,
      body: Column(
        children: [
          // ── Top: ONLY the hero swipes ─────────────────────────────────
          Expanded(
            flex: 55,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: HexPattern(
                      color: Colors.white, opacity: 0.05, radius: 46),
                ),
                PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) =>
                      Center(child: _HeroVisual(hero: _slides[i].hero)),
                ),
              ],
            ),
          ),

          // ── Bottom: FIXED white sheet (only the text changes) ─────────
          Expanded(
            flex: 45,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(34),
                  topRight: Radius.circular(34),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
                  child: Column(
                    children: [
                      // Copy changes with the page — no animation.
                      Column(
                        children: [
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.neutral900,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.neutral500,
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Fixed dots.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 9,
                            width: active ? 26 : 9,
                            decoration: BoxDecoration(
                              color: active ? _brand : AppColors.neutral200,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          );
                        }),
                      ),

                      const Spacer(),

                      // Fixed Skip / Next.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _isLast ? null : _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.neutral500,
                            ),
                            child: Text(_isLast ? '' : 'Skip'),
                          ),
                          TextButton(
                            onPressed: _next,
                            style:
                                TextButton.styleFrom(foregroundColor: _brand),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isLast ? 'Get started' : 'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Hero { logo, rocket }

class _SlideData {
  const _SlideData({
    required this.hero,
    required this.title,
    required this.body,
  });
  final _Hero hero;
  final String title;
  final String body;
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual({required this.hero});
  final _Hero hero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 148,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: hero == _Hero.logo
          ? Image.asset('assets/images/logo.png', height: 92)
          : const Icon(Icons.rocket_launch_rounded,
              color: Colors.white, size: 68),
    );
  }
}
