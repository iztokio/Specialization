import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tarot_card.dart';

/// Firestore remote datasource for static tarot card metadata.
///
/// Firestore schema:
///   content/tarot/cards/{cardId}
///   {
///     "id": "major_00_fool",
///     "number": 0,
///     "arcana": "major",
///     "suit": "none",
///     "names": { "en": "The Fool", "es": "El Loco", ... },
///     "imageUrl": "https://...",
///     "imageLicense": "CC0 1.0",
///     "imageSource": "https://...",
///     "meanings": {
///       "upright":  { "en": "...", ... },
///       "reversed": { "en": "...", ... },
///       "love":     { "en": "...", ... },
///       "work":     { "en": "...", ... },
///       "health":   { "en": "...", ... }
///     },
///     "version": 1
///   }
///
/// Content is managed by admin via Firebase Console / scripts.
/// Clients read only. Cache strategy: fetch once per content version,
/// then serve from local DB.
class TarotRemoteDatasource {
  TarotRemoteDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Fetches a single card document by [cardId].
  Future<TarotCard?> fetchCard(String cardId) async {
    try {
      final snap = await _firestore
          .doc('content/tarot/cards/$cardId')
          .get(const GetOptions(source: Source.serverAndCache));
      if (!snap.exists || snap.data() == null) return null;
      return _docToCard(snap.id, snap.data()!);
    } on FirebaseException {
      return null;
    }
  }

  /// Fetches all 78 card documents.
  ///
  /// Returns empty list when offline or collection not yet populated.
  Future<List<TarotCard>> fetchAllCards() async {
    try {
      final snap = await _firestore
          .collection('content/tarot/cards')
          .orderBy('number')
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.docs
          .map((d) => _docToCard(d.id, d.data()))
          .whereType<TarotCard>()
          .toList();
    } on FirebaseException {
      return [];
    }
  }

  // ─── Firestore → entity mapping ───────────────────────────────────────────

  TarotCard? _docToCard(String docId, Map<String, dynamic> data) {
    try {
      final id = data['id'] as String? ?? docId;
      final number = data['number'] as int? ?? 0;
      final arcana = (data['arcana'] as String?) == 'major'
          ? TarotArcana.major
          : TarotArcana.minor;
      final suit = _parseSuit(data['suit'] as String?);
      final version = data['version'] as int? ?? 0;
      final imageUrl = data['imageUrl'] as String? ?? '';
      final imageLicense = data['imageLicense'] as String? ?? 'unknown';
      final imageSource = data['imageSource'] as String? ?? '';

      final namesRaw = data['names'] as Map<String, dynamic>?;
      final names = namesRaw != null
          ? LocalizedText(
              en: namesRaw['en'] as String? ?? '',
              es: namesRaw['es'] as String? ?? '',
              pt: namesRaw['pt'] as String? ?? '',
              ru: namesRaw['ru'] as String? ?? '',
            )
          : const LocalizedText(en: '', es: '', pt: '', ru: '');

      final meaningsRaw = data['meanings'] as Map<String, dynamic>?;
      final meanings = meaningsRaw != null
          ? TarotMeanings(
              upright: _parseLocalizedText(meaningsRaw['upright']),
              reversed: _parseLocalizedText(meaningsRaw['reversed']),
              love: _parseLocalizedText(meaningsRaw['love']),
              work: _parseLocalizedText(meaningsRaw['work']),
              health: _parseLocalizedText(meaningsRaw['health']),
            )
          : _emptyMeanings;

      return TarotCard(
        id: id,
        number: number,
        arcana: arcana,
        suit: suit,
        names: names,
        imageUrl: imageUrl,
        imageLicense: imageLicense,
        imageSource: imageSource,
        meanings: meanings,
        version: version,
      );
    } catch (_) {
      return null;
    }
  }

  static LocalizedText _parseLocalizedText(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return LocalizedText(
        en: raw['en'] as String? ?? '',
        es: raw['es'] as String? ?? '',
        pt: raw['pt'] as String? ?? '',
        ru: raw['ru'] as String? ?? '',
      );
    }
    final text = raw as String? ?? '';
    return LocalizedText(en: text, es: text, pt: text, ru: text);
  }

  static TarotSuit _parseSuit(String? raw) => switch (raw) {
    'cups' => TarotSuit.cups,
    'wands' => TarotSuit.wands,
    'swords' => TarotSuit.swords,
    'pentacles' => TarotSuit.pentacles,
    _ => TarotSuit.none,
  };

  static const _emptyMeanings = TarotMeanings(
    upright: LocalizedText(en: '', es: '', pt: '', ru: ''),
    reversed: LocalizedText(en: '', es: '', pt: '', ru: ''),
    love: LocalizedText(en: '', es: '', pt: '', ru: ''),
    work: LocalizedText(en: '', es: '', pt: '', ru: ''),
    health: LocalizedText(en: '', es: '', pt: '', ru: ''),
  );
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// Returns null when Firebase is not initialized (offline mode).
final tarotRemoteDatasourceProvider =
    Provider<TarotRemoteDatasource?>((ref) {
  try {
    return TarotRemoteDatasource(FirebaseFirestore.instance);
  } catch (_) {
    return null;
  }
});
