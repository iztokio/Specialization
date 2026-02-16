/// App-wide constants
///
/// IMPORTANT: No secrets here. Secrets go in .env files and CI secrets only.

class AppConstants {
  AppConstants._();

  // App metadata
  static const String appName = 'AstraLume';
  static const String appId = 'com.astralume.horoscope';
  static const String appVersion = '1.0.0';

  // Content
  static const int freeHistoryDays = 7;
  static const int premiumHistoryDays = 90;
  static const int adShowAfterDays = 7; // Show ads after N days of use
  static const int totalTarotCards = 78;
  static const int minRepeatWindowDays = 3; // Don't repeat same card within N days

  // Cache
  static const Duration contentCacheDuration = Duration(hours: 24);
  static const int maxCachedImages = 100; // MB for image cache

  // Subscriptions (Product IDs — must match Play Console)
  static const String subscriptionMonthlyId = 'premium_monthly_v1';
  static const String subscriptionYearlyId = 'premium_yearly_v1';

  // Notifications
  static const String dailyNotificationChannelId = 'daily_horoscope';
  static const String dailyNotificationChannelName = 'Daily Horoscope';
  static const int dailyNotificationId = 1001;
  static const String defaultNotificationTime = '09:00';

  // Remote Config keys
  static const String rcContentVersion = 'content_version';
  static const String rcMinimumAppVersion = 'minimum_app_version';
  static const String rcMaintenanceMode = 'maintenance_mode';
  static const String rcAdShowAfterDays = 'ad_show_after_days';
  static const String rcFreeHistoryDays = 'free_history_days';
  static const String rcPremiumHistoryDays = 'premium_history_days';
  static const String rcPaywallVariant = 'paywall_variant'; // A/B test

  // Analytics events
  static const String eventOnboardingStart = 'onboarding_start';
  static const String eventOnboardingComplete = 'onboarding_complete';
  static const String eventHoroscopeView = 'horoscope_view';
  static const String eventTarotDraw = 'tarot_draw';
  static const String eventTarotCardView = 'tarot_card_view';
  static const String eventPaywallView = 'paywall_view';
  static const String eventPaywallCta = 'paywall_cta_tap';
  static const String eventSubscriptionSuccess = 'subscription_success';
  static const String eventSubscriptionRestored = 'subscription_restored';
  static const String eventHistoryView = 'history_view';
  static const String eventNotificationPermissionGranted = 'notification_permission_granted';
  static const String eventAdImpression = 'ad_impression';

  // Firestore collections
  static const String colUsers = 'users';
  static const String colReadings = 'readings';
  static const String colContentTarot = 'content/tarot/cards';
  static const String colContentHoroscope = 'content/horoscope/templates';
  static const String docSystemConfig = 'system/config';

  // Supported languages
  static const List<String> supportedLanguages = ['en', 'es', 'pt', 'ru'];
  static const String defaultLanguage = 'en';

  // Zodiac signs
  static const List<String> zodiacSigns = [
    'aries', 'taurus', 'gemini', 'cancer',
    'leo', 'virgo', 'libra', 'scorpio',
    'sagittarius', 'capricorn', 'aquarius', 'pisces',
  ];

  // Grace period (days after subscription expires before removing premium access)
  static const int gracePeriodDays = 3;

  // Age gate
  static const int minimumAge = 13; // COPPA compliance

  // DISCLAIMER text key (used in all disclaimers)
  static const String disclaimerKey = 'disclaimer_entertainment_only';
}

/// Zodiac date ranges — no year-specific logic, month/day only
class ZodiacCalculator {
  ZodiacCalculator._();

  static String getSign(DateTime birthDate) {
    final month = birthDate.month;
    final day = birthDate.day;

    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return 'aries';
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return 'taurus';
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return 'gemini';
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return 'cancer';
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return 'leo';
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return 'virgo';
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return 'libra';
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return 'scorpio';
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) {
      return 'sagittarius';
    }
    if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) {
      return 'capricorn';
    }
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return 'aquarius';
    return 'pisces'; // Feb 19 — Mar 20
  }
}
