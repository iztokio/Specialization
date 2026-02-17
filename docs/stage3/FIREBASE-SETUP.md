# FIREBASE SETUP — Stage 3
**Version:** 1.0.0 | **Date:** 2026-02-16
**App:** AstraLume (`com.astralume.horoscope`)

---

## OVERVIEW

Stage 3 wires the Flutter app to Firebase. All services are
initialized in `main.dart` with graceful offline fallback:
if `firebase_options.dart` contains placeholder values, the app
runs fully in offline mode using the local Drift database.

---

## STEP-BY-STEP FIREBASE SETUP

### 1. Create Firebase Project
```
https://console.firebase.google.com/
Project name: astralume-prod
Project ID:   astralume-prod (or similar)
Analytics:    YES (Google Analytics)
```

### 2. Register Android App
```
Package name: com.astralume.horoscope
App nickname: AstraLume Android
SHA-1:        [generate with: keytool -list -v -keystore debug.keystore]
```

### 3. Register iOS App
```
Bundle ID:    com.astralume.horoscope
App nickname: AstraLume iOS
```

### 4. Enable Firebase Services (Firebase Console)

| Service | Purpose | Notes |
|---------|---------|-------|
| Authentication | Anonymous auth (UID) | Enable Anonymous provider |
| Firestore Database | Content + user data | Start in test mode, then apply rules |
| Remote Config | Feature flags + content version | Add all keys from DATA-CONTRACTS.md |
| Cloud Messaging (FCM) | Push notifications | Download APNs certificate for iOS |
| Analytics | User behavior | Linked via Firebase |
| Crashlytics | Crash reporting | Enable in Firebase console |
| App Check | API security | Enable Play Integrity (Android) / DeviceCheck (iOS) |
| Storage | Tarot card images | Set CORS rules |
| Cloud Functions | Purchase verification | Node 18, deploy from /backend |

### 5. Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### 6. Configure Flutter App
```bash
cd app/
flutterfire configure \
  --project=astralume-prod \
  --platforms=android,ios
```

This generates `lib/firebase_options.dart` — **commit this file**.
It replaces the placeholder file created in Stage 3.

### 7. Deploy Firestore Security Rules
```bash
cd backend/
firebase use astralume-prod
firebase deploy --only firestore:rules
```

### 8. Deploy Cloud Functions
```bash
cd backend/functions/
npm install
npm run build
firebase deploy --only functions
```

### 9. Set Remote Config Defaults (Firebase Console)
Add these key-value pairs in Remote Config → Parameters:

| Key | Default | Type |
|-----|---------|------|
| content_version | 0 | Number |
| minimum_app_version | 1.0.0 | String |
| maintenance_mode | false | Boolean |
| ad_show_after_days | 7 | Number |
| free_history_days | 7 | Number |
| premium_history_days | 90 | Number |
| paywall_variant | control | String |

### 10. Set Up AdMob (for Stage 4)
```
https://admob.google.com/
App name: AstraLume
Platform: Android → Bundle ID: com.astralume.horoscope
Platform: iOS → Bundle ID: com.astralume.horoscope
```
Get AdMob App ID → update `android/app/src/main/AndroidManifest.xml`

---

## OFFLINE MODE (No Firebase)

When `firebase_options.dart` contains placeholder values:
- App catches `UnsupportedError` from `DefaultFirebaseOptions.currentPlatform`
- `firebaseReady = false` → Firebase services disabled
- Local Drift database works normally
- Readings use deterministic placeholder content
- No auth → userId = 'local_user_fallback'

This allows development without a Firebase project configured.

---

## SECURITY CHECKLIST

Before going live:
- [ ] Firestore rules deployed (`firebase deploy --only firestore:rules`)
- [ ] App Check enabled (Play Integrity + DeviceCheck)
- [ ] Service account key NOT committed to git
- [ ] AdMob App ID in AndroidManifest.xml (not placeholder)
- [ ] APNs certificate configured for iOS push notifications
- [ ] `google-services.json` added to `android/app/` (gitignored)
- [ ] `GoogleService-Info.plist` added to `ios/Runner/` (gitignored)

---

## FILES CHANGED IN STAGE 3

| File | Change |
|------|--------|
| `lib/firebase_options.dart` | Placeholder (replace with flutterfire output) |
| `lib/main.dart` | Firebase init with offline fallback |
| `lib/core/services/auth_service.dart` | Anonymous auth + Riverpod providers |
| `lib/core/services/notification_service.dart` | FCM + local notifications |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Full settings UI |
| `lib/features/history/presentation/screens/history_screen.dart` | History list UI |

---

*Complete Firebase setup before Stage 4 (Monetization)*
