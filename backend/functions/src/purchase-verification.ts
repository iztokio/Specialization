/**
 * Purchase Verification Cloud Functions
 *
 * SECURITY CRITICAL:
 * All subscription state changes MUST go through these functions.
 * Client code can NEVER set subscriptionStatus directly.
 *
 * ENTERTAINMENT DISCLAIMER:
 * This app is for entertainment purposes only.
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { google } from 'googleapis';
import { CallableRequest } from 'firebase-functions/v2/https';

// Initialize admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ============================================================
// TYPES
// ============================================================

interface PurchaseVerificationRequest {
  productId: string;
  purchaseToken: string;
  packageName?: string;
}

interface SubscriptionStateUpdate {
  state: SubscriptionState;
  productId: string;
  expiryDate?: Date;
  graceExpiryDate?: Date;
  isTrialPeriod?: boolean;
  lastVerifiedAt: Date;
}

type SubscriptionState =
  | 'active'
  | 'free'
  | 'cancelled'
  | 'grace_period'
  | 'on_hold'
  | 'expired'
  | 'refunded'
  | 'unknown';

// ============================================================
// GOOGLE PLAY API CLIENT
// ============================================================

async function getAndroidPublisherClient() {
  const auth = new google.auth.GoogleAuth({
    // Uses service account credentials from Firebase environment
    // Configure via: firebase functions:config:set
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return google.androidpublisher({ version: 'v3', auth });
}

// ============================================================
// VERIFY PURCHASE (Callable Function)
// ============================================================

/**
 * Called by client after a successful Google Play purchase.
 * Verifies the purchase token with Google Play API and
 * updates subscription status in Firestore.
 *
 * SECURITY: Only authenticated users can call this function.
 * The UID from the auth token is used, not client-provided UID.
 */
export const verifyPurchase = functions.https.onCall(
  async (request: CallableRequest<PurchaseVerificationRequest>) => {
    // 1. Verify authentication
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to verify purchases'
      );
    }

    const uid = request.auth.uid;
    const { productId, purchaseToken } = request.data;
    const packageName = request.data.packageName ?? functions.config().app?.package_name ?? 'com.mystictarot.app';

    // 2. Validate inputs
    if (!productId || !purchaseToken) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'productId and purchaseToken are required'
      );
    }

    // 3. Check allowed product IDs (prevent injection)
    const allowedProducts = ['premium_monthly_v1', 'premium_yearly_v1'];
    if (!allowedProducts.includes(productId)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid product ID'
      );
    }

    try {
      // 4. Verify with Google Play API
      const androidpublisher = await getAndroidPublisherClient();

      const response = await androidpublisher.purchases.subscriptions.get({
        packageName,
        subscriptionId: productId,
        token: purchaseToken,
      });

      const subscription = response.data;

      // 5. Determine subscription state
      const stateUpdate = parseSubscriptionState(subscription, productId);

      // 6. Update Firestore (server-side only, with admin privileges)
      await db.doc(`users/${uid}`).set(
        {
          subscriptionStatus: stateUpdate.state,
          subscriptionProductId: stateUpdate.productId,
          subscriptionExpiryDate: stateUpdate.expiryDate
            ? admin.firestore.Timestamp.fromDate(stateUpdate.expiryDate)
            : null,
          subscriptionGraceExpiryDate: stateUpdate.graceExpiryDate
            ? admin.firestore.Timestamp.fromDate(stateUpdate.graceExpiryDate)
            : null,
          subscriptionIsTrialPeriod: stateUpdate.isTrialPeriod ?? false,
          subscriptionLastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          // Store token server-side only — never return to client
          _purchaseToken: purchaseToken,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // Log for audit
      await logPurchaseEvent(uid, 'purchase_verified', {
        productId,
        state: stateUpdate.state,
        // Never log the actual purchase token
      });

      // 7. Return only the safe state (no sensitive data)
      return {
        success: true,
        state: stateUpdate.state,
        hasPremiumAccess: hasPremiumAccess(stateUpdate.state),
        expiryDate: stateUpdate.expiryDate?.toISOString(),
      };
    } catch (error) {
      // Log the error (without sensitive data)
      functions.logger.error('Purchase verification failed', {
        uid,
        productId,
        error: error instanceof Error ? error.message : 'Unknown error',
      });

      throw new functions.https.HttpsError(
        'internal',
        'Failed to verify purchase. Please try again.'
      );
    }
  }
);

// ============================================================
// REAL-TIME DEVELOPER NOTIFICATIONS (Pub/Sub)
// ============================================================

/**
 * Handles Google Play Real-Time Developer Notifications (RTDN).
 * These are pushed by Google when subscription state changes
 * (renewal, cancellation, payment failure, etc.)
 *
 * Setup: Configure Play Console → Monetization setup → Real-time developer notifications
 * Topic: projects/{project_id}/topics/play-rtdn
 */
export const handlePlayRTDN = functions.pubsub
  .topic('play-rtdn')
  .onPublish(async (message) => {
    try {
      const data = JSON.parse(
        Buffer.from(message.data, 'base64').toString()
      );

      functions.logger.info('RTDN received', {
        notificationType: data.subscriptionNotification?.notificationType,
      });

      if (!data.subscriptionNotification) {
        functions.logger.info('Non-subscription notification, skipping');
        return;
      }

      const { subscriptionId, purchaseToken, notificationType } =
        data.subscriptionNotification;

      // Find user by purchase token
      const userQuery = await db
        .collection('users')
        .where('_purchaseToken', '==', purchaseToken)
        .limit(1)
        .get();

      if (userQuery.empty) {
        functions.logger.warn('No user found for purchase token');
        return;
      }

      const userDoc = userQuery.docs[0];
      const uid = userDoc.id;

      // Re-verify with Google Play API to get current state
      const androidpublisher = await getAndroidPublisherClient();
      const response = await androidpublisher.purchases.subscriptions.get({
        packageName: functions.config().app?.package_name ?? 'com.mystictarot.app',
        subscriptionId,
        token: purchaseToken,
      });

      const stateUpdate = parseSubscriptionState(response.data, subscriptionId);

      // Update user's subscription status
      await db.doc(`users/${uid}`).update({
        subscriptionStatus: stateUpdate.state,
        subscriptionExpiryDate: stateUpdate.expiryDate
          ? admin.firestore.Timestamp.fromDate(stateUpdate.expiryDate)
          : null,
        subscriptionGraceExpiryDate: stateUpdate.graceExpiryDate
          ? admin.firestore.Timestamp.fromDate(stateUpdate.graceExpiryDate)
          : null,
        subscriptionLastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await logPurchaseEvent(uid, 'rtdn_processed', {
        notificationType,
        subscriptionId,
        newState: stateUpdate.state,
      });
    } catch (error) {
      functions.logger.error('RTDN processing failed', { error });
      throw error; // Rethrow to trigger Pub/Sub retry
    }
  });

// ============================================================
// RESTORE PURCHASES (Callable)
// ============================================================

export const restorePurchases = functions.https.onCall(
  async (request: CallableRequest<{ purchaseToken: string; productId: string }>) => {
    if (!request.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required'
      );
    }

    const uid = request.auth.uid;
    const { purchaseToken, productId } = request.data;

    // Re-verify the purchase
    try {
      const androidpublisher = await getAndroidPublisherClient();
      const response = await androidpublisher.purchases.subscriptions.get({
        packageName: functions.config().app?.package_name ?? 'com.mystictarot.app',
        subscriptionId: productId,
        token: purchaseToken,
      });

      const stateUpdate = parseSubscriptionState(response.data, productId);

      await db.doc(`users/${uid}`).set(
        {
          subscriptionStatus: stateUpdate.state,
          subscriptionProductId: stateUpdate.productId,
          subscriptionExpiryDate: stateUpdate.expiryDate
            ? admin.firestore.Timestamp.fromDate(stateUpdate.expiryDate)
            : null,
          subscriptionLastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          _purchaseToken: purchaseToken,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await logPurchaseEvent(uid, 'purchase_restored', {
        productId,
        state: stateUpdate.state,
      });

      return {
        success: true,
        state: stateUpdate.state,
        hasPremiumAccess: hasPremiumAccess(stateUpdate.state),
      };
    } catch (error) {
      throw new functions.https.HttpsError(
        'internal',
        'Failed to restore purchases'
      );
    }
  }
);

// ============================================================
// HELPER FUNCTIONS
// ============================================================

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function parseSubscriptionState(subscription: any, productId: string): SubscriptionStateUpdate {
  const now = Date.now();

  // Payment state: 0=pending, 1=received, 2=free trial, 3=pending deferred upgrade/downgrade
  const paymentState = subscription.paymentState;
  // Cancel reason: 0=cancelled by user, 1=billing error, 2=replaced, 3=developer cancelled
  const cancelReason = subscription.cancelReason;
  const expiryTimeMs = parseInt(subscription.expiryTimeMillis ?? '0');
  const isTrialPeriod = subscription.paymentState === 2;

  let state: SubscriptionState;

  if (subscription.cancelSurveyResult && cancelReason === 0) {
    // User cancelled
    if (expiryTimeMs > now) {
      state = 'cancelled'; // Still in paid period
    } else {
      state = 'expired';
    }
  } else if (paymentState === 0) {
    // Pending payment
    state = 'grace_period';
  } else if (subscription.userCancellationTimeMillis) {
    state = expiryTimeMs > now ? 'cancelled' : 'expired';
  } else if (paymentState === 1 || paymentState === 2) {
    // Active or free trial
    state = expiryTimeMs > now ? 'active' : 'expired';
  } else {
    state = 'unknown';
  }

  // Check for on_hold (linkedPurchaseToken without active subscription = on hold)
  if (subscription.paymentState === 0 && expiryTimeMs < now) {
    state = 'on_hold';
  }

  return {
    state,
    productId,
    expiryDate: expiryTimeMs ? new Date(expiryTimeMs) : undefined,
    isTrialPeriod,
    lastVerifiedAt: new Date(),
  };
}

function hasPremiumAccess(state: SubscriptionState): boolean {
  return ['active', 'cancelled', 'grace_period'].includes(state);
}

async function logPurchaseEvent(
  uid: string,
  eventType: string,
  data: Record<string, unknown>
): Promise<void> {
  // Audit log — never log purchase tokens or PII
  await db.collection('audit_logs').add({
    uid,
    eventType,
    data,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}
