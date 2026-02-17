import 'package:flutter_test/flutter_test.dart';
import 'package:mystic_tarot/features/subscription/domain/entities/subscription_status.dart';

void main() {
  group('SubscriptionState — Premium access logic', () {
    test('active state has premium access', () {
      expect(SubscriptionState.active.hasPremiumAccess, isTrue);
    });

    test('free state has no premium access', () {
      expect(SubscriptionState.free.hasPremiumAccess, isFalse);
    });

    test('cancelled state has premium access (still in paid period)', () {
      // User cancelled but hasn't reached expiry yet
      expect(SubscriptionState.cancelled.hasPremiumAccess, isTrue);
    });

    test('gracePeriod state has premium access', () {
      // Give benefit of doubt during grace period
      expect(SubscriptionState.gracePeriod.hasPremiumAccess, isTrue);
    });

    test('onHold state has NO premium access', () {
      expect(SubscriptionState.onHold.hasPremiumAccess, isFalse);
    });

    test('expired state has no premium access', () {
      expect(SubscriptionState.expired.hasPremiumAccess, isFalse);
    });

    test('refunded state has no premium access (revoke immediately)', () {
      expect(SubscriptionState.refunded.hasPremiumAccess, isFalse);
    });

    test('unknown state has no premium access (fail-safe)', () {
      // Security: when status is unknown, deny premium
      expect(SubscriptionState.unknown.hasPremiumAccess, isFalse);
    });

    test('gracePeriod shows payment issue', () {
      expect(SubscriptionState.gracePeriod.hasPaymentIssue, isTrue);
    });

    test('onHold shows payment issue', () {
      expect(SubscriptionState.onHold.hasPaymentIssue, isTrue);
    });

    test('active does NOT show payment issue', () {
      expect(SubscriptionState.active.hasPaymentIssue, isFalse);
    });
  });

  group('SubscriptionStatus — Entity', () {
    test('free() factory creates free status', () {
      final status = SubscriptionStatus.free('uid123');
      expect(status.state, SubscriptionState.free);
      expect(status.hasPremiumAccess, isFalse);
      expect(status.uid, 'uid123');
    });

    test('copyWith preserves unchanged fields', () {
      final original = SubscriptionStatus.free('uid456');
      final updated = original.copyWith(
        state: SubscriptionState.active,
        productId: 'premium_monthly_v1',
      );
      expect(updated.uid, 'uid456');
      expect(updated.state, SubscriptionState.active);
      expect(updated.productId, 'premium_monthly_v1');
    });

    test('hasPremiumAccess delegates to state', () {
      final active = SubscriptionStatus(
        uid: 'u1',
        state: SubscriptionState.active,
      );
      expect(active.hasPremiumAccess, isTrue);

      final free = SubscriptionStatus.free('u2');
      expect(free.hasPremiumAccess, isFalse);
    });
  });

  group('Security: fail-safe behavior', () {
    test('All non-active non-premium states deny access (comprehensive)', () {
      const noAccessStates = [
        SubscriptionState.free,
        SubscriptionState.onHold,
        SubscriptionState.expired,
        SubscriptionState.refunded,
        SubscriptionState.unknown,
      ];

      for (final state in noAccessStates) {
        expect(state.hasPremiumAccess, isFalse,
            reason: 'State $state should deny premium access');
      }
    });

    test('All premium-access states are intentionally granted', () {
      const premiumStates = [
        SubscriptionState.active,
        SubscriptionState.cancelled, // still in paid period
        SubscriptionState.gracePeriod, // grace period
      ];

      for (final state in premiumStates) {
        expect(state.hasPremiumAccess, isTrue,
            reason: 'State $state should grant premium access');
      }
    });
  });
}
