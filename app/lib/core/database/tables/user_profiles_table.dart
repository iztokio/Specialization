import 'package:drift/drift.dart';

/// Local cache of user profile data.
/// Single-row table (userId = primary key, typically one active user).
class UserProfilesTable extends Table {
  @override
  String get tableName => 'user_profiles';

  TextColumn get userId => text().withLength(min: 1, max: 128)();
  DateTimeColumn get birthDate => dateTime()();
  TextColumn get zodiacSign => text().withLength(min: 3, max: 20)();

  // Optional personalization
  TextColumn get gender => text().nullable().withLength(max: 30)();
  TextColumn get birthTime => text().nullable().withLength(max: 10)(); // HH:mm
  TextColumn get birthPlace => text().nullable().withLength(max: 100)();

  // UI preferences
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get themeMode => text().withDefault(const Constant('dark'))();

  // Notification preferences
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get notificationTime =>
      text().withDefault(const Constant('09:00'))();

  // Onboarding state
  BoolColumn get hasCompletedOnboarding => boolean().withDefault(const Constant(false))();
  BoolColumn get hasAcceptedDisclaimer => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId};
}
