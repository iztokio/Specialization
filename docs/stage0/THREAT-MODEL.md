# THREAT MODEL — Horoscope & Tarot App
**Framework:** STRIDE
**Version:** 0.1.0 | **Date:** 2026-02-16

---

## СИСТЕМА И ГРАНИЦЫ

```
┌─────────────────────────────────────────────────────────────┐
│  CLIENT (Flutter App)                                        │
│  ┌─────────────────┐    ┌──────────────────────────────┐    │
│  │  UI Layer       │    │  Local Storage (Drift/SQLite) │    │
│  │  - Screens      │    │  - DailyReading (7d cache)   │    │
│  │  - Widgets      │    │  - TarotCard metadata        │    │
│  ├─────────────────┤    │  - UserProfile (minimal)     │    │
│  │  Business Layer │    └──────────────────────────────┘    │
│  │  - Riverpod     │    ┌──────────────────────────────┐    │
│  │  - Use Cases    │    │  Secure Storage               │    │
│  ├─────────────────┤    │  - Firebase tokens            │    │
│  │  Data Layer     │    │  - Subscription status cache │    │
│  │  - Repositories │    └──────────────────────────────┘    │
│  └────────┬────────┘                                        │
└───────────┼─────────────────────────────────────────────────┘
            │ HTTPS / Firebase SDK (TLS 1.3)
            │ (No custom certificate pinning needed - Firebase handles it)
┌───────────▼─────────────────────────────────────────────────┐
│  FIREBASE BACKEND                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │  Firestore   │  │  Auth         │  │  Cloud Functions  │  │
│  │  - content   │  │  - anonymous  │  │  - verifyPurchase │  │
│  │  - readings  │  │  - email      │  │  - updateSubStatus│  │
│  └──────────────┘  │  - Google     │  │  - generateContent│  │
│  ┌──────────────┐  └──────────────┘  └──────────────────┘  │
│  │  Remote      │  ┌──────────────┐  ┌──────────────────┐  │
│  │  Config      │  │  FCM         │  │  Analytics +      │  │
│  │  - flags     │  │  - push notif│  │  Crashlytics      │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
            │
┌───────────▼──────────────────┐
│  GOOGLE PLAY (external)       │
│  - Purchase API               │
│  - Subscription status        │
└──────────────────────────────┘
```

---

## STRIDE ANALYSIS

### S — Spoofing (Подделка идентичности)

| ID | Угроза | Вектор | Вероятность | Меры защиты |
|----|--------|--------|-------------|-------------|
| S1 | Подделка Firebase Auth токена | Перехват/подделка JWT | Low | Firebase валидирует токены на сервере; короткий TTL |
| S2 | Клиент притворяется Premium | Модификация локального state | High | **Подписка проверяется ТОЛЬКО на сервере (Cloud Functions)** |
| S3 | Подмена Purchase Receipt | Crafted токен покупки | Med | Server-side verifyPurchase через Google Play API |

**Меры:**
```dart
// ЗАПРЕЩЕНО в клиентском коде:
if (localPremiumFlag) { showPremiumContent(); } // ❌ TAMPER-ABLE

// ПРАВИЛЬНО:
final isPremium = await _subscriptionRepository.verifyOnServer(); // ✅
```

---

### T — Tampering (Подделка данных)

| ID | Угроза | Вектор | Вероятность | Меры защиты |
|----|--------|--------|-------------|-------------|
| T1 | Модификация APK | Reverse engineering + repack | Med | Integrity checks (Play Integrity API); server-side validation |
| T2 | Модификация локальной БД | Root device, SQLite editor | Low | Данные в SQLite = только кэш, не истина. Истина = Firestore |
| T3 | Подмена контента Firestore | Утечка Admin SDK key | Low | **Никогда не использовать Admin SDK в клиенте** |
| T4 | Манипуляция Remote Config | Нет (read-only) | None | Remote Config = read-only для клиента |

**Меры:**
- Play Integrity API для проверки подлинности приложения
- Firestore Security Rules — клиент может ЧИТАТЬ только свои данные, не писать системные поля

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      // Cannot write subscription status directly
      allow write: if !('subscriptionStatus' in request.resource.data);
    }
    // Content is read-only for all authenticated users
    match /content/{document=**} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

---

### R — Repudiation (Отказ от авторства)

| ID | Угроза | Меры защиты |
|----|--------|-------------|
| R1 | Пользователь отрицает покупку | Firebase + Google Play receipt сохраняется на сервере |
| R2 | Спор о показанном контенте | DailyReading сохраняется в Firestore с timestamp |

---

### I — Information Disclosure (Утечка информации)

| ID | Угроза | Вектор | Меры защиты |
|----|--------|--------|-------------|
| I1 | PII в логах/краш-репортах | Crashlytics auto-collect | **Маскировать PII перед отправкой; кастомные ключи без email** |
| I2 | Firebase API key в APK | Декомпиляция | Нормально — API key публичный; защита через Firebase Rules |
| I3 | Секреты в исходнике | git history | Pre-commit hook + .gitignore; secrets только в CI environment |
| I4 | Данные пользователя между аккаунтами | Multi-user device | Данные привязаны к Firebase UID, изолированы |
| I5 | Передача данных третьим сторонам | AdMob SDK | Декларировать в Data Safety; минимизировать передаваемые данные |

**Меры:**
```dart
// Crashlytics — не логировать PII
FirebaseCrashlytics.instance.setCustomKey('user_type', isPremium ? 'premium' : 'free');
// НЕ логировать: email, имя, дату рождения, устройство (только агрегированно)

// Secure storage для чувствительных данных
await _secureStorage.write(key: 'auth_token', value: token);
// НЕ SharedPreferences для токенов!
```

---

### D — Denial of Service (Отказ в обслуживании)

| ID | Угроза | Вектор | Меры защиты |
|----|--------|--------|-------------|
| D1 | Firebase quota exhaustion | Хакер / бот с множеством аккаунтов | Firebase App Check; rate limiting в Security Rules |
| D2 | Firestore read bomb | Безлимитные reads от одного клиента | Firestore Rules с rate limits; client-side caching (7d) |
| D3 | Cloud Functions timeout/cost | Вредоносные вызовы | Firebase App Check обязателен для Functions |

**Меры:**
```javascript
// Firestore Rules — rate limiting (simplified)
match /users/{userId}/readings/{readingId} {
  allow create: if request.auth.uid == userId
    && request.time > resource.data.createdAt + duration.value(1, 'd');
    // Не более 1 чтения в день
}
```

---

### E — Elevation of Privilege (Повышение привилегий)

| ID | Угроза | Вектор | Меры защиты |
|----|--------|--------|-------------|
| E1 | Anonymous → Premium без оплаты | Манипуляция локальным state | Subscription status только из Cloud Functions |
| E2 | Запись в системные коллекции | Firestore direct write | Security Rules: клиент пишет только в /users/{ownUid}/ |
| E3 | Вызов admin Cloud Functions | Неавторизованный вызов | Functions проверяют Firebase Auth token + admin claim |

---

## ПРАКТИЧЕСКИЕ МЕРЫ (IMPLEMENTATION CHECKLIST)

### Обязательные (P0):
- [ ] `firebase_app_check` — подключить и проверять на Functions
- [ ] `flutter_secure_storage` — для auth tokens
- [ ] Firestore Security Rules — написать и протестировать с Firebase Emulator
- [ ] Cloud Functions: server-side purchase verification (ОБЯЗАТЕЛЬНО)
- [ ] `.gitignore` — google-services.json, GoogleService-Info.plist, .env
- [ ] Pre-commit hook: запрет коммита файлов с секретами
- [ ] Crashlytics: кастомные ключи без PII

### Рекомендуемые (P1):
- [ ] Play Integrity API — проверка подлинности APK
- [ ] Obfuscation (ProGuard/R8) — затруднить reverse engineering
- [ ] Certificate Transparency monitoring
- [ ] Firebase App Check — для всех Firebase сервисов

### Опциональные (P2):
- [ ] Root/jailbreak detection (но не блокировать — нарушает UX)
- [ ] Server-side audit log всех purchase events
- [ ] Anomaly detection на подозрительные паттерны (много аккаунтов с одного IP)

---

## DATA CLASSIFICATION

| Data Type | Classification | Storage | Encryption | Retention |
|-----------|---------------|---------|------------|-----------|
| Firebase UID | Internal | Firestore | Firebase at-rest | Account lifetime |
| Birth date | PII | Firestore /users/{uid} | Firebase at-rest | Account lifetime |
| Gender | PII (optional) | Firestore /users/{uid} | Firebase at-rest | Account lifetime |
| Birth time | PII (optional) | Firestore /users/{uid} | Firebase at-rest | Account lifetime |
| Birth place | PII (optional) | Firestore /users/{uid} | Firebase at-rest | Account lifetime |
| Daily Reading | User data | Firestore + SQLite | Firebase at-rest | 90 days |
| Subscription status | Financial | Firestore (server-set) | Firebase at-rest | Account lifetime |
| Push token | Technical | Firestore + FCM | Firebase at-rest | Until refresh |
| Analytics events | Aggregated | Firebase Analytics | Firebase | 14 months |
| Crash reports | Technical | Crashlytics | Firebase | 90 days |

---

## PRIVACY-BY-DESIGN CHECKLIST

- [ ] Data minimization: не собираем то, что не нужно
- [ ] Purpose limitation: данные используются только для заявленных целей
- [ ] Storage limitation: retention policy задана
- [ ] User rights: delete account = delete all user data
- [ ] Age verification: блокировать пользователей < 13 лет (COPPA)
- [ ] Consent: явное согласие перед сбором данных в onboarding

---

*Threat model ревьюируется перед Stage 5 (Quality & Security)*
