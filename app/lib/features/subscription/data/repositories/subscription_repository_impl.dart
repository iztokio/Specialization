import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/subscription_status.dart';
import '../../domain/repositories/subscription_repository.dart';

/// Offline-first implementation of [SubscriptionRepository].
///
/// SECURITY: This class reads subscription status from local cache.
/// The cache is populated ONLY from Firestore (written by Cloud Functions).
/// The client NEVER writes subscription status directly.
///
/// Stage 2: Local cache only, always returns free status if no cache.
/// Stage 3: Firestore stream listener added, real-time subscription updates.
/// Stage 4: Google Play Billing integration.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<SubscriptionStatus> getStatus(String userId) async {
    final cached = await _db.getCachedSubscription(userId);

    if (cached == null) return SubscriptionStatus.free(userId);

    // If cache has expired, return current value but schedule background refresh
    if (DateTime.now().isAfter(cached.cacheValidUntil)) {
      // TODO(stage3): Trigger background Firestore refresh
      // Don't block UI — return stale cache while refreshing
    }

    return _rowToEntity(cached);
  }

  @override
  Stream<SubscriptionStatus> watchStatus(String userId) {
    return (_db.select(_db.subscriptionCacheTable)
      ..where((t) => t.userId.equals(userId)))
        .watchSingleOrNull()
        .map((row) => row != null ? _rowToEntity(row) : SubscriptionStatus.free(userId));
  }

  @override
  Future<SubscriptionStatus> refresh(String userId) {
    // TODO(stage3): Fetch from Firestore and update local cache
    // For now, return current cached value
    return getStatus(userId);
  }

  @override
  Future<SubscriptionStatus> purchase({
    required String userId,
    required String productId,
  }) async {
    // TODO(stage4): Implement Google Play Billing flow
    // 1. Launch Google Play purchase dialog
    // 2. On success, call Cloud Function verifyPurchase
    // 3. Cloud Function writes to Firestore
    // 4. Listen to Firestore update → refresh local cache
    // 5. Return updated status
    throw UnimplementedError('Purchase flow implemented in Stage 4');
  }

  @override
  Future<SubscriptionStatus> restore(String userId) async {
    // TODO(stage4): Call Cloud Function restorePurchases
    throw UnimplementedError('Restore purchases implemented in Stage 4');
  }

  // ─── Mapping ───────────────────────────────────────────────────────────

  SubscriptionStatus _rowToEntity(SubscriptionCacheTableData row) {
    return SubscriptionStatus(
      uid: row.userId,
      state: _parseState(row.state),
      productId: row.productId,
      expiryDate: row.expiresAt,
      lastVerifiedAt: row.lastSyncedAt,
    );
  }

  SubscriptionState _parseState(String raw) {
    return switch (raw) {
      'active' => SubscriptionState.active,
      'cancelled' => SubscriptionState.cancelled,
      'expired' => SubscriptionState.expired,
      'grace_period' => SubscriptionState.gracePeriod,
      'on_hold' => SubscriptionState.onHold,
      'refunded' => SubscriptionState.refunded,
      'free' => SubscriptionState.free,
      _ => SubscriptionState.unknown, // Fail-safe: deny premium for unknown
    };
  }
}
