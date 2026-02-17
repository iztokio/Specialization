import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Offline-first implementation of [UserProfileRepository].
///
/// Stage 2: Local-only (Drift). Firestore sync added in Stage 3.
class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<UserProfile?> getProfile() async {
    final row = await _db.getActiveUserProfile();
    if (row == null) return null;
    return _rowToEntity(row);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _db.into(_db.userProfilesTable).insertOnConflictUpdate(
      _entityToCompanion(profile),
    );
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    await saveProfile(profile);
  }

  @override
  Future<void> acceptDisclaimer(String userId) async {
    await (_db.update(_db.userProfilesTable)
      ..where((t) => t.userId.equals(userId)))
        .write(
      UserProfilesTableCompanion(
        hasAcceptedDisclaimer: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    // TODO(stage3): Write disclaimer acceptance timestamp to Firestore
    //   for compliance audit trail (userId, acceptedAt, appVersion)
  }

  @override
  Future<void> completeOnboarding(String userId) async {
    await (_db.update(_db.userProfilesTable)
      ..where((t) => t.userId.equals(userId)))
        .write(
      UserProfilesTableCompanion(
        hasCompletedOnboarding: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteAllData(String userId) async {
    await (_db.delete(_db.userProfilesTable)
      ..where((t) => t.userId.equals(userId)))
        .go();
    await (_db.delete(_db.dailyReadingsTable)
      ..where((t) => t.userId.equals(userId)))
        .go();
    await (_db.delete(_db.tarotReadingsTable)
      ..where((t) => t.userId.equals(userId)))
        .go();
    await (_db.delete(_db.subscriptionCacheTable)
      ..where((t) => t.userId.equals(userId)))
        .go();
    // TODO(stage3): Delete Firestore user document + trigger Cloud Function
  }

  // ─── Mapping helpers ────────────────────────────────────────────────────

  UserProfile _rowToEntity(UserProfilesTableData row) {
    return UserProfile(
      uid: row.userId,
      birthDate: row.birthDate,
      zodiacSign: row.zodiacSign,
      gender: row.gender,
      birthTime: row.birthTime,
      birthPlaceName: row.birthPlace,
      preferredLanguage: row.language,
      notificationTime: row.notificationTime,
      themeMode: row.themeMode,
      hasCompletedOnboarding: row.hasCompletedOnboarding,
      createdAt: row.createdAt,
    );
  }

  UserProfilesTableCompanion _entityToCompanion(UserProfile e) {
    return UserProfilesTableCompanion.insert(
      userId: e.uid,
      birthDate: e.birthDate,
      zodiacSign: e.zodiacSign,
      gender: Value(e.gender),
      birthTime: Value(e.birthTime),
      birthPlace: Value(e.birthPlaceName),
      language: Value(e.preferredLanguage),
      themeMode: Value(e.themeMode),
      notificationTime: Value(e.notificationTime),
      hasCompletedOnboarding: Value(e.hasCompletedOnboarding),
      createdAt: Value(e.createdAt),
      updatedAt: Value(DateTime.now()),
    );
  }
}
