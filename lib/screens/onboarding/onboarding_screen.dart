import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// First-launch walkthrough. Clean, static slides — no animation. Copy is
/// written around what the app actually does.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = <_SlideData>[
    _SlideData(
      icon: Icons.travel_explore_rounded,
      badge: Icons.insights_rounded,
      color: AppColors.primary,
      title: 'Find the right channel',
      body:
          'Browse creators on Telegram, YouTube, TikTok, Facebook and '
          'Instagram. See audience size, views per post and their price.',
    ),
    _SlideData(
      icon: Icons.campaign_rounded,
      badge: Icons.send_rounded,
      color: AppColors.primaryLight,
      title: 'Send a promotion request',
      body:
          'Pick the dates, add your text and image, and send it straight to '
          "the creator's account.",
    ),
    _SlideData(
      icon: Icons.storefront_rounded,
      badge: Icons.sell_rounded,
      color: AppColors.accent,
      title: 'List your account, set your price',
      body:
          'Add each channel you run, show your real view counts, and name a '
          'price for every slot.',
    ),
    _SlideData(
      icon: Icons.workspace_premium_rounded,
      badge: Icons.check_rounded,
      color: AppColors.accentHover,
      title: 'Approved, then it runs',
      body:
          'Every request is checked by an admin, then by the account owner. '
          'Once both say yes, it goes live and gets marked fulfilled.',
    ),
  ];

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _finish() async {
    // Persist the flag; the router's redirect guard will move us off
    // onboarding automatically once state updates.
    await ref.read(authProvider.notifier).completeOnboarding();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: _isLast ? null : _finish,
                  child: Text(
                    _isLast ? '' : 'Skip',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _Slide(data: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 24 : 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.neutral200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Create account' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.data});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SlideIcon(icon: data.icon, badge: data.badge, color: data.color),
          const SizedBox(height: 36),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.neutral500,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Layered icon "scene": a soft circular wash, a tinted rounded tile with the
/// main glyph, and a small accent badge overlapping the corner. Gives each
/// slide depth and a distinct silhouette instead of a flat single glyph.
class _SlideIcon extends StatelessWidget {
  const _SlideIcon({
    required this.icon,
    required this.badge,
    required this.color,
  });

  final IconData icon;
  final IconData badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft circular backdrop.
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
          // Main tile.
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, size: 52, color: color),
          ),
          // Accent badge, overlapping the top-right corner.
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(badge, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.icon,
    required this.badge,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final IconData badge;
  final Color color;
  final String title;
  final String body;
}
