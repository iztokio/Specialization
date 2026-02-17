import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_birthdate_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_disclaimer_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_notifications_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_welcome_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscription/presentation/screens/paywall_screen.dart';
import '../../features/today/presentation/screens/today_screen.dart';
import '../providers/core_providers.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

part 'app_router.g.dart';

// ============================================================
// ROUTE NAMES
// ============================================================
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String onboardingBirthdate = '/onboarding/birthdate';
  static const String onboardingDisclaimer = '/onboarding/disclaimer';
  static const String onboardingNotifications = '/onboarding/notifications';

  static const String today = '/home/today';
  static const String tarotDraw = '/home/tarot/draw';
  static const String history = '/home/history';
  static const String settings = '/home/settings';

  static const String paywall = '/paywall';
}

// ============================================================
// ROUTER PROVIDER
// ============================================================
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  // Watch auth + profile so GoRouter rebuilds on change → redirect fires.
  final authAsync = ref.watch(authStateProvider);
  final profileAsync = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      // ── Splash ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const SplashScreen()),
      ),

      // ── Onboarding flow ─────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const OnboardingWelcomeScreen()),
        routes: [
          GoRoute(
            path: 'birthdate',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const OnboardingBirthdateScreen()),
          ),
          GoRoute(
            path: 'disclaimer',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const OnboardingDisclaimerScreen()),
          ),
          GoRoute(
            path: 'notifications',
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const OnboardingNotificationsScreen()),
          ),
        ],
      ),

      // ── Main app shell with bottom navigation ────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.today,
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const TodayScreen()),
          ),
          GoRoute(
            path: AppRoutes.history,
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const HistoryScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                _buildPage(state: state, child: const SettingsScreen()),
          ),
        ],
      ),

      // ── Standalone screens (no shell) ────────────────────────
      GoRoute(
        path: AppRoutes.paywall,
        pageBuilder: (context, state) =>
            _buildModalPage(state: state, child: const PaywallScreen()),
      ),
      GoRoute(
        path: AppRoutes.tarotDraw,
        pageBuilder: (context, state) =>
            _buildPage(state: state, child: const TarotDrawScreen()),
      ),
    ],

    errorPageBuilder: (context, state) =>
        MaterialPage(child: ErrorScreen(error: state.error)),

    // ── Auth-aware redirect logic ────────────────────────────────────────
    //
    // State machine:
    //   loading           → stay on splash (shows spinner)
    //   not onboarded     → /onboarding
    //   onboarded         → redirect splash/onboarding → /home/today
    redirect: (context, state) {
      final loading = authAsync.isLoading || profileAsync.isLoading;
      final loc = state.matchedLocation;

      if (loading) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final onSplash = loc == AppRoutes.splash;
      final onOnboarding = loc.startsWith('/onboarding');
      final isOnboardingDone =
          profileAsync.valueOrNull?.hasCompletedOnboarding ?? false;

      if (!isOnboardingDone) {
        // Splash is a transit state — once loading done, always go to onboarding
        if (!onOnboarding) return AppRoutes.onboarding;
        return null;
      }

      // Onboarding done — bounce away from splash/onboarding
      if (onSplash || onOnboarding) return AppRoutes.today;
      return null;
    },
  );
}

// ============================================================
// PAGE TRANSITION BUILDERS
// ============================================================
CustomTransitionPage<void> _buildPage({
  required GoRouterState state,
  required Widget child,
}) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    );

CustomTransitionPage<void> _buildModalPage({
  required GoRouterState state,
  required Widget child,
}) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );

// ============================================================
// THEME MODE PROVIDER
// ============================================================
@riverpod
ThemeMode themeMode(ThemeModeRef ref) {
  final mode = ref.watch(appThemeModeProvider);
  return switch (mode) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}

// ============================================================
// SPLASH SCREEN — fires anonymous sign-in, then router redirects
// ============================================================
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _signIn();
  }

  Future<void> _signIn() async {
    try {
      await ref.read(authServiceProvider).signInAnonymously();
    } catch (_) {
      // Offline — local_user_fallback used automatically by AuthService
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✦',
                style: TextStyle(fontSize: 80, color: AppTheme.celestialGold)),
            const SizedBox(height: 24),
            Text(
              'ASTRALUME',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(fontSize: 36, letterSpacing: 6),
            ),
            const SizedBox(height: 56),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.celestialGold),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MAIN SHELL — bottom navigation
// ============================================================
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (AppRoutes.today, Icons.auto_awesome_outlined, Icons.auto_awesome, 'Today'),
    (AppRoutes.history, Icons.history_outlined, Icons.history, 'History'),
    (AppRoutes.settings, Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    int idx = 0;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].$1)) {
        idx = i;
        break;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        backgroundColor: AppTheme.cosmicPurple,
        indicatorColor: AppTheme.royalPurple,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.$2, color: AppTheme.textSecondary),
                  selectedIcon: Icon(t.$3, color: AppTheme.celestialGold),
                  label: t.$4,
                ))
            .toList(),
      ),
    );
  }
}

// ============================================================
// PLACEHOLDER SCREENS (elaborated in Stage 4)
// ============================================================
class TarotDrawScreen extends StatelessWidget {
  const TarotDrawScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.midnightBlue,
        appBar: AppBar(
            backgroundColor: Colors.transparent, title: const Text('Tarot')),
        body: const Center(child: Text('Tarot Draw — Stage 4')),
      );
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, this.error});
  final Exception? error;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.midnightBlue,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.error, size: 64),
              const SizedBox(height: 16),
              Text('Something went wrong',
                  style: Theme.of(context).textTheme.titleLarge),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.today),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
}
