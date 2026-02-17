import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../../features/onboarding/data/repositories/user_profile_repository_impl.dart';
import '../../features/onboarding/domain/entities/user_profile.dart';
import '../../features/onboarding/domain/repositories/user_profile_repository.dart';
import '../../features/subscription/data/datasources/subscription_remote_datasource.dart';
import '../../features/subscription/data/repositories/subscription_repository_impl.dart';
import '../../features/subscription/domain/entities/subscription_status.dart';
import '../../features/subscription/domain/repositories/subscription_repository.dart';
import '../../features/tarot/data/datasources/tarot_remote_datasource.dart';
import '../../features/tarot/data/repositories/tarot_repository_impl.dart';
import '../../features/tarot/domain/entities/tarot_card.dart';
import '../../features/tarot/domain/repositories/tarot_repository.dart';
import '../../features/today/data/datasources/horoscope_remote_datasource.dart';
import '../../features/today/data/repositories/horoscope_repository_impl.dart';
import '../../features/today/domain/entities/daily_reading.dart';
import '../../features/today/domain/repositories/horoscope_repository.dart';

// ═══════════════════════════════════════════════════════════════════════
// DATABASE
// ═══════════════════════════════════════════════════════════════════════

/// Singleton AppDatabase provider.
/// Lifecycle: lives for the entire app lifetime (never disposed).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ═══════════════════════════════════════════════════════════════════════
// REPOSITORIES
// ═══════════════════════════════════════════════════════════════════════

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl(ref.watch(appDatabaseProvider));
});

final horoscopeRepositoryProvider = Provider<HoroscopeRepository>((ref) {
  return HoroscopeRepositoryImpl(
    ref.watch(appDatabaseProvider),
    remote: ref.watch(horoscopeRemoteDatasourceProvider),
  );
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepositoryImpl(
    ref.watch(appDatabaseProvider),
    remote: ref.watch(subscriptionRemoteDatasourceProvider),
  );
});

final tarotRepositoryProvider = Provider<TarotRepository>((ref) {
  return TarotRepositoryImpl(
    ref.watch(appDatabaseProvider),
    remote: ref.watch(tarotRemoteDatasourceProvider),
  );
});

// ═══════════════════════════════════════════════════════════════════════
// STATE NOTIFIERS
// ═══════════════════════════════════════════════════════════════════════

// ─── User Profile ──────────────────────────────────────────────────────

/// Watches the current user profile.
/// Returns null if user has not completed onboarding.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(userProfileRepositoryProvider);
  return repo.getProfile();
});

/// Active user ID (from profile). Null if no profile.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.uid;
});

/// Whether onboarding is complete (gates navigation to main app).
final isOnboardingCompleteProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return profile?.hasCompletedOnboarding ?? false;
});

/// Current zodiac sign (or 'gemini' as placeholder before onboarding).
final currentZodiacSignProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.zodiacSign ?? 'gemini';
});

// ─── Subscription ──────────────────────────────────────────────────────

/// Current subscription status.
/// Fail-safe: returns free status if user ID is null or on error.
final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(SubscriptionStatus.free('guest'));
  }
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.watchStatus(userId);
});

/// Quick boolean: does user have premium access?
/// Fail-safe: false when subscription state is unknown.
final hasPremiumAccessProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionStatusProvider).valueOrNull?.hasPremiumAccess ?? false;
});

// ─── Today's Reading ───────────────────────────────────────────────────

/// Provider params for today's reading fetch.
class TodayReadingParams {
  const TodayReadingParams({required this.userId, required this.zodiacSign});
  final String userId;
  final String zodiacSign;
}

/// Today's horoscope reading.
/// Automatically uses current user + zodiac sign from profile.
final todayReadingProvider = FutureProvider<DailyReading?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final zodiacSign = ref.watch(currentZodiacSignProvider);

  if (userId == null) return null;

  final repo = ref.watch(horoscopeRepositoryProvider);
  return repo.getTodayReading(
    userId: userId,
    zodiacSign: zodiacSign,
  );
});

// ─── App Settings ──────────────────────────────────────────────────────

/// Selected horoscope category (General/Love/Work/Wellbeing).
/// Persisted to user profile in stage 3.
final selectedHoroscopeCategoryProvider =
    StateProvider<String>((ref) => 'general');

/// Current app theme mode from user profile.
final appThemeModeProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.themeMode ?? 'dark';
});

/// Current app language from user profile.
final appLanguageProvider = Provider<String>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.preferredLanguage ?? 'en';
});

// ─── Tarot ─────────────────────────────────────────────────────────────────

/// Today's daily card for the current user.
/// Deterministic: same result every time for same user+date+zodiac.
final dailyCardProvider = FutureProvider<TarotCard?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final zodiacSign = ref.watch(currentZodiacSignProvider);
  if (userId == null) return null;

  return ref.watch(tarotRepositoryProvider).getDailyCard(
    userId: userId,
    zodiacSign: zodiacSign,
    date: DateTime.now(),
  );
});

/// 3-card spread for current user (premium).
/// Deterministic: same result every time for same user+date+zodiac.
/// Call only when [hasPremiumAccessProvider] is true.
final threeCardSpreadProvider = FutureProvider<List<TarotCard>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final zodiacSign = ref.watch(currentZodiacSignProvider);
  if (userId == null) return [];

  return ref.watch(tarotRepositoryProvider).getThreeCardSpread(
    userId: userId,
    zodiacSign: zodiacSign,
    date: DateTime.now(),
  );
});
