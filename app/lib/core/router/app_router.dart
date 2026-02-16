import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

// ============================================================
// ROUTE NAMES
// ============================================================
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String onboardingBirthdate = '/onboarding/birthdate';
  static const String onboardingPersonalization = '/onboarding/personalization';
  static const String onboardingDisclaimer = '/onboarding/disclaimer';
  static const String onboardingNotifications = '/onboarding/notifications';

  static const String home = '/home';
  static const String today = '/home/today';
  static const String tarotDraw = '/home/tarot/draw';
  static const String tarotCard = '/home/tarot/card/:cardId';
  static const String history = '/home/history';
  static const String historyDetail = '/home/history/:date';
  static const String settings = '/home/settings';
  static const String profile = '/home/settings/profile';
  static const String notifications = '/home/settings/notifications';
  static const String language = '/home/settings/language';
  static const String theme = '/home/settings/theme';

  static const String subscription = '/subscription';
  static const String paywall = '/paywall';

  static const String tarotLibrary = '/tarot/library';
  static const String zodiacInfo = '/zodiac/:sign';
}

// ============================================================
// ROUTER PROVIDER
// ============================================================
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  // TODO: Watch auth state to redirect
  // final authState = ref.watch(authStateProvider);
  // final onboardingComplete = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    routes: [
      // Splash
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const SplashScreen(),
        ),
      ),

      // Onboarding flow
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const OnboardingWelcomeScreen(),
        ),
        routes: [
          GoRoute(
            path: 'birthdate',
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const OnboardingBirthdateScreen(),
            ),
          ),
          GoRoute(
            path: 'personalization',
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const OnboardingPersonalizationScreen(),
            ),
          ),
          GoRoute(
            path: 'disclaimer',
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const OnboardingDisclaimerScreen(),
            ),
          ),
          GoRoute(
            path: 'notifications',
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const OnboardingNotificationsScreen(),
            ),
          ),
        ],
      ),

      // Main app shell
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.today,
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const TodayScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.history,
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const HistoryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => _buildPage(
              state: state,
              child: const SettingsScreen(),
            ),
          ),
        ],
      ),

      // Standalone screens (no shell)
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) => _buildModalPage(
          state: state,
          child: const PaywallScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.tarotDraw,
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const TarotDrawScreen(),
        ),
      ),
    ],

    // Global error handler
    errorPageBuilder: (context, state) => MaterialPage(
      child: ErrorScreen(error: state.error),
    ),

    // Redirect logic
    redirect: (context, state) {
      // TODO: Implement auth + onboarding redirect logic
      // if (!authState.isLoggedIn) return AppRoutes.onboarding;
      // if (!onboardingComplete) return AppRoutes.onboarding;
      return null;
    },
  );
}

// ============================================================
// PAGE BUILDERS
// ============================================================
CustomTransitionPage<void> _buildPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

CustomTransitionPage<void> _buildModalPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      final tween = Tween(begin: begin, end: end)
          .chain(CurveTween(curve: curve));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

// ============================================================
// THEME MODE PROVIDER (used by main.dart)
// ============================================================
@riverpod
ThemeMode themeMode(ThemeModeRef ref) {
  // TODO: Load from user settings
  return ThemeMode.dark; // Default: dark cosmic theme
}

// ============================================================
// PLACEHOLDER SCREENS (will be replaced in Stage 3)
// ============================================================
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Mystic Tarot', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Onboarding — Welcome')),
      );
}

class OnboardingBirthdateScreen extends StatelessWidget {
  const OnboardingBirthdateScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Onboarding — Birth Date')),
      );
}

class OnboardingPersonalizationScreen extends StatelessWidget {
  const OnboardingPersonalizationScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Onboarding — Personalization')),
      );
}

class OnboardingDisclaimerScreen extends StatelessWidget {
  const OnboardingDisclaimerScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Onboarding — Disclaimer ⚠️')),
      );
}

class OnboardingNotificationsScreen extends StatelessWidget {
  const OnboardingNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Onboarding — Notifications')),
      );
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Today — Horoscope & Tarot')),
      );
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('History')));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Settings')));
}

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Paywall — Premium')));
}

class TarotDrawScreen extends StatelessWidget {
  const TarotDrawScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Tarot Draw')));
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, this.error});
  final Exception? error;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('Error: $error')),
      );
}
