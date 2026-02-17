import 'package:flutter_test/flutter_test.dart';
import 'package:mystic_tarot/features/today/domain/entities/daily_reading.dart';

void main() {
  group('DailyReading — Deterministic seed', () {
    test('Same date + sign always produces same seed', () {
      final date = DateTime(2026, 2, 16);
      const sign = 'aries';

      final seed1 = DailyReading.generateSeed(date, sign);
      final seed2 = DailyReading.generateSeed(date, sign);
      final seed3 = DailyReading.generateSeed(date, sign);

      expect(seed1, equals(seed2));
      expect(seed2, equals(seed3));
    });

    test('Different dates produce different seeds', () {
      const sign = 'aries';
      final date1 = DateTime(2026, 2, 16);
      final date2 = DateTime(2026, 2, 17);

      final seed1 = DailyReading.generateSeed(date1, sign);
      final seed2 = DailyReading.generateSeed(date2, sign);

      expect(seed1, isNot(equals(seed2)));
    });

    test('Different signs produce different seeds for same date', () {
      final date = DateTime(2026, 2, 16);

      final seedAries = DailyReading.generateSeed(date, 'aries');
      final seedTaurus = DailyReading.generateSeed(date, 'taurus');

      expect(seedAries, isNot(equals(seedTaurus)));
    });

    test('Seed is always positive (non-negative)', () {
      final testDates = [
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 15),
        DateTime(2026, 12, 31),
        DateTime(2025, 2, 14),
      ];
      const signs = ['aries', 'scorpio', 'pisces', 'capricorn'];

      for (final date in testDates) {
        for (final sign in signs) {
          final seed = DailyReading.generateSeed(date, sign);
          expect(seed, greaterThanOrEqualTo(0),
              reason: 'Seed must be non-negative for $date/$sign');
        }
      }
    });
  });

  group('DailyReading — Card selection', () {
    test('Selects correct number of cards', () {
      const seed = 12345;
      final cards = DailyReading.selectCardIndices(
        seed: seed,
        count: 3,
        totalCards: 78,
      );
      expect(cards.length, 3);
    });

    test('Selected cards are in valid range', () {
      const seed = 99999;
      final cards = DailyReading.selectCardIndices(
        seed: seed,
        count: 3,
        totalCards: 78,
      );
      for (final card in cards) {
        expect(card, greaterThanOrEqualTo(0));
        expect(card, lessThan(78));
      }
    });

    test('No duplicate cards in selection', () {
      const seed = 54321;
      final cards = DailyReading.selectCardIndices(
        seed: seed,
        count: 5,
        totalCards: 78,
      );
      expect(cards.toSet().length, cards.length,
          reason: 'No duplicate cards should be drawn');
    });

    test('Selection is deterministic', () {
      const seed = 777;
      final selection1 = DailyReading.selectCardIndices(
        seed: seed,
        count: 3,
        totalCards: 78,
      );
      final selection2 = DailyReading.selectCardIndices(
        seed: seed,
        count: 3,
        totalCards: 78,
      );
      expect(selection1, equals(selection2));
    });

    test('Excludes specified card indices', () {
      const seed = 42;
      final exclude = [0, 1, 2, 3, 4];
      final cards = DailyReading.selectCardIndices(
        seed: seed,
        count: 3,
        totalCards: 78,
        excludeIndices: exclude,
      );
      for (final card in cards) {
        expect(exclude.contains(card), isFalse,
            reason: 'Excluded cards should not be drawn');
      }
    });

    test('Falls back to full deck when exclusions prevent selection', () {
      const seed = 100;
      // Exclude 76 of 78 cards, request 3
      final exclude = List.generate(76, (i) => i);
      final cards = DailyReading.selectCardIndices(
        seed: seed,
        count: 3,
        totalCards: 78,
        excludeIndices: exclude,
      );
      // Should still return 3 cards from full deck
      expect(cards.length, 3);
    });
  });

  group('DailyReading — ID generation', () {
    test('makeId format is correct', () {
      const uid = 'user123';
      final date = DateTime(2026, 2, 16);
      final id = DailyReading.makeId(uid, date);
      expect(id, 'user123_2026-02-16');
    });

    test('makeId pads month and day correctly', () {
      const uid = 'user456';
      final date = DateTime(2026, 1, 5);
      final id = DailyReading.makeId(uid, date);
      expect(id, 'user456_2026-01-05');
    });
  });
}
