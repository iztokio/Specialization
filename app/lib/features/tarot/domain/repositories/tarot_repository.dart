import '../entities/tarot_card.dart';

/// Contract for Tarot card data access.
///
/// Two data types:
/// 1. Card metadata (78 cards) — static content, cached from Firestore once
/// 2. Daily draw / spread — deterministic per user+date, cached locally
///
/// FREE features:
/// - Daily card (1 card, deterministic)
/// - Card basic meaning
///
/// PREMIUM features:
/// - 3-Card Spread (Past/Present/Future)
/// - Card Library (all 78 cards with full detail)
abstract interface class TarotRepository {
  /// Get a single card by index (0-77).
  Future<TarotCard?> getCardByIndex(int index);

  /// Get all 78 cards (for Card Library — premium).
  Future<List<TarotCard>> getAllCards();

  /// Get today's deterministic daily card for the user.
  /// Returns the same card all day regardless of restarts.
  Future<TarotCard> getDailyCard({
    required String userId,
    required String zodiacSign,
    required DateTime date,
  });

  /// Get a 3-card spread (premium feature).
  /// Deterministic: same 3 cards all day for this user.
  /// Throws [PremiumRequiredException] if user is not premium.
  Future<List<TarotCard>> getThreeCardSpread({
    required String userId,
    required String zodiacSign,
    required DateTime date,
  });

  /// Search cards by keyword (name, keywords, suit).
  Future<List<TarotCard>> searchCards(String query);

  /// Prefetch and cache all 78 card metadata records.
  /// Called once on first launch (or when content version changes).
  Future<void> prefetchCardLibrary();
}
