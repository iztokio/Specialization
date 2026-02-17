import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firestore remote datasource for subscription status.
///
/// SECURITY MODEL:
/// - This datasource is READ-ONLY from the client perspective
/// - Subscription documents are written exclusively by Cloud Functions:
///     functions/src/subscriptions/processPurchase.ts
///     functions/src/subscriptions/validateReceipt.ts
/// - Firestore Security Rules enforce: client cannot write subscriptionStatus
///   (see backend/firestore.rules)
///
/// Firestore schema:
///   users/{uid}/subscription/status
///   {
///     "subscriptionState": "active" | "expired" | "cancelled" | "free",
///     "productId": "astralume_premium_monthly" | "astralume_premium_annual",
///     "purchaseToken": "...",         // Android
///     "originalTransactionId": "...", // iOS
///     "expiresAt": Timestamp,
///     "purchasedAt": Timestamp,
///     "updatedAt": Timestamp (serverTimestamp)
///   }
class SubscriptionRemoteDatasource {
  SubscriptionRemoteDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Real-time subscription status stream.
  ///
  /// Emits null when document doesn't exist (→ free tier).
  /// Uses Firestore onSnapshot for instant push updates after purchase.
  Stream<Map<String, dynamic>?> watchStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subscription')
        .doc('status')
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }

  /// One-time fetch of subscription status (for cold start / offline check).
  Future<Map<String, dynamic>?> fetchStatus(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscription')
          .doc('status')
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.exists ? snap.data() : null;
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'permission-denied') {
        return null; // Fail-safe: treat as free
      }
      rethrow;
    }
  }

  /// Writes purchase acknowledgment to Firestore for Cloud Function processing.
  ///
  /// NOTE: This writes to `users/{uid}/pendingPurchases/{purchaseId}`,
  /// NOT to the subscription/status document.
  /// Cloud Functions validate the receipt and update subscription/status.
  ///
  /// This does NOT grant premium access — Cloud Functions are the authority.
  Future<void> submitPurchaseForValidation({
    required String userId,
    required String purchaseId,
    required String productId,
    required String purchaseToken, // Android: purchaseToken, iOS: transactionId
    required String platform, // 'android' | 'ios'
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('pendingPurchases')
        .doc(purchaseId)
        .set({
      'productId': productId,
      'purchaseToken': purchaseToken,
      'platform': platform,
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending_validation',
    });
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// Returns null when Firebase is not initialized (offline mode).
final subscriptionRemoteDatasourceProvider =
    Provider<SubscriptionRemoteDatasource?>((ref) {
  try {
    return SubscriptionRemoteDatasource(FirebaseFirestore.instance);
  } catch (_) {
    return null; // Firebase not initialized — offline mode
  }
});
