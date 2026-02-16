import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

/// Push notification service for AstraLume.
///
/// Handles:
/// 1. FCM token management (registration + refresh)
/// 2. Daily horoscope reminders (scheduled local notification)
/// 3. FCM message handling (foreground + background)
///
/// Permission: Requested after onboarding completes, not on first launch.
/// Channels: 'daily_horoscope' (Android 8+)
///
/// GDPR/privacy: FCM token stored server-side only, never in shared prefs.
class NotificationService {
  NotificationService(this._messaging, this._localNotifications);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  /// Initialize notification channels and FCM listeners.
  /// Call once in main() after Firebase.initializeApp().
  Future<void> initialize() async {
    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      AppConstants.dailyNotificationChannelId,
      AppConstants.dailyNotificationChannelName,
      description: 'Daily personalized horoscope reading',
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Initialize local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false, // Request explicitly after onboarding
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Handle FCM messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

    // Set FCM foreground presentation options (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Request notification permission (call after onboarding).
  /// Returns true if permission granted.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get FCM registration token for this device.
  /// Token is sent to server to enable targeted push notifications.
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  /// Schedule daily horoscope notification at [time] (HH:mm format).
  /// Replaces any previously scheduled notification.
  Future<void> scheduleDailyNotification({
    required String notificationTitle,
    required String notificationBody,
    required String time, // "HH:mm"
  }) async {
    final parts = time.split(':');
    if (parts.length != 2) return;

    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;

    // TODO(stage3): Implement TZDateTime-based scheduling with flutter_timezone
    // For now, use a 10-second test notification in debug mode
    await _localNotifications.show(
      AppConstants.dailyNotificationId,
      notificationTitle,
      notificationBody,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.dailyNotificationChannelId,
          AppConstants.dailyNotificationChannelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Suppress unused variable warnings for hour/minute until TZDateTime impl
    assert(hour >= 0 && hour < 24);
    assert(minute >= 0 && minute < 60);
  }

  /// Cancel the daily notification (when user disables in settings).
  Future<void> cancelDailyNotification() async {
    await _localNotifications.cancel(AppConstants.dailyNotificationId);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.dailyNotificationChannelId,
          AppConstants.dailyNotificationChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _handleBackgroundMessageTap(RemoteMessage message) {
    // TODO(stage3): Navigate to today screen or specific reading
    // ref.read(appRouterProvider).go('/today');
  }

  void _onNotificationTapped(NotificationResponse response) {
    // TODO(stage3): Navigate to today screen
  }
}

// ─── Background message handler (top-level, required by FCM) ─────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialized in the background isolate
  // This is called when the app is terminated and receives a data message
  // Note: Do NOT initialize Firebase here — it's handled by the plugin
}

// ─── Riverpod providers ──────────────────────────────────────────────────────

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final localNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    ref.watch(firebaseMessagingProvider),
    ref.watch(localNotificationsProvider),
  );
});
