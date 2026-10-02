import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Clean, static splash: a centered "EthioPromo" wordmark, like most
/// professional apps. Resolves auth + onboarding state, then routes.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait<Object?>([
      SharedPreferences.getInstance(),
      Future<void>.delayed(const Duration(milliseconds: 1600)),
    ]);
    if (!mounted) return;

    final prefs = results[0] as SharedPreferences;
    final seenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    final isLoggedIn = ref.read(authProvider).isLoggedIn;

    if (!seenOnboarding) {
      context.go('/onboarding');
    } else if (isLoggedIn) {
      context.go('/dashboard');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 220,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
