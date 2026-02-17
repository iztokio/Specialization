# TECH STACK DECISION — Horoscope & Tarot App
**Version:** 0.1.0 | **Date:** 2026-02-16

---

## РЕШЕНИЕ: Flutter + Firebase

**Обоснование выбора:**
- Единая кодовая база для Android + iOS (архитектурное требование)
- Firebase = самый быстрый path to production для solo/small team
- Большая экосистема пакетов для всего необходимого
- Официальные плагины Google (Play Billing, AdMob, Analytics)

---

## TECHNOLOGY STACK

### CLIENT

| Layer | Technology | Package | Version | Justification |
|-------|-----------|---------|---------|---------------|
| Framework | Flutter | - | 3.27.x (stable) | Cross-platform, native perf |
| Language | Dart | - | 3.6.x | Type-safe, null-safe |
| State Management | Riverpod | `riverpod` + `flutter_riverpod` | 2.x | Compile-safe, testable, no context |
| Navigation | GoRouter | `go_router` | 14.x | Declarative, deep links, shell routes |
| Local DB | Drift (SQLite) | `drift` + `drift_flutter` | 2.x | Type-safe SQL, migrations, code gen |
| Secure Storage | flutter_secure_storage | `flutter_secure_storage` | 9.x | iOS Keychain / Android Keystore |
| HTTP | Dio | `dio` | 5.x | Interceptors, retry, timeouts |
| Localization | Flutter intl | `flutter_localizations` + `intl` | built-in | Official i18n support |
| Animations | Flutter native + Lottie | `lottie` | 3.x | Mystic card flip animations |
| Images | Cached Network Image | `cached_network_image` | 3.x | CDN images with offline cache |
| Date/Time | - | built-in `DateTime` | - | No external dep needed |
| Logging | Logger | `logger` | 2.x | Structured logging, PII-safe |
| Permissions | Permission Handler | `permission_handler` | 11.x | Notifications, location |
| Local Notifications | Flutter Local Notifications | `flutter_local_notifications` | 17.x | Daily reminders |

### FIREBASE SERVICES

| Service | Use Case | Package |
|---------|----------|---------|
| Firebase Auth | Anonymous + Email + Google auth | `firebase_auth` |
| Firestore | User data, content, readings | `cloud_firestore` |
| Remote Config | Feature flags, content versions, A/B | `firebase_remote_config` |
| FCM | Push notifications | `firebase_messaging` |
| Analytics | User behavior tracking | `firebase_analytics` |
| Crashlytics | Crash reporting | `firebase_crashlytics` |
| Performance | App performance monitoring | `firebase_performance` |
| Storage | Tarot card images CDN | `firebase_storage` |
| App Check | Prevent API abuse | `firebase_app_check` |
| Cloud Functions | Purchase verification, content gen | `cloud_functions` |

### MONETIZATION & ADS

| Service | Package | Version |
|---------|---------|---------|
| Google Play Billing | `in_app_purchase` | 3.x |
| AdMob | `google_mobile_ads` | 5.x |

### BACKEND (Firebase Functions — Node.js/TypeScript)

| Function | Trigger | Purpose |
|----------|---------|---------|
| `verifyPurchase` | HTTPS callable | Google Play API purchase verification |
| `updateSubscriptionStatus` | Pub/Sub (Play RTDN) | Real-time subscription updates |
| `generateDailyContent` | Scheduled (cron) | Pre-generate daily readings |
| `sendDailyNotification` | Scheduled (FCM batch) | Push notification dispatch |
| `moderateContent` | Firestore trigger | LLM content moderation (v2) |

### CI/CD

| Tool | Purpose |
|------|---------|
| GitHub Actions | CI pipeline |
| `flutter analyze` | Static analysis (lint) |
| `flutter test` | Unit + widget tests |
| `flutter build apk --debug` | Build validation |
| `dart format` | Code formatting |
| Fastlane (future) | Automated Play Store deploy |

---

## ARCHITECTURE PATTERN: Clean Architecture + Feature-First

```
lib/
├── core/                    # Shared infrastructure
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── theme/
│   ├── router/
│   ├── utils/
│   └── services/            # Firebase wrapper services
│
├── features/                # Feature modules
│   ├── onboarding/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── today/               # Today screen (horoscope + tarot)
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── tarot/               # Tarot card deck + spreads
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── horoscope/           # Horoscope history + detail
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── history/             # Reading history
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── subscription/        # Paywall + billing
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── settings/            # Profile + settings
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── notifications/       # Push + local notifications
│       ├── data/
│       ├── domain/
│       └── presentation/
│
├── l10n/                    # Localization ARB files
│   ├── app_en.arb
│   ├── app_es.arb
│   ├── app_pt.arb
│   └── app_ru.arb
│
└── main.dart
```

### Per-feature structure (Clean Architecture):
```
feature/
├── data/
│   ├── datasources/         # Remote (Firebase) + Local (Drift)
│   ├── models/              # Data models with JSON serialization
│   └── repositories/        # Repository implementations
├── domain/
│   ├── entities/            # Business entities (pure Dart)
│   ├── repositories/        # Abstract repository interfaces
│   └── usecases/            # Business logic use cases
└── presentation/
    ├── providers/           # Riverpod providers
    ├── screens/             # Full screens
    └── widgets/             # Feature-specific widgets
```

---

## STATE MANAGEMENT: Riverpod 2.x

**Выбор:** Riverpod (не Bloc, не Provider)
**Причины:**
- Compile-time safety (нет runtime errors)
- Testable без BuildContext
- Code generation снижает boilerplate
- AsyncValue для loading/error/data — идеально для Firebase

```dart
// Пример: subscription provider
@riverpod
Future<SubscriptionStatus> subscriptionStatus(SubscriptionStatusRef ref) async {
  final uid = ref.watch(currentUserProvider).value?.uid;
  if (uid == null) return SubscriptionStatus.free;
  return ref.watch(subscriptionRepositoryProvider).getStatus(uid);
}

// Использование в виджете:
final status = ref.watch(subscriptionStatusProvider);
return status.when(
  data: (s) => s.isPremium ? PremiumContent() : FreeContent(),
  loading: () => const ContentSkeleton(),
  error: (e, _) => FreeContent(), // Fail safe = free content
);
```

---

## DATABASE SCHEMA (Drift)

```dart
// Локальная SQLite схема — детали в Stage 2
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firebaseUid => text().unique()();
  DateTimeColumn get birthDate => dateTime()();
  TextColumn get zodiacSign => text()(); // derived, cached
  TextColumn get gender => text().nullable()();
  TextColumn get birthTime => text().nullable()(); // "HH:mm"
  TextColumn get birthPlace => text().nullable()();
  TextColumn get preferredLanguage => text().withDefault(const Constant('en'))();
  TextColumn get notificationTime => text().withDefault(const Constant('09:00'))();
  IntColumn get contentVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class DailyReadings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firebaseUid => text()();
  DateTimeColumn get readingDate => dateTime()(); // date only, no time
  TextColumn get zodiacSign => text()();
  TextColumn get horoscopeText => text()();
  TextColumn get tarotCardIds => text()(); // JSON array
  TextColumn get tarotPositions => text()(); // JSON: upright/reversed
  BoolColumn get isPremiumReading => boolean().withDefault(const Constant(false))();
  TextColumn get language => text()();
  IntColumn get contentVersion => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

---

## FIRESTORE SCHEMA

```
/users/{uid}
  - birthDate: Timestamp
  - zodiacSign: string
  - gender: string? (optional)
  - birthTime: string? (optional) "HH:mm"
  - birthPlace: GeoPoint? (optional)
  - birthPlaceName: string? (optional)
  - preferredLanguage: string
  - notificationTime: string "HH:mm"
  - subscriptionStatus: string (ONLY written by Cloud Functions)
  - subscriptionExpiry: Timestamp?
  - fcmToken: string?
  - createdAt: Timestamp
  - updatedAt: Timestamp

/users/{uid}/readings/{yyyy-MM-dd}
  - date: Timestamp
  - zodiacSign: string
  - horoscopeText: map {en, es, pt, ru}
  - tarotCards: array [{id, position: "upright"|"reversed"}]
  - isPremium: bool
  - contentVersion: number
  - seed: number (для воспроизводимости)
  - createdAt: Timestamp

/content/tarot/cards/{cardId}
  - id: string (e.g. "major_00_fool")
  - name: map {en, es, pt, ru}
  - arcana: "major" | "minor"
  - suit: string? (cups|wands|swords|pentacles)
  - number: number
  - imageUrl: string (Firebase Storage URL)
  - imageLicense: string
  - imageSource: string
  - meanings: {
      upright: map {en, es, pt, ru},
      reversed: map {en, es, pt, ru},
      love: map {en, es, pt, ru},
      work: map {en, es, pt, ru},
      health: map {en, es, pt, ru}
    }
  - version: number

/content/horoscope/templates/{signId}
  - sign: string
  - templates: array of strings (multilang)
  - version: number
  - updatedAt: Timestamp

/system/config
  - contentVersion: number
  - minimumAppVersion: string
  - maintenanceMode: bool
  - adShowAfterDays: number (default: 7)
  - freeHistoryDays: number (default: 7)
  - premiumHistoryDays: number (default: 90)
```

---

## ВЕРСИОНИРОВАНИЕ КОНТЕНТА

```
Content update flow:
1. Admin обновляет content в Firestore
2. Admin увеличивает /system/config.contentVersion
3. Клиент при запуске проверяет contentVersion vs локальная версия
4. Если version > local → invalidate cache → reload from Firestore
5. Remote Config как fallback для быстрых флагов
```

---

## OFFLINE STRATEGY

```
Cache-First with Background Refresh:

1. Today's reading:
   - Check local SQLite (DailyReadings where date = today)
   - If exists → show immediately
   - Background sync from Firestore
   - If not exists + offline → show "offline" placeholder with last known horoscope

2. Tarot cards (metadata):
   - Preloaded into SQLite on first launch
   - Images: CachedNetworkImage (disk cache 100MB)
   - Updated only when contentVersion changes

3. History (7 days):
   - SQLite as source of truth for offline
   - Sync from Firestore when online
```

---

## ENVIRONMENT CONFIGURATION

```
.env.development      # Firebase Dev project
.env.staging          # Firebase Staging project
.env.production       # Firebase Production project

# Variables:
FIREBASE_PROJECT_ID=
ADMOB_APP_ID_ANDROID=
ADMOB_BANNER_ID=
ADMOB_INTERSTITIAL_ID=
PLAY_SUBSCRIPTION_MONTHLY_ID=
PLAY_SUBSCRIPTION_YEARLY_ID=
```

**КРИТИЧНО:** `.env.*` файлы в `.gitignore`. Секреты передаются через CI/CD secrets.

---

*Детальная архитектура — Stage 2*
