import 'package:flutter/material.dart';

/// MysticTarot Design System
///
/// Visual direction: Dark cosmic mysticism with gold accents
/// Primary palette: Deep midnight blue + celestial gold + cosmic purple
///
/// DISCLAIMER: Entertainment app — no medical/financial advice implied by design.

class AppTheme {
  AppTheme._();

  // ============================================================
  // COLOR PALETTE
  // ============================================================

  /// Primary brand colors
  static const Color midnightBlue = Color(0xFF0D0B2A);    // Background deep
  static const Color cosmicPurple = Color(0xFF1A1040);    // Background card
  static const Color deepIndigo = Color(0xFF1E1B4B);      // Surface
  static const Color royalPurple = Color(0xFF4C1D95);     // Primary action

  /// Accent - Celestial Gold
  static const Color celestialGold = Color(0xFFD4AF37);   // Primary accent
  static const Color lightGold = Color(0xFFF5E27A);       // Gold light
  static const Color warmGold = Color(0xFFB8860B);        // Gold dark

  /// Secondary - Mystic Teal
  static const Color mysticTeal = Color(0xFF0F766E);      // Secondary
  static const Color lightTeal = Color(0xFF14B8A6);       // Teal light

  /// Semantic colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  /// Text colors (dark theme)
  static const Color textPrimary = Color(0xFFF8F4FF);     // Almost white
  static const Color textSecondary = Color(0xFFB8B0D4);   // Muted purple-white
  static const Color textDisabled = Color(0xFF6B6490);    // Disabled
  static const Color textGold = Color(0xFFD4AF37);        // Gold text

  /// Light theme text
  static const Color textPrimaryLight = Color(0xFF1A1040);
  static const Color textSecondaryLight = Color(0xFF4C4470);

  // ============================================================
  // TYPOGRAPHY
  // ============================================================
  // Cinzel        — headings, titles (elegant serif, mystical)
  // Raleway       — body text, UI (clean sans-serif)
  // CinzelDecorative — display/hero only

  static const TextTheme _darkTextTheme = TextTheme(
    // Display — large hero text
    displayLarge: TextStyle(
      fontFamily: 'CinzelDecorative',
      fontSize: 36,
      fontWeight: FontWeight.w700,
      color: celestialGold,
      letterSpacing: 2.0,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: 1.5,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: 1.0,
    ),

    // Headlines
    headlineLarge: TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: celestialGold,
      letterSpacing: 0.5,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Cinzel',
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),

    // Title
    titleLarge: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textSecondary,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textSecondary,
      letterSpacing: 0.5,
    ),

    // Body
    bodyLarge: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textPrimary,
      height: 1.6,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textSecondary,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 12,
      fontWeight: FontWeight.w300,
      color: textDisabled,
      height: 1.4,
    ),

    // Label
    labelLarge: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: 1.2,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textSecondary,
      letterSpacing: 0.8,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Raleway',
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: textDisabled,
      letterSpacing: 0.5,
    ),
  );

  // ============================================================
  // DARK THEME (Primary — mystical night sky)
  // ============================================================
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: celestialGold,
      onPrimary: midnightBlue,
      primaryContainer: Color(0xFF2D2060),
      onPrimaryContainer: lightGold,
      secondary: mysticTeal,
      onSecondary: textPrimary,
      secondaryContainer: Color(0xFF0F4040),
      onSecondaryContainer: lightTeal,
      tertiary: Color(0xFF7C3AED),
      onTertiary: textPrimary,
      error: error,
      onError: textPrimary,
      surface: deepIndigo,
      onSurface: textPrimary,
      surfaceContainerHighest: cosmicPurple,
      outline: Color(0xFF3D3570),
      outlineVariant: Color(0xFF2A2550),
      shadow: Color(0xFF000000),
      scrim: Color(0x80000000),
      inverseSurface: textPrimary,
      onInverseSurface: midnightBlue,
      inversePrimary: royalPurple,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: midnightBlue,
      textTheme: _darkTextTheme,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Cinzel',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: celestialGold,
          letterSpacing: 1.0,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),

      // Card
      cardTheme: CardTheme(
        color: cosmicPurple,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: celestialGold.withAlpha(50),
            width: 1,
          ),
        ),
      ),

      // Elevated Button (primary CTA)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: celestialGold,
          foregroundColor: midnightBlue,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
          elevation: 4,
          shadowColor: celestialGold.withAlpha(80),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: celestialGold,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: celestialGold, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightGold,
          textStyle: const TextStyle(
            fontFamily: 'Raleway',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: deepIndigo,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: celestialGold.withAlpha(60),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: celestialGold,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontFamily: 'Raleway',
        ),
        hintStyle: const TextStyle(
          color: textDisabled,
          fontFamily: 'Raleway',
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cosmicPurple,
        selectedItemColor: celestialGold,
        unselectedItemColor: textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'Raleway',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Raleway',
          fontSize: 10,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: celestialGold.withAlpha(40),
        thickness: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: deepIndigo,
        selectedColor: celestialGold.withAlpha(40),
        labelStyle: const TextStyle(
          color: textPrimary,
          fontFamily: 'Raleway',
          fontSize: 12,
        ),
        side: BorderSide(
          color: celestialGold.withAlpha(80),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return celestialGold;
          return textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return celestialGold.withAlpha(80);
          }
          return deepIndigo;
        }),
      ),

      // Page transitions
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ============================================================
  // LIGHT THEME (secondary — soft dawn)
  // ============================================================
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: royalPurple,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDE9FE),
      onPrimaryContainer: royalPurple,
      secondary: mysticTeal,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFCCFBF1),
      onSecondaryContainer: Color(0xFF115E59),
      tertiary: Color(0xFFB45309),
      onTertiary: Colors.white,
      error: error,
      onError: Colors.white,
      surface: Color(0xFFFAF8FF),
      onSurface: textPrimaryLight,
      surfaceContainerHighest: Color(0xFFEDE9FE),
      outline: Color(0xFFCBC4E0),
      outlineVariant: Color(0xFFE5E1F0),
      shadow: Color(0xFF000000),
      scrim: Color(0x80000000),
      inverseSurface: deepIndigo,
      onInverseSurface: textPrimary,
      inversePrimary: lightGold,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF5F3FF),
    );
  }
}

// ============================================================
// SPACING & DIMENSIONS
// ============================================================
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

// ============================================================
// BORDER RADII
// ============================================================
class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 100.0;
}

// ============================================================
// GRADIENTS
// ============================================================
class AppGradients {
  AppGradients._();

  static const LinearGradient cosmicBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D0B2A),
      Color(0xFF1A0E3D),
      Color(0xFF0D1B4A),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient goldShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFB8860B),
      Color(0xFFD4AF37),
      Color(0xFFF5E27A),
      Color(0xFFD4AF37),
      Color(0xFFB8860B),
    ],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
  );

  static const LinearGradient cardOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xCC0D0B2A),
    ],
  );

  static const RadialGradient glowEffect = RadialGradient(
    colors: [
      Color(0x40D4AF37),
      Colors.transparent,
    ],
    radius: 0.8,
  );
}
