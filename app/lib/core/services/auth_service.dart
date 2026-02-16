import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Auth service for AstraLume.
///
/// Strategy: Anonymous Auth on first launch.
/// - User gets a stable UID immediately, no login friction
/// - UID is used as primary key in Firestore + local DB
/// - No email/password required (entertainment app)
/// - Account persists across app restarts
///
/// PRIVACY: No PII stored in auth profile. UID only.
/// COPPA: Users under 13 are blocked by age gate in onboarding.
///
/// Offline mode: If Firebase is not configured (no firebase_options),
/// returns a local-only UID ('local_user_fallback').
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  /// Current authenticated user. Null if not signed in.
  User? get currentUser => _auth.currentUser;

  /// Current user ID. Falls back to 'local_user_fallback' if not authed.
  String get currentUserId =>
      _auth.currentUser?.uid ?? 'local_user_fallback';

  /// Whether the user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Stream of auth state changes (signed in / signed out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in anonymously (called on first launch).
  ///
  /// If already signed in, returns current user.
  /// Throws [AuthException] if network unavailable and no cached session.
  Future<String> signInAnonymously() async {
    if (_auth.currentUser != null) {
      return _auth.currentUser!.uid;
    }

    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

  /// Sign out (called from Settings → Delete Account).
  /// After sign-out, the app resets to onboarding.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Delete the current user's auth account.
  /// Should be called after deleting Firestore data.
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }
}

// ─── Riverpod providers ─────────────────────────────────────────────────────

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

/// Stream of auth state changes (for router redirection).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Current user ID (or 'local_user_fallback' in offline mode).
final authUserIdProvider = Provider<String>((ref) {
  return ref.watch(authServiceProvider).currentUserId;
});

/// Whether Firebase Auth session exists.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});
