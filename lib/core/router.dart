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
import '../screens/influencer/create_account_screen.dart';
import '../screens/influencer/channel_detail_screen.dart';
import '../screens/influencer/promotions_screen.dart';
import '../screens/browse/browse_screen.dart';
import '../screens/browse/account_detail_screen.dart';
import '../screens/promotions/create_promotion_screen.dart';
import '../screens/promotions/my_promotions_screen.dart';
import '../screens/shell/home_shell.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/admin_overview_screen.dart';
import '../screens/admin/admin_channels_screen.dart';
import '../screens/admin/admin_promotions_screen.dart';
import '../screens/admin/admin_users_screen.dart';
import '../models/models.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;

      // Until startup state is restored, stay on the splash.
      if (!auth.initialized) {
        return location == '/' ? null : '/';
      }

      // First launch: show the walkthrough once.
      if (!auth.seenOnboarding) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      final loggedIn = auth.isLoggedIn;
      final atAuthScreen = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';
      final atEntry = location == '/' || location == '/onboarding';

      if (!loggedIn) {
        // Logged out: allow auth screens; send everything else to login.
        return atAuthScreen ? null : '/login';
      }

      // Logged in. Admins live in the /admin area; others in the user area.
      final isAdmin = auth.isAdmin;
      final inAdminArea = location.startsWith('/admin');

      if (isAdmin) {
        if (atEntry || atAuthScreen || !inAdminArea) return '/admin';
        return null;
      } else {
        if (inAdminArea) return '/dashboard';
        if (atEntry || atAuthScreen) return '/dashboard';
        return null;
      }
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
                builder: (context, state) {
                  // Role-aware 2nd tab: influencers manage their channels,
                  // business users browse creators.
                  final isInfluencer =
                      ref.read(authProvider).isInfluencer;
                  return isInfluencer
                      ? const InfluencerDashboardScreen()
                      : const BrowseScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-promotions',
                builder: (context, state) {
                  // Influencers see incoming requests to their channels;
                  // business users see the promotions they've sent.
                  final isInfluencer =
                      ref.read(authProvider).isInfluencer;
                  return isInfluencer
                      ? const PromotionsScreen()
                      : const MyPromotionsScreen();
                },
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

      // Admin shell (admins only; the redirect guard enforces this).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/admin',
                builder: (context, state) => const AdminOverviewScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/admin/channels',
                builder: (context, state) => const AdminChannelsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/admin/promotions',
                builder: (context, state) => const AdminPromotionsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/admin/users',
                builder: (context, state) => const AdminUsersScreen()),
          ]),
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
          path: '/influencer/accounts/new',
          builder: (context, state) => const CreateAccountScreen()),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/influencer/accounts/edit',
          builder: (context, state) => CreateAccountScreen(
                editing: state.extra is InfluencerAccount
                    ? state.extra as InfluencerAccount
                    : null,
              )),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: '/channel/:accountId',
          builder: (context, state) => ChannelDetailScreen(
              accountId: state.pathParameters['accountId']!)),
    ],
  );
});

/// Bridges Riverpod auth state changes to go_router's refreshListenable.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}
