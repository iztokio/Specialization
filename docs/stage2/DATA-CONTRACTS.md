# DATA CONTRACTS — Stage 2
**Version:** 1.0.0 | **Date:** 2026-02-16
**App:** AstraLume

---

## 1. FIRESTORE DATA MODELS

### /users/{userId}
```typescript
interface UserDocument {
  // Core — required
  birthDate: Timestamp;
  zodiacSign: string; // 'aries' | 'taurus' | ... | 'pisces'
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Optional personalization
  gender?: 'male' | 'female' | 'non_binary' | 'prefer_not_to_say';
  birthTime?: string;      // "HH:mm" format
  birthPlaceName?: string; // City name
  birthPlaceLat?: number;
  birthPlaceLng?: number;

  // Preferences
  preferredLanguage: 'en' | 'es' | 'pt' | 'ru';
  notificationTime: string;  // "HH:mm"
  themeMode: 'dark' | 'light' | 'system';
  notificationsEnabled: boolean;

  // Onboarding state
  hasCompletedOnboarding: boolean;

  // ⚠️ SUBSCRIPTION — WRITTEN BY SERVER ONLY ⚠️
  subscriptionStatus?: {
    state: 'free' | 'active' | 'cancelled' | 'expired' |
           'grace_period' | 'on_hold' | 'refunded' | 'unknown';
    productId?: string;        // 'premium_monthly_v1' | 'premium_yearly_v1'
    // purchaseToken: NEVER stored in client-readable Firestore
    expiresAt?: Timestamp;
    graceExpiresAt?: Timestamp;
    lastVerifiedAt?: Timestamp;
    isTrialPeriod: boolean;
  };
}
```

### /users/{userId}/disclaimers/{disclaimerId}
```typescript
// IMMUTABLE — create-only, cannot be updated or deleted (audit trail)
interface DisclaimerAcceptance {
  acceptedAt: Timestamp;   // When user tapped "I Understand"
  appVersion: string;      // e.g. "1.0.0"
  disclaimerVersion: string; // e.g. "1.0" — increment if disclaimer text changes
}
```

### /readings/{userId}/daily/{YYYYMMDD_zodiacSign}
```typescript
interface DailyReadingDocument {
  readingDate: Timestamp;
  zodiacSign: string;
  contentVersion: number;   // Must match system/config contentVersion

  horoscope: {
    general: LocalizedText;
    love:    LocalizedText;
    work:    LocalizedText;
    wellbeing: LocalizedText;
  };

  cardOfDay: {
    cardId: string;          // 'major_00_fool', 'cups_01_ace', etc.
    position: 'upright' | 'reversed';
    isReversed: boolean;
  };

  // Premium only — null for free users
  threeCardSpread?: {
    past:    { cardId: string; position: 'upright' | 'reversed' };
    present: { cardId: string; position: 'upright' | 'reversed' };
    future:  { cardId: string; position: 'upright' | 'reversed' };
  };

  language: string;
  isPremium: boolean;
  cachedAt: Timestamp;
}

interface LocalizedText {
  en: string;
  es: string;
  pt: string;
  ru: string;
}
```

### /content/tarot/cards/{cardId}
```typescript
// cardId format: 'major_00_fool', 'cups_01_ace', 'swords_14_king'
interface TarotCardDocument {
  id: string;
  number: number;    // 0-21 major, 1-14 minor
  arcana: 'major' | 'minor';
  suit: 'cups' | 'wands' | 'swords' | 'pentacles' | 'none';
  names: LocalizedText;
  imageUrl: string;       // Firebase Storage URL
  imageLicense: string;   // REQUIRED: e.g. "CC0 1.0", "Public Domain"
  imageSource: string;    // REQUIRED: attribution URL
  meanings: {
    upright:  LocalizedText;
    reversed: LocalizedText;
    love:     LocalizedText;  // Entertainment only
    work:     LocalizedText;  // Entertainment only
    health:   LocalizedText;  // Entertainment only — NOT medical advice
  };
  version: number;
}
```

### /system/config
```typescript
interface SystemConfig {
  contentVersion: number;       // Increment when horoscope/tarot content changes
  minimumAppVersion: string;    // Force update if app below this version
  maintenanceMode: boolean;     // Show maintenance screen if true
  adShowAfterDays: number;      // Override app default (default: 7)
  freeHistoryDays: number;      // Override app default (default: 7)
  premiumHistoryDays: number;   // Override app default (default: 90)
  paywallVariant: string;       // A/B test: 'control' | 'variant_a'
}
```

---

## 2. CLOUD FUNCTIONS API CONTRACTS

### verifyPurchase (HTTPS Callable)
```typescript
// Request (client → server)
interface VerifyPurchaseRequest {
  purchaseToken: string;   // From Google Play
  productId: string;       // 'premium_monthly_v1' | 'premium_yearly_v1'
  packageName: string;     // 'com.astralume.horoscope'
}

// Response (server → client)
interface VerifyPurchaseResponse {
  success: boolean;
  subscriptionState: string;  // 'active' | 'error' | etc.
  expiresAt?: string;         // ISO datetime
  isTrialPeriod: boolean;
  error?: string;             // Only on failure
}

// Error codes
// 'INVALID_TOKEN' — token rejected by Play API
// 'ALREADY_OWNED' — token already used by another account
// 'INTERNAL_ERROR' — server-side failure
```

### restorePurchases (HTTPS Callable)
```typescript
// Request — no parameters needed (uses Firebase Auth UID)
interface RestorePurchasesRequest {}

// Response
interface RestorePurchasesResponse {
  found: boolean;
  subscriptionState?: string;
  expiresAt?: string;
}
```

### handlePlayRTDN (Pub/Sub)
```typescript
// Triggered by Google Play Real-Time Developer Notifications
// Internal — not called by client
// Handles: subscription renewals, cancellations, holds, refunds
```

---

## 3. LOCAL DATABASE SCHEMA (Drift)

### user_profiles
| Column | Type | Default | Notes |
|--------|------|---------|-------|
| userId | TEXT PK | — | Firebase Auth UID |
| birthDate | INTEGER | — | Unix timestamp (ms) |
| zodiacSign | TEXT | — | Lowercase sign name |
| gender | TEXT? | NULL | Optional |
| birthTime | TEXT? | NULL | "HH:mm" |
| birthPlace | TEXT? | NULL | City name |
| language | TEXT | 'en' | ISO 639-1 |
| themeMode | TEXT | 'dark' | dark/light/system |
| notificationsEnabled | INTEGER | 1 | Boolean |
| notificationTime | TEXT | '09:00' | HH:mm |
| hasCompletedOnboarding | INTEGER | 0 | Boolean |
| hasAcceptedDisclaimer | INTEGER | 0 | Boolean |
| createdAt | INTEGER | NOW | Unix timestamp |
| updatedAt | INTEGER | NOW | Unix timestamp |

### daily_readings
| Column | Type | Default | Notes |
|--------|------|---------|-------|
| id | TEXT PK | — | {userId}_{YYYYMMDD}_{sign} |
| userId | TEXT | — | FK to user_profiles |
| readingDate | INTEGER | — | Date-only timestamp |
| zodiacSign | TEXT | — | |
| generalText | TEXT | — | Horoscope general text |
| loveText | TEXT | — | Love category |
| workText | TEXT | — | Work category |
| wellbeingText | TEXT | — | Wellbeing category |
| cardIndex | INTEGER | — | 0-77 |
| isReversed | INTEGER | — | Boolean |
| cardName | TEXT | — | Localized card name |
| cardMeaning | TEXT | — | Active meaning text |
| contentVersion | TEXT | '0' | Matches system/config |
| cachedAt | INTEGER | NOW | When cached |
| expiresAt | INTEGER | — | cachedAt + 24h |

### subscription_cache
| Column | Type | Default | Notes |
|--------|------|---------|-------|
| userId | TEXT PK | — | Firebase Auth UID |
| state | TEXT | 'free' | See SubscriptionState |
| productId | TEXT? | NULL | Play Store product ID |
| expiresAt | INTEGER? | NULL | Unix timestamp |
| lastSyncedAt | INTEGER | — | When synced from server |
| cacheValidUntil | INTEGER | — | Staleness threshold |

---

## 4. REMOTE CONFIG KEYS

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `content_version` | number | 0 | Increment on content update |
| `minimum_app_version` | string | "1.0.0" | Force upgrade gate |
| `maintenance_mode` | boolean | false | Maintenance screen |
| `ad_show_after_days` | number | 7 | Days before ads appear |
| `free_history_days` | number | 7 | Free tier history window |
| `premium_history_days` | number | 90 | Premium history window |
| `paywall_variant` | string | "control" | A/B test variant |

---

*Stage 2 data contracts v1.0.0 — subject to change in Stage 3 (Firebase integration)*
