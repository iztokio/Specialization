import '../entities/daily_reading.dart';

/// Contract for fetching and caching daily horoscope + card of the day.
///
/// Offline-first strategy:
/// - Cache-first: return local if valid (not expired)
/// - Background refresh: silently fetch Firestore if content version changed
/// - Deterministic: same zodiac sign + date = same reading (no randomness)
///
/// Content version: checked against Remote Config 'content_version'.
/// If server version > local version, trigger refresh even if cache is valid.
abstract interface class HoroscopeRepository {
  /// Get today's reading for the given zodiac sign.
  ///
  /// Cache validity: 24h from [cachedAt].
  /// Returns cached value immediately; triggers background refresh if stale.
  ///
  /// [forceRefresh]: bypass cache and fetch from Firestore.
  Future<DailyReading> getTodayReading({
    required String userId,
    required String zodiacSign,
    bool forceRefresh = false,
  });

  /// Get reading for a specific past date (history feature).
  /// Only returns cached data — no server fetch for past dates.
  Future<DailyReading?> getReadingForDate({
    required String userId,
    required String zodiacSign,
    required DateTime date,
  });

  /// Get readings for the last [days] days (history list).
  /// [days]: 7 for free, 90 for premium.
  Future<List<DailyReading>> getReadingHistory({
    required String userId,
    required String zodiacSign,
    required int days,
  });

  /// Purge readings older than [days] days from local cache.
  Future<void> purgeOldReadings({int keepDays = 90});
}
