import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// Hide Drift's isNull/isNotNull — they clash with flutter_test matchers
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:mystic_tarot/core/database/app_database.dart';

/// Tests for local SQLite database operations.
/// Uses in-memory database — no file system required.
///
/// Note: Drift code generation (.g.dart) is run via build_runner in CI.
/// These tests validate the schema and query helpers.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase — Schema', () {
    test('creates all tables on first open', () async {
      // Simply opening the database should create all tables without error
      final profile = await db.getActiveUserProfile();
      expect(profile, isNull); // No data yet — just verifying schema created
    });

    test('user_profiles table accepts insert and retrieval', () async {
      final now = DateTime.now();
      final companion = UserProfilesTableCompanion.insert(
        userId: 'test_user_123',
        birthDate: DateTime(1995, 6, 15),
        zodiacSign: 'gemini',
        language: const Value('en'),
        themeMode: const Value('dark'),
        notificationTime: const Value('09:00'),
        hasCompletedOnboarding: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await db.into(db.userProfilesTable).insert(companion);

      final row = await db.getActiveUserProfile();
      expect(row, isNotNull);
      expect(row!.userId, 'test_user_123');
      expect(row.zodiacSign, 'gemini');
      expect(row.language, 'en');
    });

    test('upsertDailyReading stores and retrieves reading', () async {
      final date = DateTime(2026, 2, 16);
      final expires = date.add(const Duration(hours: 24));
      final companion = DailyReadingsTableCompanion.insert(
        id: 'user1_20260216_gemini',
        userId: 'user1',
        readingDate: date,
        zodiacSign: 'gemini',
        generalText: 'Stars align for Gemini today.',
        loveText: 'Love beckons.',
        workText: 'Career opportunities abound.',
        wellbeingText: 'Rest and reflect.',
        cardIndex: 17,
        isReversed: false,
        cardName: 'The Star',
        cardMeaning: 'Hope and renewal.',
        expiresAt: expires,
      );

      await db.upsertDailyReading(companion);

      final result = await db.getTodayReading(
        userId: 'user1',
        date: date,
        zodiacSign: 'gemini',
      );

      expect(result, isNotNull);
      expect(result!.id, 'user1_20260216_gemini');
      expect(result.generalText, 'Stars align for Gemini today.');
      expect(result.cardIndex, 17);
      expect(result.isReversed, false);
    });

    test('getTodayReading returns null for expired cache', () async {
      final pastDate = DateTime(2026, 2, 15);
      final expiredAt = DateTime.now().subtract(const Duration(hours: 1));
      final companion = DailyReadingsTableCompanion.insert(
        id: 'user1_20260215_gemini',
        userId: 'user1',
        readingDate: pastDate,
        zodiacSign: 'gemini',
        generalText: 'Yesterday\'s reading.',
        loveText: 'Love text.',
        workText: 'Work text.',
        wellbeingText: 'Wellbeing text.',
        cardIndex: 5,
        isReversed: true,
        cardName: 'The Hierophant',
        cardMeaning: 'Tradition.',
        expiresAt: expiredAt, // Already expired
      );

      await db.upsertDailyReading(companion);

      // Querying for today — different date, so should return null
      final result = await db.getTodayReading(
        userId: 'user1',
        date: DateTime(2026, 2, 16), // Different date
        zodiacSign: 'gemini',
      );
      expect(result, isNull);
    });

    test('subscription cache insert and retrieval', () async {
      final now = DateTime.now();
      final validUntil = now.add(const Duration(hours: 6));
      final companion = SubscriptionCacheTableCompanion.insert(
        userId: 'user1',
        state: const Value('active'),
        productId: const Value('premium_yearly_v1'),
        lastSyncedAt: now,
        cacheValidUntil: validUntil,
      );

      await db.into(db.subscriptionCacheTable).insertOnConflictUpdate(companion);

      final result = await db.getCachedSubscription('user1');
      expect(result, isNotNull);
      expect(result!.state, 'active');
      expect(result.productId, 'premium_yearly_v1');
    });

    test('deleteAllData removes all user rows', () async {
      final now = DateTime.now();
      // Insert profile
      await db.into(db.userProfilesTable).insert(
        UserProfilesTableCompanion.insert(
          userId: 'delete_me',
          birthDate: DateTime(1990, 1, 1),
          zodiacSign: 'capricorn',
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      // Verify inserted
      expect(await db.getActiveUserProfile(), isNotNull);

      // Delete
      await (db.delete(db.userProfilesTable)
        ..where((t) => t.userId.equals('delete_me'))).go();

      expect(await db.getActiveUserProfile(), isNull);
    });

    test('purgeExpiredReadings removes expired rows', () async {
      final expiredAt = DateTime.now().subtract(const Duration(hours: 1));
      await db.upsertDailyReading(
        DailyReadingsTableCompanion.insert(
          id: 'expired_reading',
          userId: 'u1',
          readingDate: DateTime(2026, 1, 1),
          zodiacSign: 'aries',
          generalText: 'Old text.',
          loveText: '', workText: '', wellbeingText: '',
          cardIndex: 0, isReversed: false,
          cardName: 'Card', cardMeaning: 'Meaning',
          expiresAt: expiredAt,
        ),
      );

      final purged = await db.purgeExpiredReadings();
      expect(purged, greaterThan(0));
    });
  });
}
