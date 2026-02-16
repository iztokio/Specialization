import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';

import 'package:mystic_tarot/core/database/app_database.dart';
import 'package:mystic_tarot/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:mystic_tarot/features/subscription/domain/entities/subscription_status.dart';

/// Tests for SubscriptionRepository — security-critical behavior.
/// Verifies fail-safe patterns: unknown/missing state = no premium.
void main() {
  late AppDatabase db;
  late SubscriptionRepositoryImpl repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SubscriptionRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SubscriptionRepository — Default state (security)', () {
    test('getStatus returns free when no cache exists', () async {
      final status = await repo.getStatus('new_user');
      expect(status.state, SubscriptionState.free);
      expect(status.hasPremiumAccess, false);
    });

    test('watchStatus emits free status for new user', () async {
      final stream = repo.watchStatus('new_user');
      final status = await stream.first;
      expect(status.state, SubscriptionState.free);
      expect(status.hasPremiumAccess, false);
    });
  });

  group('SubscriptionRepository — Cache reads', () {
    Future<void> insertCache(String userId, String state) async {
      final now = DateTime.now();
      await db.upsertSubscriptionCache(
        SubscriptionCacheTableCompanion.insert(
          userId: userId,
          state: Value(state),
          lastSyncedAt: now,
          cacheValidUntil: now.add(const Duration(hours: 6)),
        ),
      );
    }

    test('active state grants premium access', () async {
      await insertCache('user1', 'active');
      final status = await repo.getStatus('user1');
      expect(status.state, SubscriptionState.active);
      expect(status.hasPremiumAccess, true);
    });

    test('grace_period state grants premium access', () async {
      await insertCache('user1', 'grace_period');
      final status = await repo.getStatus('user1');
      expect(status.state, SubscriptionState.gracePeriod);
      expect(status.hasPremiumAccess, true);
    });

    test('cancelled state grants premium access (still in paid period)', () async {
      await insertCache('user1', 'cancelled');
      final status = await repo.getStatus('user1');
      expect(status.state, SubscriptionState.cancelled);
      expect(status.hasPremiumAccess, true);
    });

    test('expired state denies premium access', () async {
      await insertCache('user1', 'expired');
      final status = await repo.getStatus('user1');
      expect(status.state, SubscriptionState.expired);
      expect(status.hasPremiumAccess, false);
    });

    test('on_hold state denies premium access', () async {
      await insertCache('user1', 'on_hold');
      final status = await repo.getStatus('user1');
      expect(status.state, SubscriptionState.onHold);
      expect(status.hasPremiumAccess, false);
    });

    test('refunded state denies premium access immediately', () async {
      await insertCache('user1', 'refunded');
      final status = await repo.getStatus('user1');
      expect(status.state, SubscriptionState.refunded);
      expect(status.hasPremiumAccess, false);
    });

    test('unknown state denies premium access (fail-safe)', () async {
      await insertCache('user1', 'unknown');
      final status = await repo.getStatus('user1');
      expect(status.state, SubscriptionState.unknown);
      expect(status.hasPremiumAccess, false);
    });

    test('unrecognized state string maps to unknown (fail-safe)', () async {
      await insertCache('user1', 'some_future_state_not_in_enum');
      final status = await repo.getStatus('user1');
      expect(status.hasPremiumAccess, false); // Fail-safe: deny
    });
  });

  group('SubscriptionRepository — Stream reactivity', () {
    test('watchStatus emits update when cache is upserted', () async {
      final stream = repo.watchStatus('stream_user');

      // Schedule cache insert after stream starts
      Future.delayed(const Duration(milliseconds: 50), () async {
        final now = DateTime.now();
        await db.upsertSubscriptionCache(
          SubscriptionCacheTableCompanion.insert(
            userId: 'stream_user',
            state: const Value('active'),
            lastSyncedAt: now,
            cacheValidUntil: now.add(const Duration(hours: 6)),
          ),
        );
      });

      // Collect first 2 emissions
      final emissions = await stream.take(2).toList();

      // First emission: free (no cache)
      expect(emissions[0].state, SubscriptionState.free);
      // Second emission: active (after cache insert)
      expect(emissions[1].state, SubscriptionState.active);
      expect(emissions[1].hasPremiumAccess, true);
    });
  });

  group('SubscriptionRepository — Unimplemented Stage 4 methods', () {
    test('purchase throws UnimplementedError (Stage 4)', () {
      expect(
        () => repo.purchase(userId: 'u1', productId: 'premium_yearly_v1'),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('restore throws UnimplementedError (Stage 4)', () {
      expect(
        () => repo.restore('u1'),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
