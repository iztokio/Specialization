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
/// all methods fall back gracefully, returning 'local_user_fallback' as UID.
class AuthService {
  AuthService(this._auth);

  /// Nullable: null when Firebase is not initialized (offline mode).
  final FirebaseAuth? _auth;

  /// Current authenticated user. Null if not signed in or offline.
  User? get currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Current user ID. Always returns a non-null value.
  /// Falls back to 'local_user_fallback' when offline or not authed.
  String get currentUserId {
    try {
      return _auth?.currentUser?.uid ?? 'local_user_fallback';
    } catch (_) {
      return 'local_user_fallback';
    }
  }

  /// Whether the user is currently signed in.
  bool get isSignedIn {
    try {
      return _auth?.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Stream of auth state changes (for router redirection).
  /// In offline mode, emits null immediately so the router doesn't hang.
  Stream<User?> get authStateChanges {
    try {
      return _auth?.authStateChanges() ?? Stream.value(null);
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Sign in anonymously (called on first launch).
  ///
  /// If already signed in, returns current user's UID.
  /// In offline mode, returns 'local_user_fallback' without throwing.
  Future<String> signInAnonymously() async {
    final auth = _auth;
    if (auth == null) return 'local_user_fallback'; // Offline mode

    try {
      if (auth.currentUser != null) return auth.currentUser!.uid;
      final credential = await auth.signInAnonymously();
      return credential.user!.uid;
    } catch (_) {
      return 'local_user_fallback';
    }
  }

  /// Sign out. No-op in offline mode.
  Future<void> signOut() async {
    try {
      await _auth?.signOut();
    } catch (_) {
      // Offline — nothing to sign out from
    }
  }

  /// Delete the current user's auth account. No-op in offline mode.
  Future<void> deleteAccount() async {
    try {
      await _auth?.currentUser?.delete();
    } catch (_) {
      // Offline — nothing to delete
    }
  }
}

// ─── Riverpod providers ─────────────────────────────────────────────────────

/// FirebaseAuth instance, or null if Firebase is not initialized.
final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  try {
    return FirebaseAuth.instance;
  } catch (_) {
    // Firebase.initializeApp() was not called (e.g. no firebase_options)
    return null;
  }
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

/// Stream of auth state changes (for GoRouter redirect).
/// Emits AsyncData(null) immediately in offline mode.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Current user ID — ALWAYS non-null. 'local_user_fallback' when offline.
final authUserIdProvider = Provider<String>((ref) {
  // Prefer UID from live auth state; fall back to AuthService getter.
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid != null) return uid;
  return ref.watch(authServiceProvider).currentUserId;
});

/// Whether Firebase Auth session exists.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});
