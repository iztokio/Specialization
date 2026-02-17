import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:mystic_tarot/core/database/app_database.dart';
import 'package:mystic_tarot/features/onboarding/data/repositories/user_profile_repository_impl.dart';
import 'package:mystic_tarot/features/onboarding/domain/entities/user_profile.dart';

/// Stage 3: Integration tests for the onboarding flow.
///
/// Tests the full user journey through UserProfileRepository:
///   1. saveProfile → getProfile round-trip
///   2. acceptDisclaimer updates flag
///   3. completeOnboarding updates flag
///   4. deleteAllData wipes profile
///   5. getProfile returns null before first profile save
///   6. Second saveProfile overwrites first (conflict update)
void main() {
  late AppDatabase db;
  late UserProfileRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = UserProfileRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  group('Onboarding flow — UserProfileRepository', () {
    const uid = 'onboarding_test_user';

    UserProfile _makeProfile({String language = 'en'}) =>
        UserProfile.fromOnboarding(
          uid: uid,
          birthDate: DateTime(1995, 6, 10), // Gemini ♊ (Jun 10, well within May 21–Jun 20)
          language: language,
        );

    test('getProfile returns null before any save', () async {
      final profile = await repo.getProfile();
      expect(profile, isNull);
    });

    test('saveProfile → getProfile round-trip preserves all fields', () async {
      final profile = _makeProfile();
      await repo.saveProfile(profile);

      final loaded = await repo.getProfile();
      expect(loaded, isNotNull);
      expect(loaded!.uid, uid);
      expect(loaded.zodiacSign, 'gemini');
      expect(loaded.birthDate.year, 1995);
      expect(loaded.birthDate.month, 6);
      expect(loaded.birthDate.day, 10);
      expect(loaded.preferredLanguage, 'en');
      expect(loaded.hasCompletedOnboarding, isFalse);
    });

    test('second saveProfile overwrites first (upsert semantics)', () async {
      await repo.saveProfile(_makeProfile(language: 'en'));
      await repo.saveProfile(_makeProfile(language: 'es'));

      final loaded = await repo.getProfile();
      expect(loaded!.preferredLanguage, 'es');

      // Confirm only one row in DB
      final all = await db.select(db.userProfilesTable).get();
      expect(all.length, 1);
    });

    test('acceptDisclaimer sets hasAcceptedDisclaimer flag', () async {
      await repo.saveProfile(_makeProfile());
      await repo.acceptDisclaimer(uid);

      final row = await (db.select(db.userProfilesTable)
        ..where((t) => t.userId.equals(uid)))
          .getSingleOrNull();
      expect(row?.hasAcceptedDisclaimer, isTrue);
    });

    test('completeOnboarding sets hasCompletedOnboarding flag', () async {
      await repo.saveProfile(_makeProfile());

      // Verify not completed before
      final before = await repo.getProfile();
      expect(before!.hasCompletedOnboarding, isFalse);

      await repo.completeOnboarding(uid);

      final after = await repo.getProfile();
      expect(after!.hasCompletedOnboarding, isTrue);
    });

    test('deleteAllData removes profile row', () async {
      await repo.saveProfile(_makeProfile());
      expect(await repo.getProfile(), isNotNull);

      await repo.deleteAllData(uid);
      expect(await repo.getProfile(), isNull);
    });

    test('deleteAllData also clears daily_readings for user', () async {
      await repo.saveProfile(_makeProfile());
      // Insert a dummy reading row
      await db.into(db.dailyReadingsTable).insert(
        DailyReadingsTableCompanion.insert(
          id: '${uid}_20260216_gemini',
          userId: uid,
          readingDate: DateTime(2026, 2, 16),
          zodiacSign: 'gemini',
          generalText: 'test',
          loveText: 'test',
          workText: 'test',
          wellbeingText: 'test',
          cardIndex: 0,
          isReversed: false,
          cardName: 'The Fool',
          cardMeaning: 'New beginnings',
          expiresAt: DateTime(2026, 2, 17),
        ),
      );

      await repo.deleteAllData(uid);

      final readings = await (db.select(db.dailyReadingsTable)
        ..where((t) => t.userId.equals(uid)))
          .get();
      expect(readings, isEmpty);
    });
  });
}
