# ROADMAP — Horoscope & Tarot App
**Last Updated:** 2026-02-16

---

## LEGEND
- `[P0]` — Critical (blocker for release)
- `[P1]` — High (strongly recommended)
- `[P2]` — Medium (nice to have)
- `[P3]` — Low (post-launch)

---

## STAGE 0 — FOUNDATION & SETUP
**Goal:** Репозиторий, стек, PRD, окружение, CI скелет.
**Status:** IN PROGRESS

- [x] PRD-Lite
- [x] Roadmap
- [x] Risk List
- [x] Success Criteria
- [ ] Brand Identity Research (marketing)
- [ ] Flutter project init
- [ ] GitHub Actions CI skeleton (lint + test + build)
- [ ] Firebase project setup instructions
- [ ] Threat model
- [ ] GATE AUDIT

---

## STAGE 1 — UX & PRODUCT DESIGN
**Goal:** User flows, IA, wireframes, тексты экранов, дисклеймеры.

- [ ] User journey maps (3 personas)
- [ ] Information Architecture diagram
- [ ] Screen flows (Figma-compatible wireframes in text/pseudo-format)
- [ ] UI Kit: цвета, шрифты, компоненты
- [ ] Onboarding copy (4 языка)
- [ ] Paywall copy (4 языка)
- [ ] Disclaimer texts (4 языка, legal-safe)
- [ ] Push notification templates
- [ ] GATE AUDIT

---

## STAGE 2 — ARCHITECTURE & DATA
**Goal:** Модульная архитектура, state management, схема БД, API контракт.

- [ ] Module structure diagram (Clean Architecture + Feature-first)
- [ ] State management setup (Riverpod)
- [ ] Database schema (Drift/SQLite) with migrations
- [ ] Firestore schema + security rules
- [ ] Content versioning system
- [ ] Offline strategy (cache-first)
- [ ] API contract (Firebase Functions endpoints)
- [ ] GATE AUDIT

---

## STAGE 3 — MVP IMPLEMENTATION
**Goal:** Рабочее приложение: онбординг, today, tarot, история, аналитика.

**Sprint 3.1 — Core Shell**
- [ ] Navigation (GoRouter)
- [ ] Theme system (light/dark)
- [ ] Localization setup (4 languages)
- [ ] Firebase initialization

**Sprint 3.2 — Onboarding**
- [ ] Birth date picker
- [ ] (Optional) Gender/time/place input
- [ ] Disclaimer accept screen
- [ ] Zodiac sign calculation
- [ ] Notification time setup

**Sprint 3.3 — Today Screen**
- [ ] Daily horoscope display
- [ ] Tarot card draw (1 card, free)
- [ ] Offline cache logic
- [ ] Daily seed (deterministic by date+sign)

**Sprint 3.4 — History**
- [ ] History list (7 days)
- [ ] Local SQLite storage
- [ ] Offline-first reads

**Sprint 3.5 — Settings & Profile**
- [ ] Notification settings
- [ ] Theme toggle
- [ ] Language selector
- [ ] Zodiac display
- [ ] Edit profile

**Sprint 3.6 — Analytics & Crash**
- [ ] Firebase Analytics events (10 key events)
- [ ] Crashlytics setup
- [ ] Performance Monitoring

**Sprint 3.7 — Content Pipeline**
- [ ] 78 Tarot cards (metadata + images)
- [ ] Horoscope templates (12 signs × 365 days OR template engine)
- [ ] Remote Config for content versions
- [ ] Content update mechanism (no app release needed)

- [ ] Unit tests (core logic ≥ 70%)
- [ ] Widget tests (key screens)
- [ ] GATE AUDIT

---

## STAGE 4 — MONETIZATION
**Goal:** Billing, paywall, серверная валидация, premium gates, ads.

- [ ] Google Play Billing integration (in_app_purchase)
- [ ] Subscription products setup (monthly/yearly)
- [ ] Paywall screen (value → price → CTA)
- [ ] Premium gates (3-card spread, 90-day history, etc.)
- [ ] Firebase Functions: purchase verification
- [ ] Grace period handling
- [ ] Restore purchases
- [ ] AdMob integration (banner + interstitial)
- [ ] Ad frequency cap (≥7 days use, not subscriber)
- [ ] A/B test paywall (Remote Config)
- [ ] Test purchases (sandbox)
- [ ] GATE AUDIT

---

## STAGE 5 — QUALITY, SECURITY & COMPLIANCE
**Goal:** Тест-план, безопасность, privacy, лицензии ассетов.

- [ ] Full test plan document
- [ ] Integration tests (key user flows)
- [ ] Performance audit (startup time, memory, battery)
- [ ] Security audit (threat model validation)
- [ ] Privacy Policy (EN + RU + ES + PT)
- [ ] Terms of Service
- [ ] Google Play Data Safety form filled
- [ ] All asset licenses documented
- [ ] Accessibility audit (contrast, font size, tap targets)
- [ ] GATE AUDIT

---

## STAGE 6 — RELEASE PREPARATION
**Goal:** AAB, signing, Play Console, store listing.

- [ ] Release build configuration
- [ ] App signing (Play App Signing)
- [ ] AAB generation
- [ ] Store listing assets:
  - [ ] App icon (512×512)
  - [ ] Feature graphic (1024×500)
  - [ ] Screenshots (min 2, max 8 per device type)
  - [ ] Short description (80 chars, 4 langs)
  - [ ] Full description (4000 chars, 4 langs)
- [ ] Content rating questionnaire
- [ ] Pre-launch report review
- [ ] Release checklist sign-off
- [ ] GATE AUDIT

---

## STAGE 7 — POST-LAUNCH (P2/P3)
**Goal:** Метрики, A/B тесты, контент-операции.

- [ ] Retention dashboard (Firebase + custom)
- [ ] A/B paywall variants (3 variants)
- [ ] Content operations playbook
- [ ] LLM content generation (with moderation)
- [ ] iOS build + TestFlight
- [ ] Streak feature
- [ ] Compatibility readings (P3)
- [ ] Numerology module (P3)

---

## CURRENT MILESTONE: STAGE 0
**Estimated completion:** Stage 0 = current session
**Next milestone:** Stage 1 (UX/Design)
