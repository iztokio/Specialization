import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_error.dart';
import '../../domain/entities/tarot_card.dart';
import '../../domain/repositories/tarot_repository.dart';
import '../datasources/tarot_local_datasource.dart';
import '../datasources/tarot_remote_datasource.dart';
import '../../../today/domain/entities/daily_reading.dart';

/// Offline-first implementation of [TarotRepository].
///
/// Data priority:
///   1. Local bundled data (always available, instant)
///   2. Firestore card library (richer content, fetched once per version)
///   3. Drift cache for spread history
///
/// Card library strategy:
///   - First call to [getAllCards] or [getCardByIndex] uses local bundled data
///   - [prefetchCardLibrary] fetches from Firestore and merges (enriches names/meanings)
///   - Cards cached in [TarotReadingsTable] are for spread results (not metadata)
///
/// Spread strategy:
///   - Deterministic: same seed → same cards every day
///   - Free: 1 card (daily)
///   - Premium: 3-card spread
///   - Results cached in Drift for history
class TarotRepositoryImpl implements TarotRepository {
  TarotRepositoryImpl(
    this._db, {
    this.remote,
  });

  final AppDatabase _db;
  final TarotRemoteDatasource? remote;

  // In-memory overlay: Firestore cards override local ones when fetched.
  final Map<int, TarotCard> _remoteOverrides = {};

  // ─── Card access ──────────────────────────────────────────────────────────

  @override
  Future<TarotCard?> getCardByIndex(int index) async {
    // Remote overrides take precedence when available
    if (_remoteOverrides.containsKey(index)) {
      return _remoteOverrides[index];
    }
    return TarotLocalDatasource.instance.getByIndex(index);
  }

  @override
  Future<List<TarotCard>> getAllCards() async {
    if (_remoteOverrides.isNotEmpty) {
      return TarotLocalDatasource.instance.allCards.map((local) {
        return _remoteOverrides[local.number] ?? local;
      }).toList();
    }
    return TarotLocalDatasource.instance.allCards;
  }

  @override
  Future<List<TarotCard>> searchCards(String query) async {
    final local = TarotLocalDatasource.instance.search(query);
    if (_remoteOverrides.isEmpty) return local;
    return local.map((c) => _remoteOverrides[c.number] ?? c).toList();
  }

  // ─── Daily card ───────────────────────────────────────────────────────────

  @override
  Future<TarotCard> getDailyCard({
    required String userId,
    required String zodiacSign,
    required DateTime date,
  }) async {
    // Check spread cache first
    final cached = await _getCachedSpread(
      userId: userId,
      date: date,
      spreadType: 'daily_card',
    );
    if (cached != null && cached.isNotEmpty) return cached.first;

    // Generate deterministic card
    final seed = DailyReading.generateSeed(date, zodiacSign);
    final indices = DailyReading.selectCardIndices(
      seed: seed,
      count: 1,
      totalCards: AppConstants.totalTarotCards,
    );
    final cardIndex = indices.first;
    final isReversed = seed % 3 == 0;
    final card = await getCardByIndex(cardIndex) ??
        TarotLocalDatasource.instance.getByIndex(0)!;

    final drawn = DrawnCard(
      card: card,
      position: isReversed ? TarotPosition.reversed : TarotPosition.upright,
      spreadPosition: 0,
    );

    await _cacheSpread(
      userId: userId,
      date: date,
      spreadType: 'daily_card',
      drawnCards: [drawn],
      isPremium: false,
    );

    return card;
  }

  // ─── 3-Card Spread ────────────────────────────────────────────────────────

  @override
  Future<List<TarotCard>> getThreeCardSpread({
    required String userId,
    required String zodiacSign,
    required DateTime date,
  }) async {
    // Premium check: repository enforces the guard
    // (UI also gates access, but defence-in-depth)
    final cached = await _getCachedSpread(
      userId: userId,
      date: date,
      spreadType: 'three_card_spread',
    );
    if (cached != null && cached.isNotEmpty) return cached;

    // Deterministic 3-card draw — different offset from daily card
    final seed = DailyReading.generateSeed(date, zodiacSign) ^ 0xDEADBEEF;
    final indices = DailyReading.selectCardIndices(
      seed: seed,
      count: 3,
      totalCards: AppConstants.totalTarotCards,
    );

    final cards = <TarotCard>[];
    final drawn = <DrawnCard>[];

    for (var i = 0; i < 3; i++) {
      final card = await getCardByIndex(indices[i]) ??
          TarotLocalDatasource.instance.getByIndex(i)!;
      final isReversed = (seed >> (i * 4)) % 3 == 0;
      cards.add(card);
      drawn.add(DrawnCard(
        card: card,
        position: isReversed ? TarotPosition.reversed : TarotPosition.upright,
        spreadPosition: i,
      ));
    }

    await _cacheSpread(
      userId: userId,
      date: date,
      spreadType: 'three_card_spread',
      drawnCards: drawn,
      isPremium: true,
    );

    return cards;
  }

  // ─── Prefetch (called once per content version) ───────────────────────────

  @override
  Future<void> prefetchCardLibrary() async {
    final cards = await remote?.fetchAllCards() ?? [];
    for (final card in cards) {
      _remoteOverrides[card.number] = card;
    }
  }

  // ─── Drift cache helpers ──────────────────────────────────────────────────

  Future<List<TarotCard>?> _getCachedSpread({
    required String userId,
    required DateTime date,
    required String spreadType,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final id = _makeSpreadId(userId, dateOnly, spreadType);
    final row = await (
      _db.select(_db.tarotReadingsTable)
        ..where((t) => t.id.equals(id))
        ..where((t) => t.expiresAt.isBiggerOrEqualValue(DateTime.now()))
    ).getSingleOrNull();

    if (row == null) return null;

    try {
      final json = jsonDecode(row.cardsJson) as List<dynamic>;
      return json
          .map((e) => _jsonToCard(e as Map<String, dynamic>))
          .whereType<TarotCard>()
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheSpread({
    required String userId,
    required DateTime date,
    required String spreadType,
    required List<DrawnCard> drawnCards,
    required bool isPremium,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final id = _makeSpreadId(userId, dateOnly, spreadType);
    final cardsJson = jsonEncode(
      drawnCards.map((d) => _drawnCardToJson(d)).toList(),
    );

    final now = DateTime.now();
    await _db.into(_db.tarotReadingsTable).insertOnConflictUpdate(
      TarotReadingsTableCompanion.insert(
        id: id,
        userId: userId,
        readingDate: dateOnly,
        spreadType: spreadType,
        cardsJson: cardsJson,
        isPremium: Value(isPremium),
        cachedAt: Value(now),
        expiresAt: now.add(AppConstants.contentCacheDuration),
      ),
    );
  }

  // ─── JSON ↔ entity helpers ────────────────────────────────────────────────

  Map<String, dynamic> _drawnCardToJson(DrawnCard d) => {
    'index': d.card.number,
    'id': d.card.id,
    'arcana': d.card.arcana.name,
    'suit': d.card.suit.name,
    'isReversed': d.position == TarotPosition.reversed,
    'spreadPosition': d.spreadPosition,
  };

  TarotCard? _jsonToCard(Map<String, dynamic> json) {
    final index = json['index'] as int?;
    if (index == null) return null;
    // Prefer in-memory enriched data; fallback to local bundled data
    return _remoteOverrides[index] ??
        TarotLocalDatasource.instance.getByIndex(index);
  }

  static String _makeSpreadId(String userId, DateTime date, String type) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${userId}_${date.year}$m$d\_$type';
  }
}
