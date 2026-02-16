import 'package:drift/drift.dart';

/// Local cache of subscription status.
/// SECURITY: This is a READ-ONLY cache derived from server state.
/// The actual `subscriptionStatus` field in Firestore is ONLY written by
/// server-side Cloud Functions. This local table mirrors the server value.
///
/// The app MUST always verify premium access against this cached value
/// AND periodically refresh from Firestore. Never trust client-side state alone.
class SubscriptionCacheTable extends Table {
  @override
  String get tableName => 'subscription_cache';

  TextColumn get userId => text().withLength(min: 1, max: 128)();

  // Subscription state: 'free', 'active', 'cancelled', 'expired',
  //                     'grace_period', 'on_hold', 'refunded', 'unknown'
  TextColumn get state => text().withDefault(const Constant('free'))();

  // Play Store product ID (e.g. 'premium_yearly_v1')
  TextColumn get productId => text().nullable()();

  // Expiry from server (nullable for free users)
  DateTimeColumn get expiresAt => dateTime().nullable()();

  // When this cache was last synced from Firestore
  DateTimeColumn get lastSyncedAt => dateTime()();

  // How fresh before forcing a re-check (6h for active, 1h for grace/hold)
  DateTimeColumn get cacheValidUntil => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}
