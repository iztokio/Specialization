import 'package:flutter_test/flutter_test.dart';
import 'package:mystic_tarot/core/constants/app_constants.dart';
import 'package:mystic_tarot/features/onboarding/domain/entities/user_profile.dart';

/// Stage 3: Unit tests for UserProfile entity and onboarding logic.
///
/// Tests:
///   1. fromOnboarding factory sets correct zodiac sign
///   2. validateBirthDate rejects future dates
///   3. validateBirthDate rejects age < 13 (COPPA)
///   4. validateBirthDate accepts valid date (age 25)
///   5. validateBirthDate rejects age > 120
///   6. copyWith preserves unchanged fields
///   7. hasCompletedOnboarding defaults to false
///   8. ZodiacCalculator boundary: Dec 22 = Capricorn, Dec 21 = Sagittarius
void main() {
  group('UserProfile.fromOnboarding', () {
    test('computes zodiac sign from birth date', () {
      final profile = UserProfile.fromOnboarding(
        uid: 'u1',
        birthDate: DateTime(1995, 3, 25), // Aries
      );
      expect(profile.zodiacSign, 'aries');
      expect(profile.uid, 'u1');
    });

    test('defaults language to en, notification time to 09:00', () {
      final profile = UserProfile.fromOnboarding(
        uid: 'u1',
        birthDate: DateTime(1990, 6, 15),
      );
      expect(profile.preferredLanguage, AppConstants.defaultLanguage);
      expect(profile.notificationTime, AppConstants.defaultNotificationTime);
    });

    test('accepts optional birth time and place', () {
      final profile = UserProfile.fromOnboarding(
        uid: 'u2',
        birthDate: DateTime(1988, 12, 5),
        birthTime: '14:30',
        birthPlaceName: 'London',
      );
      expect(profile.birthTime, '14:30');
      expect(profile.birthPlaceName, 'London');
    });

    test('hasCompletedOnboarding defaults to false', () {
      final profile = UserProfile.fromOnboarding(
        uid: 'u3',
        birthDate: DateTime(2000, 1, 1),
      );
      expect(profile.hasCompletedOnboarding, isFalse);
    });
  });

  group('UserProfile.validateBirthDate', () {
    test('returns null for valid birth date (age 25)', () {
      final date = DateTime(DateTime.now().year - 25, 6, 15);
      expect(UserProfile.validateBirthDate(date), isNull);
    });

    test('rejects null date', () {
      expect(UserProfile.validateBirthDate(null), isNotNull);
    });

    test('rejects future date', () {
      final future = DateTime.now().add(const Duration(days: 1));
      expect(UserProfile.validateBirthDate(future), isNotNull);
    });

    test('rejects age below 13 (COPPA)', () {
      final tooYoung = DateTime(
        DateTime.now().year - AppConstants.minimumAge + 1,
        6,
        1,
      );
      final error = UserProfile.validateBirthDate(tooYoung);
      expect(error, contains('13'));
    });

    test('accepts exactly 13 years old', () {
      final exactAge = DateTime(
        DateTime.now().year - AppConstants.minimumAge,
        1,
        1,
      );
      expect(UserProfile.validateBirthDate(exactAge), isNull);
    });

    test('rejects age > 120', () {
      final ancient = DateTime(DateTime.now().year - 121, 1, 1);
      expect(UserProfile.validateBirthDate(ancient), isNotNull);
    });
  });

  group('UserProfile.copyWith', () {
    final base = UserProfile(
      uid: 'u1',
      birthDate: DateTime(1990, 5, 15),
      zodiacSign: 'taurus',
      preferredLanguage: 'en',
      notificationTime: '09:00',
      createdAt: DateTime(2024, 1, 1),
    );

    test('preserves all unchanged fields', () {
      final updated = base.copyWith(preferredLanguage: 'es');
      expect(updated.uid, base.uid);
      expect(updated.birthDate, base.birthDate);
      expect(updated.zodiacSign, base.zodiacSign);
      expect(updated.preferredLanguage, 'es');
      expect(updated.notificationTime, base.notificationTime);
    });

    test('can update hasCompletedOnboarding', () {
      final completed = base.copyWith(hasCompletedOnboarding: true);
      expect(completed.hasCompletedOnboarding, isTrue);
      expect(base.hasCompletedOnboarding, isFalse); // original unchanged
    });
  });

  group('ZodiacCalculator boundary cases', () {
    test('Dec 21 → Sagittarius', () {
      expect(ZodiacCalculator.getSign(DateTime(2000, 12, 21)), 'sagittarius');
    });

    test('Dec 22 → Capricorn', () {
      expect(ZodiacCalculator.getSign(DateTime(2000, 12, 22)), 'capricorn');
    });

    test('Mar 20 → Pisces', () {
      expect(ZodiacCalculator.getSign(DateTime(2000, 3, 20)), 'pisces');
    });

    test('Mar 21 → Aries', () {
      expect(ZodiacCalculator.getSign(DateTime(2000, 3, 21)), 'aries');
    });

    test('all 12 signs are recognized', () {
      final dates = [
        (DateTime(2000, 4, 1), 'aries'),
        (DateTime(2000, 5, 1), 'taurus'),
        (DateTime(2000, 6, 1), 'gemini'),
        (DateTime(2000, 7, 1), 'cancer'),
        (DateTime(2000, 8, 1), 'leo'),
        (DateTime(2000, 9, 1), 'virgo'),
        (DateTime(2000, 10, 1), 'libra'),
        (DateTime(2000, 11, 1), 'scorpio'),
        (DateTime(2000, 12, 1), 'sagittarius'),
        (DateTime(2000, 1, 10), 'capricorn'),
        (DateTime(2000, 2, 1), 'aquarius'),
        (DateTime(2000, 3, 10), 'pisces'),
      ];
      for (final (date, expected) in dates) {
        expect(ZodiacCalculator.getSign(date), expected,
            reason: 'Expected $expected for ${date.month}/${date.day}');
      }
    });
  });
}
