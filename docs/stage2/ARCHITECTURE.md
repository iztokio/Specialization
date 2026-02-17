# ARCHITECTURE — Stage 2: Data & State Management
**Version:** 1.0.0 | **Date:** 2026-02-16
**App:** AstraLume | **Stage:** 2 of 6

---

## 1. ARCHITECTURE OVERVIEW

### Pattern: Clean Architecture + Feature-First + Offline-First

```
UI Layer (Presentation)
    │  Riverpod providers (watches)
    ▼
Domain Layer
    │  Repository interfaces (abstract)
    ▼
Data Layer
    ├── Local Datasource (Drift / SQLite)
    └── Remote Datasource (Firestore) ← Stage 3
```

**Key Principles:**
- UI never touches database or network directly
- Domain layer has zero Flutter/Firebase dependencies
- Repository implementations are swappable (testability)
- Cache-first: local data shown immediately, background refresh from Firestore
- All writes to `subscriptionStatus` originate from server (Cloud Functions)

---

## 2. LOCAL DATABASE (Drift / SQLite)

### File: `app/lib/core/database/app_database.dart`
### Schema Version: 1 (baseline)

| Table | Purpose | PK | Unique constraint |
|-------|---------|-----|-------------------|
| `user_profiles` | User profile + preferences | `userId` | one row per user |
| `daily_readings` | Cached horoscope + card of day | `id` | userId+date+sign |
| `tarot_readings` | Cached tarot draws/spreads | `id` | userId+date+type |
| `subscription_cache` | Mirror of Firestore sub status | `userId` | one row per user |

### Cache Validity
| Data Type | Cache TTL | Refresh Trigger |
|-----------|-----------|-----------------|
| Daily reading | 24 hours | New day OR content_version change |
| Tarot spread | 24 hours | New day |
| Subscription | 6h (active) / 1h (grace) | App foreground + purchase event |
| User profile | Persistent | User explicitly updates settings |

### Migration Strategy
- Every schema change adds a migration step in `_migrate()` in `app_database.dart`
- Migrations MUST be idempotent (wrapped in `if (from < N)` blocks)
- Test file: `test/unit/core/database_migration_test.dart` (Stage 3)
- NEVER modify an existing migration — only add new steps

---

## 3. REPOSITORY PATTERN

### Offline-First Strategy

```
getX() call
    │
    ▼
Local cache valid?
    │ YES → return cached immediately
    │         + schedule background Firestore check (Stage 3)
    │
    NO ──► Fetch from Firestore (Stage 3)
               │
               ├─[Success]──► Store in local cache → return
               │
               └─[Network error]──► Return stale cache if exists
                                    Otherwise return error
```

### Repository Interfaces (Domain Layer)
| Interface | Location |
|-----------|----------|
| `UserProfileRepository` | `features/onboarding/domain/repositories/` |
| `HoroscopeRepository` | `features/today/domain/repositories/` |
| `TarotRepository` | `features/tarot/domain/repositories/` |
| `SubscriptionRepository` | `features/subscription/domain/repositories/` |

### Repository Implementations (Data Layer)
| Implementation | Stage | Remote added |
|---------------|-------|-------------|
| `UserProfileRepositoryImpl` | Stage 2 ✅ | Stage 3 |
| `HoroscopeRepositoryImpl` | Stage 2 ✅ | Stage 3 |
| `SubscriptionRepositoryImpl` | Stage 2 ✅ | Stage 3/4 |

---

## 4. STATE MANAGEMENT (Riverpod)

### Provider Hierarchy

```
appDatabaseProvider (singleton, never disposed)
    │
    ├── userProfileRepositoryProvider
    │       └── userProfileProvider (FutureProvider)
    │               ├── currentUserIdProvider
    │               ├── isOnboardingCompleteProvider
    │               ├── currentZodiacSignProvider
    │               ├── appThemeModeProvider
    │               └── appLanguageProvider
    │
    ├── horoscopeRepositoryProvider
    │       └── todayReadingProvider (FutureProvider)
    │
    └── subscriptionRepositoryProvider
            └── subscriptionStatusProvider (StreamProvider)
                    └── hasPremiumAccessProvider
```

### State Provider File
`app/lib/core/providers/core_providers.dart`

### Premium Access Gate (security layer)
```dart
// ALWAYS check this provider, never check subscription fields directly
final hasPremium = ref.watch(hasPremiumAccessProvider);
if (!hasPremium) showPaywall();
```

---

## 5. FIRESTORE SECURITY RULES

### File: `backend/firestore.rules`
### Key Rules

| Collection | Read | Write |
|-----------|------|-------|
| `/users/{userId}` | Owner only | Owner (no sub fields) |
| `/users/{userId}/disclaimers/{id}` | Owner | Owner (create only, immutable) |
| `/readings/{userId}/daily/{id}` | Owner | Owner (create/update) |
| `/content/**` | All authed users | DENIED (admin only) |
| `/system/**` | All authed users | DENIED (admin only) |
| Everything else | DENIED | DENIED |

### Critical Security Rule
```javascript
// Client CANNOT write subscription fields — Cloud Functions only
function hasNoSubscriptionFields() {
  return !request.resource.data.keys().hasAny([
    'subscriptionStatus', 'subscriptionState', 'productId',
    'purchaseToken', 'expiresAt', ...
  ]);
}
```

---

## 6. DETERMINISTIC CONTENT ENGINE

### Seed Generation (no randomness, reproducible)
```dart
int seed = DailyReading.generateSeed(date, zodiacSign);
// seed = hash(YYYYMMDD XOR signIndex * 1000000) — always positive
// Same date + sign = same seed on any device, any restart
```

### Card Selection (deterministic, excludes recent cards)
```dart
List<int> cards = DailyReading.selectCardIndices(
  seed: seed,
  count: 1, // 3 for premium spread
  totalCards: 78,
  excludeIndices: recentCardIndices, // 3-day exclusion window
);
```

### Daily Reading Cache Key
```
id = '{userId}_{YYYY-MM-DD}'
```

---

## 7. STAGE 2 GAPS (Resolved in Stage 3)

| Gap | Why deferred | Stage 3 action |
|-----|-------------|----------------|
| Firestore remote datasource | Needs firebase.json + flutterfire configure | Add after Firebase project setup |
| Drift code generation (.g.dart files) | Needs `build_runner` in CI | Run `flutter pub run build_runner build` |
| Firestore stream listeners for subscription | Needs Firebase auth | Add after Auth integration |
| Full multilingual content | Needs content management | Populate via Admin SDK / seeding script |
| Database migration tests | Needs schema v1 to stabilize | Add in Stage 3 |
| `TarotRepositoryImpl` | Lower priority, no premium Tarot yet | Stage 3 |

---

## 8. DECISIONS LOG

| Decision | Rationale |
|----------|-----------|
| Drift over Hive | Type-safe migrations; SQL queries for history filtering |
| Riverpod FutureProvider over StateNotifier | Simpler async state; cache-and-network pattern |
| Server-only subscription writes | Security: client cannot grant itself premium |
| 24h reading cache | Balance freshness vs battery/data usage |
| Feature-first folder structure | Scales better than layer-first for large apps |
| `part 'app_database.g.dart'` placeholder | build_runner generates in CI; avoids import errors |

---

*Stage 2 complete. Gate Audit follows before Stage 3.*
