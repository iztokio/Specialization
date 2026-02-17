import 'package:drift/drift.dart';

/// Local cache of daily horoscope readings.
/// One row per (userId, date, zodiacSign).
/// Stays valid for 24h; refreshed from Firestore in background.
class DailyReadingsTable extends Table {
  @override
  String get tableName => 'daily_readings';

  // Composite primary key: id = '{userId}_{YYYYMMDD}_{sign}'
  TextColumn get id => text().withLength(min: 1, max: 200)();
  TextColumn get userId => text().withLength(min: 1, max: 128)();

  // When this reading is for
  DateTimeColumn get readingDate => dateTime()();
  TextColumn get zodiacSign => text().withLength(min: 3, max: 20)();

  // Content — stored as JSON strings for flexibility
  TextColumn get generalText => text()();
  TextColumn get loveText => text()();
  TextColumn get workText => text()();
  TextColumn get wellbeingText => text()();

  // Tarot card of the day (deterministic)
  IntColumn get cardIndex => integer()(); // 0-77
  BoolColumn get isReversed => boolean()();
  TextColumn get cardName => text()();
  TextColumn get cardMeaning => text()();

  // Content versioning — matches Firestore contentVersion
  TextColumn get contentVersion => text().withDefault(const Constant('0'))();

  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [
    Index('idx_daily_readings_user_date', 'CREATE INDEX IF NOT EXISTS '
        'idx_daily_readings_user_date ON daily_readings (userId, readingDate)'),
  ];
}
