import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/subscription_status.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_datasource.dart';

/// Offline-first implementation of [SubscriptionRepository].
///
/// SECURITY: This class reads subscription status from local cache only.
/// The cache is populated from Firestore (written exclusively by Cloud Functions).
/// The client NEVER writes subscription status directly — enforced by Firestore Rules.
///
/// Cache strategy: Firestore stream populates local Drift cache in background.
/// On cold start, returns local cache immediately while stream reconnects.
///
/// Stage 2: Local cache only, returns free status if no cache.
/// Stage 3: Firestore stream → local cache sync (this implementation).
/// Stage 4: Google Play Billing integration.
class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._db, {this.remote});

  final AppDatabase _db;

  /// Remote datasource. Null in offline mode (no Firebase).
  final SubscriptionRemoteDatasource? remote;

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
    // Start background Firestore → cache sync.
    _startRemoteSync(userId);

    // Return local cache stream (instant, works offline).
    return (_db.select(_db.subscriptionCacheTable)
      ..where((t) => t.userId.equals(userId)))
        .watchSingleOrNull()
        .map((row) => row != null ? _rowToEntity(row) : SubscriptionStatus.free(userId));
  }

  /// Syncs Firestore subscription document to local Drift cache.
  /// Called once per stream subscription; idempotent if called multiple times.
  void _startRemoteSync(String userId) {
    final datasource = remote;
    if (datasource == null) return; // Offline mode — skip

    datasource.watchStatus(userId).listen(
      (data) async {
        if (data == null) return; // No Firestore doc → user is on free tier
        final now = DateTime.now();
        await _db.into(_db.subscriptionCacheTable).insertOnConflictUpdate(
          SubscriptionCacheTableCompanion.insert(
            userId: userId,
            state: Value(data['subscriptionState'] as String? ?? 'free'),
            productId: Value(data['productId'] as String?),
            expiresAt: Value(
              data['expiresAt'] != null
                  ? (data['expiresAt'] as dynamic).toDate() as DateTime
                  : null,
            ),
            lastSyncedAt: now,
            cacheValidUntil: now.add(const Duration(hours: 24)),
          ),
        );
      },
      onError: (_) {
        // Firestore unavailable — local cache remains valid
      },
    );
  }

  @override
  Future<SubscriptionStatus> refresh(String userId) async {
    final data = await remote?.fetchStatus(userId);
    if (data == null) return getStatus(userId);

    final now = DateTime.now();
    await _db.into(_db.subscriptionCacheTable).insertOnConflictUpdate(
      SubscriptionCacheTableCompanion.insert(
        userId: userId,
        state: Value(data['subscriptionState'] as String? ?? 'free'),
        productId: Value(data['productId'] as String?),
        expiresAt: Value(
          data['expiresAt'] != null
              ? (data['expiresAt'] as dynamic).toDate() as DateTime
              : null,
        ),
        lastSyncedAt: now,
        cacheValidUntil: now.add(const Duration(hours: 24)),
      ),
    );
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
