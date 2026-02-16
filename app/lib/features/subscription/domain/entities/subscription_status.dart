import 'package:equatable/equatable.dart';

/// Subscription status entity.
///
/// CRITICAL SECURITY NOTE:
/// This status MUST only be set by server-side Cloud Functions
/// after verifying with the Google Play API.
/// NEVER trust a client-side subscription flag.

enum SubscriptionState {
  /// Active, paid subscription
  active,

  /// Free tier (no subscription ever or cancelled)
  free,

  /// Subscription cancelled but still in paid period
  cancelled,

  /// Payment failed, grace period active (show premium, prompt to fix payment)
  gracePeriod,

  /// Grace period ended, payment still failed (revoke premium)
  onHold,

  /// Subscription expired
  expired,

  /// Refund processed (revoke premium immediately)
  refunded,

  /// Unknown (treat as free to be safe)
  unknown,
}

extension SubscriptionStateExtension on SubscriptionState {
  /// Should the user see premium content?
  bool get hasPremiumAccess => switch (this) {
    SubscriptionState.active => true,
    SubscriptionState.cancelled => true, // Still in paid period
    SubscriptionState.gracePeriod => true, // Give benefit of doubt
    SubscriptionState.free => false,
    SubscriptionState.onHold => false,
    SubscriptionState.expired => false,
    SubscriptionState.refunded => false,
    SubscriptionState.unknown => false, // Fail-safe: deny premium
  };

  /// Should we show a "fix payment" warning?
  bool get hasPaymentIssue => this == SubscriptionState.gracePeriod ||
      this == SubscriptionState.onHold;

  /// Should we show a "subscription expired" notice?
  bool get isExpiredOrRevoked => this == SubscriptionState.expired ||
      this == SubscriptionState.refunded ||
      this == SubscriptionState.onHold;
}

class SubscriptionStatus extends Equatable {
  const SubscriptionStatus({
    required this.uid,
    required this.state,
    this.productId,
    this.purchaseToken,
    this.expiryDate,
    this.graceExpiryDate,
    this.lastVerifiedAt,
    this.isTrialPeriod = false,
  });

  final String uid;
  final SubscriptionState state;
  final String? productId; // 'premium_monthly_v1' | 'premium_yearly_v1'
  final String? purchaseToken; // Stored server-side, not exposed to client
  final DateTime? expiryDate;
  final DateTime? graceExpiryDate;
  final DateTime? lastVerifiedAt;
  final bool isTrialPeriod;

  bool get hasPremiumAccess => state.hasPremiumAccess;
  bool get hasPaymentIssue => state.hasPaymentIssue;

  /// Free tier baseline
  factory SubscriptionStatus.free(String uid) => SubscriptionStatus(
        uid: uid,
        state: SubscriptionState.free,
      );

  SubscriptionStatus copyWith({
    String? uid,
    SubscriptionState? state,
    String? productId,
    String? purchaseToken,
    DateTime? expiryDate,
    DateTime? graceExpiryDate,
    DateTime? lastVerifiedAt,
    bool? isTrialPeriod,
  }) {
    return SubscriptionStatus(
      uid: uid ?? this.uid,
      state: state ?? this.state,
      productId: productId ?? this.productId,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      expiryDate: expiryDate ?? this.expiryDate,
      graceExpiryDate: graceExpiryDate ?? this.graceExpiryDate,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      isTrialPeriod: isTrialPeriod ?? this.isTrialPeriod,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        state,
        productId,
        expiryDate,
        graceExpiryDate,
        isTrialPeriod,
      ];
}
