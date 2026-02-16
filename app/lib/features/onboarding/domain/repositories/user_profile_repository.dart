import '../../domain/entities/user_profile.dart';

/// Contract for persisting and retrieving user profile data.
///
/// Offline-first strategy:
/// - Read: local (Drift) → Firestore background refresh
/// - Write: local first, then sync to Firestore
///
/// Privacy: Only birth date + optional fields + preferences.
/// No PII beyond what the user explicitly provides.
abstract interface class UserProfileRepository {
  /// Get the active user profile from local cache.
  /// Returns null if no profile saved (first launch).
  Future<UserProfile?> getProfile();

  /// Save profile locally and queue Firestore sync.
  /// Called after onboarding completes.
  Future<void> saveProfile(UserProfile profile);

  /// Update specific profile fields (e.g., notification time change).
  Future<void> updateProfile(UserProfile profile);

  /// Mark disclaimer as accepted (required before using app).
  /// Timestamp saved to Firestore for compliance audit trail.
  Future<void> acceptDisclaimer(String userId);

  /// Mark onboarding as complete (sets today_screen as home).
  Future<void> completeOnboarding(String userId);

  /// Permanently delete all local and Firestore data for user.
  /// Called from Settings → Delete Account.
  Future<void> deleteAllData(String userId);
}
