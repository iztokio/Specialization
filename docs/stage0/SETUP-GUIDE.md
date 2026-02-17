# SETUP GUIDE — Developer Environment
**Version:** 0.1.0 | **Date:** 2026-02-16

---

## PREREQUISITES

### Required Tools
```bash
# 1. Flutter SDK 3.27.x (stable)
# Download from https://docs.flutter.dev/get-started/install
# Or use FVM (Flutter Version Manager):
dart pub global activate fvm
fvm install 3.27.4
fvm use 3.27.4

# 2. Verify Flutter installation
flutter doctor -v

# 3. Java 17+ (for Android builds)
# Already installed: OpenJDK 21

# 4. Node.js 20+ (for Firebase Functions)
# Already installed: Node 22

# 5. Firebase CLI
npm install -g firebase-tools
firebase login

# 6. FlutterFire CLI (for Firebase config)
dart pub global activate flutterfire_cli
```

### Android Setup
```bash
# 1. Install Android Studio OR Android command-line tools
# https://developer.android.com/studio

# 2. Accept licenses
flutter doctor --android-licenses

# 3. Verify
flutter doctor
```

---

## FIREBASE PROJECT SETUP

### 1. Create Firebase Project
```
1. Go to https://console.firebase.google.com
2. Create new project: "mystic-tarot-prod"
3. Enable Google Analytics
4. Create separate project for dev: "mystic-tarot-dev"
```

### 2. Enable Firebase Services
```
Auth: Enable Anonymous + Email + Google sign-in
Firestore: Create database (production mode, region: your closest)
Remote Config: Initialize
Cloud Messaging: (automatic)
Analytics: (automatic)
Crashlytics: Enable in Crashlytics tab
Performance: Enable
Storage: Create default bucket
App Check: Enable with Play Integrity (Android)
```

### 3. Configure Flutter App
```bash
cd app/

# Configure Firebase (creates google-services.json + lib/firebase_options.dart)
flutterfire configure \
  --project=mystic-tarot-dev \
  --platforms=android,ios

# NOTE: Keep google-services.json OUT of git (it's in .gitignore)
# Store in CI secrets instead
```

### 4. Firestore Security Rules
```bash
# Deploy rules from backend/firestore.rules
firebase deploy --only firestore:rules
```

---

## APP SETUP

### 1. Install Dependencies
```bash
cd app/
flutter pub get
```

### 2. Run Code Generation
```bash
cd app/
dart run build_runner build --delete-conflicting-outputs
```

### 3. Download Fonts
```bash
# Download from Google Fonts (open-source):
# Cinzel: https://fonts.google.com/specimen/Cinzel
# Raleway: https://fonts.google.com/specimen/Raleway
# Cinzel Decorative: https://fonts.google.com/specimen/Cinzel+Decorative

# All under SIL Open Font License 1.1 — OK for commercial use
# Place in app/assets/fonts/
```

### 4. Run App
```bash
# Run on connected device or emulator
flutter run

# Run in debug mode with specific device
flutter run -d <device-id>
```

---

## PLAY CONSOLE SETUP

### 1. Google Play Console
```
1. Create developer account: https://play.google.com/console
2. Create new app: "Mystic Tarot"
3. Category: Entertainment → Books & Reference
4. Content rating: PEGI 3 / Everyone (Entertainment)
```

### 2. In-App Products Setup
```
# Monthly subscription
Product ID: premium_monthly_v1
Price: $4.99/month (test with your target market)
Trial: 3 days free (optional, test both with A/B)

# Yearly subscription
Product ID: premium_yearly_v1
Price: $29.99/year (~50% discount vs monthly)
Trial: 7 days free
```

### 3. Real-Time Developer Notifications
```
1. Create Pub/Sub topic: play-rtdn
2. Grant permissions to Google Play service account
3. Set topic in Play Console → Monetization setup → Real-time developer notifications
```

---

## ADMOB SETUP

### 1. Create AdMob Account
```
1. https://admob.google.com
2. Add Android app with package: com.mystictarot.app
3. Copy App ID (ca-app-pub-XXXX~XXXX)
4. Create ad units:
   - Banner ad: ca-app-pub-XXXX/XXXX
   - Interstitial ad: ca-app-pub-XXXX/XXXX
```

### 2. Update AndroidManifest.xml
```xml
<!-- Replace REPLACE_WITH_ADMOB_APP_ID with actual App ID -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-YOUR_ACTUAL_APP_ID" />
```

---

## SIGNING SETUP (Release Build)

### 1. Generate Keystore
```bash
keytool -genkey -v -keystore mystic-tarot-release.jks \
  -keyalg RSA -keysize 2048 -validity 36500 \
  -alias mystic-tarot

# IMPORTANT: Store keystore file SECURELY (not in git!)
# Password manager or secure vault
```

### 2. key.properties (NOT in git)
```properties
# app/android/key.properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=mystic-tarot
storeFile=../mystic-tarot-release.jks
```

### 3. Build Release
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## BACKEND SETUP

### 1. Firebase Functions
```bash
cd backend/functions/
npm install
npm run build

# Deploy to Firebase
firebase deploy --only functions
```

### 2. Set Function Config
```bash
firebase functions:config:set \
  app.package_name="com.mystictarot.app"
```

---

## CI/CD SECRETS (GitHub)

Add these secrets in GitHub → Settings → Secrets:
```
GOOGLE_SERVICES_JSON       # Base64 encoded google-services.json
KEYSTORE_BASE64            # Base64 encoded .jks file
KEYSTORE_PASSWORD          # Keystore password
KEY_PASSWORD               # Key password
KEY_ALIAS                  # Key alias
FIREBASE_TOKEN             # firebase login --ci output
```

---

## RUNNING TESTS
```bash
cd app/

# Unit tests
flutter test test/unit/

# Widget tests
flutter test test/widget/

# All tests with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## ASSET CHECKLIST (Before Release)
- [ ] All 78 Tarot card images in `assets/images/tarot/`
- [ ] License documented in `docs/assets/ASSET-LICENSES.md`
- [ ] 12 Zodiac illustrations in `assets/images/zodiac/`
- [ ] App icon 1024×1024 PNG in `assets/images/`
- [ ] Lottie animations in `assets/lottie/`
- [ ] All fonts in `assets/fonts/` with license verification

---

*Next: Run `flutter doctor` and resolve any issues before Stage 1.*
