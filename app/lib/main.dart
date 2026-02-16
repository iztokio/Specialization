import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

// ============================================================
// DISCLAIMER:
// This app is for ENTERTAINMENT PURPOSES ONLY.
// Horoscopes and Tarot readings do not constitute medical,
// financial, legal, or any other professional advice.
// ============================================================

/// Top-level FCM background handler (required by firebase_messaging).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background messages handled silently — no UI interaction
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // ─── Firebase initialization ────────────────────────────────
      // Graceful fallback: if firebase_options.dart is placeholder,
      // the app runs in offline mode (local Drift DB only).
      bool firebaseReady = false;
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseReady = true;

        // Crashlytics: only in release mode
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(!kDebugMode);

        // FCM background handler
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      } catch (e) {
        // Firebase not configured yet — run in offline mode
        if (kDebugMode) {
          debugPrint(
            '[AstraLume] Firebase not configured — offline mode active.\n'
            'Run: flutterfire configure --project=YOUR_PROJECT_ID',
          );
        }
      }

      runApp(
        ProviderScope(
          child: AstraLumeApp(firebaseReady: firebaseReady),
        ),
      );
    },
    (error, stack) {
      if (kDebugMode) debugPrint('[AstraLume] Uncaught: $error\n$stack');
      // Crashlytics only records if Firebase was initialized
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class AstraLumeApp extends ConsumerWidget {
  const AstraLumeApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AstraLume',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      supportedLocales: const [
        Locale('en'), Locale('es'), Locale('pt'), Locale('ru'),
      ],
      routerConfig: router,
    );
  }
}
