import 'package:equatable/equatable.dart';
import 'package:mystic_tarot/core/constants/app_constants.dart';

/// Core user profile entity — Entertainment app, minimal PII.
///
/// PRIVACY NOTE: We collect minimum data necessary for personalization.
/// All data is stored securely in Firestore under the user's UID.
/// Users can delete their account and all associated data.
class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.birthDate,
    required this.zodiacSign,
    required this.preferredLanguage,
    required this.notificationTime,
    required this.createdAt,
    this.gender,
    this.birthTime,
    this.birthPlaceName,
    this.birthPlaceLat,
    this.birthPlaceLng,
    this.themeMode = 'dark',
    this.hasCompletedOnboarding = false,
    this.installDate,
  });

  final String uid;
  final DateTime birthDate;
  final String zodiacSign; // derived, cached

  // Optional personalization
  final String? gender; // 'male' | 'female' | 'non_binary' | null
  final String? birthTime; // "HH:mm" format
  final String? birthPlaceName; // city name
  final double? birthPlaceLat;
  final double? birthPlaceLng;

  // Preferences
  final String preferredLanguage; // 'en' | 'es' | 'pt' | 'ru'
  final String notificationTime; // "HH:mm"
  final String themeMode; // 'dark' | 'light' | 'system'
  final bool hasCompletedOnboarding;
  final DateTime? installDate;
  final DateTime createdAt;

  /// Factory: create new profile from onboarding data
  factory UserProfile.fromOnboarding({
    required String uid,
    required DateTime birthDate,
    String? gender,
    String? birthTime,
    String? birthPlaceName,
    double? birthPlaceLat,
    double? birthPlaceLng,
    String language = AppConstants.defaultLanguage,
    String notificationTime = AppConstants.defaultNotificationTime,
  }) {
    return UserProfile(
      uid: uid,
      birthDate: birthDate,
      zodiacSign: ZodiacCalculator.getSign(birthDate),
      gender: gender,
      birthTime: birthTime,
      birthPlaceName: birthPlaceName,
      birthPlaceLat: birthPlaceLat,
      birthPlaceLng: birthPlaceLng,
      preferredLanguage: language,
      notificationTime: notificationTime,
      createdAt: DateTime.now(),
      installDate: DateTime.now(),
    );
  }

  /// Validate birth date
  static String? validateBirthDate(DateTime? date) {
    if (date == null) return 'Birth date is required';
    if (date.isAfter(DateTime.now())) return 'Birth date cannot be in the future';
    final age = DateTime.now().difference(date).inDays ~/ 365;
    if (age < AppConstants.minimumAge) {
      return 'You must be at least ${AppConstants.minimumAge} years old';
    }
    if (age > 120) return 'Please enter a valid birth date';
    return null;
  }

  UserProfile copyWith({
    String? uid,
    DateTime? birthDate,
    String? zodiacSign,
    String? gender,
    String? birthTime,
    String? birthPlaceName,
    double? birthPlaceLat,
    double? birthPlaceLng,
    String? preferredLanguage,
    String? notificationTime,
    String? themeMode,
    bool? hasCompletedOnboarding,
    DateTime? installDate,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      birthDate: birthDate ?? this.birthDate,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      gender: gender ?? this.gender,
      birthTime: birthTime ?? this.birthTime,
      birthPlaceName: birthPlaceName ?? this.birthPlaceName,
      birthPlaceLat: birthPlaceLat ?? this.birthPlaceLat,
      birthPlaceLng: birthPlaceLng ?? this.birthPlaceLng,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      notificationTime: notificationTime ?? this.notificationTime,
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      installDate: installDate ?? this.installDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        birthDate,
        zodiacSign,
        gender,
        birthTime,
        birthPlaceName,
        birthPlaceLat,
        birthPlaceLng,
        preferredLanguage,
        notificationTime,
        themeMode,
        hasCompletedOnboarding,
      ];
}
