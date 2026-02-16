import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================
// DISCLAIMER:
// This app is for ENTERTAINMENT PURPOSES ONLY.
// Horoscopes and Tarot readings do not constitute medical,
// financial, legal, or any other professional advice.
// ============================================================

// NOTE: Firebase init is deferred until `flutterfire configure` is run.
// See docs/stage0/SETUP-GUIDE.md

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      // TODO(stage3): Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
      // TODO(stage3): Crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode)
      runApp(const ProviderScope(child: AstraLumeApp()));
    },
    (error, stack) {
      if (kDebugMode) debugPrint('Uncaught: $error\n$stack');
      // TODO(stage3): FirebaseCrashlytics.instance.recordError(error, stack)
    },
  );
}

class AstraLumeApp extends ConsumerWidget {
  const AstraLumeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO(stage3): Replace with generated GoRouter + Riverpod providers
    return MaterialApp(
      title: 'AstraLume',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4AF37),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0B2A),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0B2A),
      ),
      themeMode: ThemeMode.dark,
      supportedLocales: const [
        Locale('en'), Locale('es'), Locale('pt'), Locale('ru'),
      ],
      home: const _SplashPlaceholder(),
    );
  }
}

class _SplashPlaceholder extends StatelessWidget {
  const _SplashPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0B2A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '✦ ASTRALUME ✦',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 28,
                letterSpacing: 3.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'For entertainment purposes only',
              style: TextStyle(
                color: Color(0x80FFFFFF),
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
