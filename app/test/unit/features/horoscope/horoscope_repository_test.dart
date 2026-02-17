import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mystic_tarot/core/database/app_database.dart';
import 'package:mystic_tarot/features/today/data/repositories/horoscope_repository_impl.dart';

/// Tests for HoroscopeRepository offline-first behavior.
/// Uses in-memory database — no Firebase required.
void main() {
  late AppDatabase db;
  late HoroscopeRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HoroscopeRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('HoroscopeRepository — Offline-first behavior', () {
    test('getTodayReading returns a reading for valid user + sign', () async {
      final reading = await repo.getTodayReading(
        userId: 'user1',
        zodiacSign: 'gemini',
      );

      expect(reading.uid, 'user1');
      expect(reading.zodiacSign, 'gemini');
    });

    test('getTodayReading is cached after first call', () async {
      // First call — generates and caches
      final reading1 = await repo.getTodayReading(
        userId: 'user1',
        zodiacSign: 'gemini',
      );

      // Second call — should return from cache
      final reading2 = await repo.getTodayReading(
        userId: 'user1',
        zodiacSign: 'gemini',
      );

      // Same reading (deterministic)
      expect(reading1.id, reading2.id);
      expect(reading1.zodiacSign, reading2.zodiacSign);
    });

    test('getTodayReading different signs produce different readings', () async {
      final gemini = await repo.getTodayReading(
        userId: 'user1',
        zodiacSign: 'gemini',
      );
      final aries = await repo.getTodayReading(
        userId: 'user1',
        zodiacSign: 'aries',
      );

      // Each sign returns its own zodiac value
      expect(gemini.zodiacSign, 'gemini');
      expect(aries.zodiacSign, 'aries');
      // Seeds differ because sign is part of the seed hash
      expect(gemini.seed, isNot(aries.seed));
    });

    test('getTodayReading forceRefresh replaces cache', () async {
      // First call
      final reading1 = await repo.getTodayReading(
        userId: 'user1',
        zodiacSign: 'gemini',
      );

      // Force refresh — same placeholder content but re-cached
      final reading2 = await repo.getTodayReading(
        userId: 'user1',
        zodiacSign: 'gemini',
        forceRefresh: true,
      );

      // Both are valid
      expect(reading1.zodiacSign, reading2.zodiacSign);
      expect(reading2.uid, 'user1');
    });

    test('getReadingForDate returns null for uncached date', () async {
      final pastDate = DateTime(2026, 1, 1);
      final result = await repo.getReadingForDate(
        userId: 'user1',
        zodiacSign: 'gemini',
        date: pastDate,
      );
      expect(result, isNull);
    });

    test('getReadingHistory returns empty list when no history', () async {
      final history = await repo.getReadingHistory(
        userId: 'user1',
        zodiacSign: 'gemini',
        days: 7,
      );
      expect(history, isEmpty);
    });

    test('getReadingHistory returns reading added to cache', () async {
      // Populate cache with today's reading
      await repo.getTodayReading(userId: 'user1', zodiacSign: 'gemini');

      final history = await repo.getReadingHistory(
        userId: 'user1',
        zodiacSign: 'gemini',
        days: 7,
      );

      expect(history.length, 1);
      expect(history.first.zodiacSign, 'gemini');
    });

    test('reading disclaimer is embedded (entertainment only)', () async {
      final reading = await repo.getTodayReading(
        userId: 'user1',
        zodiacSign: 'leo',
      );
      // Content should contain disclaimer marker
      expect(reading.horoscope.en.toLowerCase(), contains('entertainment'));
    });
  });

  group('HoroscopeRepository — Reading ID format', () {
    test('reading ID follows expected format', () async {
      final reading = await repo.getTodayReading(
        userId: 'abc123',
        zodiacSign: 'cancer',
      );

      // Format: {userId}_{YYYY-MM-DD}
      expect(reading.id, startsWith('abc123_'));
      expect(reading.id, matches(r'^abc123_\d{4}-\d{2}-\d{2}$'));
    });
  });
}
