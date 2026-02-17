import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firestore remote datasource for daily horoscope readings.
///
/// Firestore schema:
///   users/{uid}/readings/{YYYY-MM-DD}_{zodiacSign}
///   {
///     "zodiacSign": "aries",
///     "readingDate": Timestamp,
///     "generalText": "...",
///     "loveText": "...",
///     "workText": "...",
///     "wellbeingText": "...",
///     "cardIndex": 14,
///     "isReversed": false,
///     "cardName": "The Star",
///     "cardMeaning": "...",
///     "contentVersion": "1.0.0",
///     "language": "en",
///     "isPremium": false,
///     "seed": 1234567890,
///     "createdAt": Timestamp
///   }
///
/// Content is generated server-side by Cloud Functions and populated
/// in batch daily. Clients read only. Writes via Cloud Functions only.
class HoroscopeRemoteDatasource {
  HoroscopeRemoteDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Fetches a daily reading from Firestore.
  ///
  /// Returns null when offline or reading not yet generated server-side.
  /// Document ID format: `YYYY-MM-DD_zodiacSign`
  Future<Map<String, dynamic>?> fetchReading({
    required String userId,
    required DateTime date,
    required String zodiacSign,
  }) async {
    final docId = _makeDocId(date, zodiacSign);
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .doc(docId)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!snap.exists) return null;
      return snap.data();
    } on FirebaseException catch (e) {
      // Offline or permission error — caller falls back to local cache
      if (e.code == 'unavailable' || e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  /// Fetches multiple readings in batch (for history screen).
  ///
  /// Uses whereField + limit for pagination.
  /// Returns results ordered by readingDate descending.
  Future<List<Map<String, dynamic>>> fetchReadingHistory({
    required String userId,
    required String zodiacSign,
    required int days,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('zodiacSign', isEqualTo: zodiacSign)
          .where('readingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .orderBy('readingDate', descending: true)
          .limit(days)
          .get(const GetOptions(source: Source.serverAndCache));

      return snap.docs.map((d) => d.data()).toList();
    } on FirebaseException {
      return [];
    }
  }

  /// Logs that a reading was viewed (for analytics/personalization).
  /// Fire-and-forget — never blocks UI.
  Future<void> markReadingViewed({
    required String userId,
    required DateTime date,
    required String zodiacSign,
  }) async {
    final docId = _makeDocId(date, zodiacSign);
    _firestore
        .collection('users')
        .doc(userId)
        .collection('readings')
        .doc(docId)
        .set({'lastViewedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))
        .ignore(); // intentionally fire-and-forget
  }

  static String _makeDocId(DateTime date, String zodiacSign) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d\_$zodiacSign';
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// Returns null when Firebase is not initialized (offline mode).
final horoscopeRemoteDatasourceProvider =
    Provider<HoroscopeRemoteDatasource?>((ref) {
  try {
    return HoroscopeRemoteDatasource(FirebaseFirestore.instance);
  } catch (_) {
    return null; // Firebase not initialized — offline mode
  }
});
