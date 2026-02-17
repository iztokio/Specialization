import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'tables/user_profiles_table.dart';
import 'tables/daily_readings_table.dart';
import 'tables/tarot_readings_table.dart';
import 'tables/subscription_cache_table.dart';

part 'app_database.g.dart';

/// AstraLume local SQLite database (Drift).
///
/// VERSIONING POLICY:
/// - Every schema change MUST add a migration step in [_migrate]
/// - Never modify an existing migration — always add a new one
/// - Test migrations in [test/unit/core/database_migration_test.dart]
///
/// USAGE:
/// - Injected via Riverpod (see core/providers/core_providers.dart)
/// - Accessed through Repository interfaces — never use directly in UI
@DriftDatabase(tables: [
  UserProfilesTable,
  DailyReadingsTable,
  TarotReadingsTable,
  SubscriptionCacheTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Exposed for testing — allows injecting in-memory database
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      await _migrate(m, from, to);
    },
    beforeOpen: (details) async {
      // Enable WAL mode for better concurrent read performance
      await customStatement('PRAGMA journal_mode=WAL');
      // Enable foreign keys
      await customStatement('PRAGMA foreign_keys=ON');
    },
  );

  Future<void> _migrate(
    Migrator m,
    int from,
    int to,
  ) async {
    // v1 → v2 example (for future use):
    // if (from < 2) {
    //   await m.addColumn(userProfilesTable, userProfilesTable.newColumn);
    // }
    //
    // IMPORTANT: Always add new migrations here, never modify existing ones.
    // Each migration block must be idempotent (if from < N).
  }

  // ─── Convenience query helpers ─────────────────────────────────────────

  /// Get the active user profile (first/only row for single-user app)
  Future<UserProfilesTableData?> getActiveUserProfile() {
    return (select(userProfilesTable)..limit(1)).getSingleOrNull();
  }

  /// Get cached daily reading for today
  Future<DailyReadingsTableData?> getTodayReading({
    required String userId,
    required DateTime date,
    required String zodiacSign,
  }) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final id = '${userId}_${_dateToStr(dateOnly)}_$zodiacSign';
    return (select(dailyReadingsTable)
      ..where((t) => t.id.equals(id))
      ..where((t) => t.expiresAt.isBiggerOrEqualValue(DateTime.now())))
        .getSingleOrNull();
  }

  /// Upsert a daily reading (replace if exists)
  Future<void> upsertDailyReading(DailyReadingsTableCompanion reading) {
    return into(dailyReadingsTable).insertOnConflictUpdate(reading);
  }

  /// Get cached subscription status
  Future<SubscriptionCacheTableData?> getCachedSubscription(String userId) {
    return (select(subscriptionCacheTable)
      ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
  }

  /// Upsert subscription cache (always replace with latest server value)
  Future<void> upsertSubscriptionCache(
    SubscriptionCacheTableCompanion cache,
  ) {
    return into(subscriptionCacheTable).insertOnConflictUpdate(cache);
  }

  /// Purge expired readings (called on app foreground)
  Future<int> purgeExpiredReadings() {
    return (delete(dailyReadingsTable)
      ..where((t) => t.expiresAt.isSmallerThanValue(DateTime.now())))
        .go();
  }

  /// Purge expired tarot readings
  Future<int> purgeExpiredTarotReadings() {
    return (delete(tarotReadingsTable)
      ..where((t) => t.expiresAt.isSmallerThanValue(DateTime.now())))
        .go();
  }

  static String _dateToStr(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}$m$day';
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    Directory dir;
    try {
      // Prefer application support dir (maps to XDG_DATA_HOME on Linux)
      dir = await getApplicationSupportDirectory();
    } catch (_) {
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        // Final fallback for headless/CI environments
        dir = Directory('/tmp/astralume');
        await dir.create(recursive: true);
      }
    }
    final file = File(p.join(dir.path, 'astralume.db'));
    return NativeDatabase.createInBackground(file);
  });
}
