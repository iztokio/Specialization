import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Key ────────────────────────────────────────────────────────────────────
const _kLocaleKey = 'app_locale';

// ─── Supported languages ─────────────────────────────────────────────────────
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.label,
    required this.nativeLabel,
    required this.flag,
  });

  final String code;
  final String label;
  final String nativeLabel;
  final String flag;
}

const supportedLanguages = [
  AppLanguage(code: 'ru', label: 'Russian',    nativeLabel: 'Русский',    flag: '🇷🇺'),
  AppLanguage(code: 'en', label: 'English',    nativeLabel: 'English',    flag: '🇺🇸'),
  AppLanguage(code: 'es', label: 'Spanish',    nativeLabel: 'Español',    flag: '🇪🇸'),
  AppLanguage(code: 'pt', label: 'Portuguese', nativeLabel: 'Português',  flag: '🇧🇷'),
];

// ─── SharedPreferences singleton ─────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize via ProviderScope override in main()');
});

// ─── Locale Notifier ─────────────────────────────────────────────────────────
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final code = prefs.getString(_kLocaleKey) ?? 'ru'; // Russian as default
    return Locale(code);
  }

  Future<void> setLocale(String languageCode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kLocaleKey, languageCode);
    state = Locale(languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
