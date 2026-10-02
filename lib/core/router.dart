import 'package:go_router/go_router.dart';
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
import '../screens/promotions/my_promotions_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen()),
    GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen()),
    GoRoute(
        path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(
        path: '/influencer',
        builder: (context, state) => const InfluencerDashboardScreen()),
    GoRoute(
        path: '/influencer/accounts',
        builder: (context, state) => const AccountsScreen()),
    GoRoute(
        path: '/influencer/accounts/new',
        builder: (context, state) => const CreateAccountScreen()),
    GoRoute(
        path: '/influencer/promotions',
        builder: (context, state) => const PromotionsScreen()),
    GoRoute(
        path: '/browse', builder: (context, state) => const BrowseScreen()),
    GoRoute(
        path: '/browse/:accountId',
        builder: (context, state) => AccountDetailScreen(
            accountId: state.pathParameters['accountId']!)),
    GoRoute(
        path: '/my-promotions',
        builder: (context, state) => const MyPromotionsScreen()),
  ],
);
