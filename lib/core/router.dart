import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/profile_screen.dart';
import '../screens/influencer/influencer_dashboard_screen.dart';
import '../screens/influencer/accounts_screen.dart';
import '../screens/influencer/create_account_screen.dart';
import '../screens/influencer/promotions_screen.dart';
import '../screens/browse/browse_screen.dart';
import '../screens/browse/account_detail_screen.dart';
import '../screens/promotions/create_promotion_screen.dart';
import '../screens/promotions/my_promotions_screen.dart';
import '../screens/shell/home_shell.dart';
import '../models/models.dart';

/// Public routes that never require authentication.
const _publicRoutes = <String>{
  '/',
  '/onboarding',
  '/login',
  '/register',
  '/forgot-password',
};

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider).isLoggedIn;
      final location = state.matchedLocation;
      final isPublic = _publicRoutes.contains(location);

      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn &&
          (location == '/login' ||
              location == '/register' ||
              location == '/onboarding')) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen()),
      GoRoute(
          path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen()),

      // Main app shell with persistent bottom navigation.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browse',
                builder: (context, state) => const BrowseScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-promotions',
                builder: (context, state) => const MyPromotionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Detail / flow routes pushed on top of the shell (full screen).
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/browse-detail/:accountId',
          builder: (context, state) => AccountDetailScreen(
              accountId: state.pathParameters['accountId']!)),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/browse-detail/:accountId/promote',
          builder: (context, state) => CreatePromotionScreen(
                accountPublicId: state.pathParameters['accountId']!,
                account: state.extra is InfluencerAccount
                    ? state.extra as InfluencerAccount
                    : null,
              )),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/influencer',
          builder: (context, state) => const InfluencerDashboardScreen()),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/influencer/accounts',
          builder: (context, state) => const AccountsScreen()),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/influencer/accounts/new',
          builder: (context, state) => const CreateAccountScreen()),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/influencer/promotions',
          builder: (context, state) => const PromotionsScreen()),
    ],
  );
});

/// Bridges Riverpod auth state changes to go_router's refreshListenable.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}
