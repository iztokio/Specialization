import 'package:drift/drift.dart';

/// Local cache of tarot card draws (beyond daily card).
/// Includes 3-card spread results for premium users.
/// Keyed by userId + date + spread type.
class TarotReadingsTable extends Table {
  @override
  String get tableName => 'tarot_readings';

  TextColumn get id => text().withLength(min: 1, max: 200)();
  TextColumn get userId => text().withLength(min: 1, max: 128)();

  DateTimeColumn get readingDate => dateTime()();

  // 'daily_card', 'three_card_spread'
  TextColumn get spreadType => text().withLength(min: 1, max: 50)();

  // Serialized card data (JSON array of card results)
  TextColumn get cardsJson => text()(); // [{index, name, isReversed, meaning}]

  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();

  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get indexes => [
    Index('idx_tarot_readings_user_date', 'CREATE INDEX IF NOT EXISTS '
        'idx_tarot_readings_user_date ON tarot_readings (userId, readingDate)'),
  ];
}
