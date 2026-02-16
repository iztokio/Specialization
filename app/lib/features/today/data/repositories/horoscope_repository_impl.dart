import 'package:drift/drift.dart';
import 'package:mystic_tarot/features/tarot/domain/entities/tarot_card.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/daily_reading.dart';
import '../../domain/repositories/horoscope_repository.dart';

/// Offline-first implementation of [HoroscopeRepository].
///
/// Stage 2: Cache-first with placeholder content.
/// Stage 3: Firestore remote datasource added.
///
/// Cache strategy:
/// - Valid for 24h after [cachedAt]
/// - Background refresh when content_version from Remote Config changes
/// - Deterministic seed: same date + sign = same reading every time
class HoroscopeRepositoryImpl implements HoroscopeRepository {
  HoroscopeRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<DailyReading> getTodayReading({
    required String userId,
    required String zodiacSign,
    bool forceRefresh = false,
  }) async {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);

    if (!forceRefresh) {
      final cached = await _db.getTodayReading(
        userId: userId,
        date: dateOnly,
        zodiacSign: zodiacSign,
      );
      if (cached != null) return _rowToEntity(cached);
    }

    // TODO(stage3): Fetch from Firestore remote datasource
    // For now, generate deterministic placeholder content
    final reading = _generatePlaceholderReading(
      userId: userId,
      zodiacSign: zodiacSign,
      date: dateOnly,
    );

    // Cache locally
    await _db.upsertDailyReading(_entityToCompanion(reading));
    return reading;
  }

  @override
  Future<DailyReading?> getReadingForDate({
    required String userId,
    required String zodiacSign,
    required DateTime date,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final cached = await _db.getTodayReading(
      userId: userId,
      date: dateOnly,
      zodiacSign: zodiacSign,
    );
    return cached != null ? _rowToEntity(cached) : null;
  }

  @override
  Future<List<DailyReading>> getReadingHistory({
    required String userId,
    required String zodiacSign,
    required int days,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await (_db.select(_db.dailyReadingsTable)
      ..where((t) => t.userId.equals(userId))
      ..where((t) => t.zodiacSign.equals(zodiacSign))
      ..where((t) => t.readingDate.isBiggerOrEqualValue(cutoff))
      ..orderBy([(t) => OrderingTerm.desc(t.readingDate)]))
        .get();
    return rows.map(_rowToEntity).toList();
  }

  @override
  Future<void> purgeOldReadings({int keepDays = 90}) async {
    await _db.purgeExpiredReadings();
  }

  // ─── Placeholder content (Stage 3: replace with Firestore) ─────────────

  DailyReading _generatePlaceholderReading({
    required String userId,
    required String zodiacSign,
    required DateTime date,
  }) {
    final seed = DailyReading.generateSeed(date, zodiacSign);
    final cardIndices = DailyReading.selectCardIndices(
      seed: seed,
      count: 1,
      totalCards: AppConstants.totalTarotCards,
    );
    final cardIndex = cardIndices.first;
    final isReversed = seed % 3 == 0;
    final position = isReversed ? TarotPosition.reversed : TarotPosition.upright;
    final placeholderText = _placeholder(zodiacSign);

    // Minimal placeholder TarotCard — Stage 3 populates from Firestore
    final placeholderCard = TarotCard(
      id: 'placeholder_$cardIndex',
      number: cardIndex,
      arcana: cardIndex < 22 ? TarotArcana.major : TarotArcana.minor,
      suit: TarotSuit.none,
      names: LocalizedText(en: 'Card ${cardIndex + 1}', es: 'Carta ${cardIndex + 1}', pt: 'Carta ${cardIndex + 1}', ru: 'Карта ${cardIndex + 1}'),
      imageUrl: '',
      imageLicense: 'pending',
      imageSource: 'pending',
      meanings: TarotMeanings(
        upright: LocalizedText(en: placeholderText, es: placeholderText, pt: placeholderText, ru: placeholderText),
        reversed: LocalizedText(en: placeholderText, es: placeholderText, pt: placeholderText, ru: placeholderText),
        love: LocalizedText(en: placeholderText, es: placeholderText, pt: placeholderText, ru: placeholderText),
        work: LocalizedText(en: placeholderText, es: placeholderText, pt: placeholderText, ru: placeholderText),
        health: LocalizedText(en: placeholderText, es: placeholderText, pt: placeholderText, ru: placeholderText),
      ),
      version: 0,
    );

    return DailyReading(
      id: DailyReading.makeId(userId, date),
      uid: userId,
      date: date,
      zodiacSign: zodiacSign,
      horoscope: LocalizedText(
        en: _placeholderHoroscope(zodiacSign, 'general'),
        es: _placeholderHoroscope(zodiacSign, 'general'),
        pt: _placeholderHoroscope(zodiacSign, 'general'),
        ru: _placeholderHoroscope(zodiacSign, 'general'),
      ),
      drawnCards: [
        DrawnCard(card: placeholderCard, position: position, spreadPosition: 0),
      ],
      seed: seed,
      contentVersion: 0,
      language: 'en',
      isPremium: false,
      createdAt: DateTime.now(),
    );
  }

  String _placeholder(String sign) =>
      'The stars illuminate your path for today. '
      'Trust your intuition. For entertainment only.';

  String _placeholderHoroscope(String sign, String category) {
    // Stage 3 replaces with Firestore content per category + language
    return 'Today, the cosmic energies align uniquely for $sign. '
        'Your $category path is illuminated by the stars. '
        'Trust your intuition and embrace the opportunities ahead. '
        'For entertainment purposes only.';
  }

  // ─── Mapping helpers ────────────────────────────────────────────────────
  //
  // The DB stores a flat snapshot for performance; the rich entity is
  // reconstructed on read. Stage 3 adds full multilingual content.

  DailyReading _rowToEntity(DailyReadingsTableData row) {
    final text = row.generalText;
    final isReversed = row.isReversed;
    final position = isReversed ? TarotPosition.reversed : TarotPosition.upright;

    final placeholderCard = TarotCard(
      id: 'placeholder_${row.cardIndex}',
      number: row.cardIndex,
      arcana: row.cardIndex < 22 ? TarotArcana.major : TarotArcana.minor,
      suit: TarotSuit.none,
      names: LocalizedText(en: row.cardName, es: row.cardName, pt: row.cardName, ru: row.cardName),
      imageUrl: '',
      imageLicense: 'pending',
      imageSource: 'pending',
      meanings: TarotMeanings(
        upright: LocalizedText(en: row.cardMeaning, es: row.cardMeaning, pt: row.cardMeaning, ru: row.cardMeaning),
        reversed: LocalizedText(en: row.cardMeaning, es: row.cardMeaning, pt: row.cardMeaning, ru: row.cardMeaning),
        love: LocalizedText(en: row.loveText, es: row.loveText, pt: row.loveText, ru: row.loveText),
        work: LocalizedText(en: row.workText, es: row.workText, pt: row.workText, ru: row.workText),
        health: LocalizedText(en: row.wellbeingText, es: row.wellbeingText, pt: row.wellbeingText, ru: row.wellbeingText),
      ),
      version: int.tryParse(row.contentVersion) ?? 0,
    );

    return DailyReading(
      // Entity ID uses makeId (uid + date, no zodiac) — consistent with domain.
      // DB key includes zodiac (internal storage key — not exposed to domain).
      id: DailyReading.makeId(row.userId, row.readingDate),
      uid: row.userId,
      date: row.readingDate,
      zodiacSign: row.zodiacSign,
      horoscope: LocalizedText(en: text, es: text, pt: text, ru: text),
      drawnCards: [
        DrawnCard(card: placeholderCard, position: position, spreadPosition: 0),
      ],
      seed: DailyReading.generateSeed(row.readingDate, row.zodiacSign),
      contentVersion: int.tryParse(row.contentVersion) ?? 0,
      language: 'en',
      isPremium: false,
      createdAt: row.cachedAt,
    );
  }

  DailyReadingsTableCompanion _entityToCompanion(DailyReading e) {
    final card = e.drawnCards.isNotEmpty ? e.drawnCards.first : null;
    final cardIndex = card?.card.number ?? 0;
    final isReversed = card?.position == TarotPosition.reversed;
    final cardName = card?.card.getName('en') ?? '';
    final cardMeaning = card?.card.meanings.upright.en ?? '';

    // DB key includes zodiacSign so each sign has its own row.
    // Entity.id (no sign) is the business key; DB id is the storage key.
    final dbId = '${e.uid}_${_dateToStr(e.date)}_${e.zodiacSign}';
    return DailyReadingsTableCompanion.insert(
      id: dbId,
      userId: e.uid,
      readingDate: e.date,
      zodiacSign: e.zodiacSign,
      generalText: e.horoscope.en,
      loveText: card?.card.meanings.love.en ?? e.horoscope.en,
      workText: card?.card.meanings.work.en ?? e.horoscope.en,
      wellbeingText: card?.card.meanings.health.en ?? e.horoscope.en,
      cardIndex: cardIndex,
      isReversed: isReversed,
      cardName: cardName,
      cardMeaning: cardMeaning,
      contentVersion: Value(e.contentVersion.toString()),
      cachedAt: Value(e.createdAt),
      expiresAt: e.createdAt.add(AppConstants.contentCacheDuration),
    );
  }

  static String _dateToStr(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}$m$day';
  }
}
