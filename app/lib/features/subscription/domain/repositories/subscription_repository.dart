import '../entities/subscription_status.dart';

/// Contract for subscription state management.
///
/// SECURITY CRITICAL:
/// - Premium access is determined server-side via Firestore + Cloud Functions
/// - Local cache is a convenience layer only — always verify with server
/// - Client code NEVER writes subscriptionStatus directly to Firestore
/// - Firestore Security Rules enforce server-only writes on subscription fields
///
/// Flow:
///   Purchase → Google Play Dialog → verifyPurchase Cloud Function
///   → Firestore update → subscriptionRepository.refresh() → UI update
abstract interface class SubscriptionRepository {
  /// Get current subscription status (from cache, refreshed in background).
  ///
  /// Returns immediately with cached value.
  /// Triggers background server verification if cache is stale.
  Future<SubscriptionStatus> getStatus(String userId);

  /// Watch subscription status changes (reactive stream for UI).
  /// Emits a new value whenever status changes (purchase, expiry, etc.)
  Stream<SubscriptionStatus> watchStatus(String userId);

  /// Force-refresh subscription status from Firestore.
  /// Called after purchase, restore, or on app foreground.
  Future<SubscriptionStatus> refresh(String userId);

  /// Initiate a purchase flow for the given product ID.
  /// Returns the updated status after server verification.
  ///
  /// IMPORTANT: Does NOT write to Firestore directly.
  /// Calls Google Play Billing → server verifyPurchase → reads back status.
  Future<SubscriptionStatus> purchase({
    required String userId,
    required String productId,
  });

  /// Restore previous purchases (for device change / reinstall).
  /// Calls Cloud Function restorePurchases → updates local cache.
  Future<SubscriptionStatus> restore(String userId);
}
