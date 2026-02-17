# RISK LIST — Horoscope & Tarot App
**Version:** 0.1.0 | **Date:** 2026-02-16

Format: `ID | Risk | Probability | Impact | Severity | Mitigation | Owner`

---

## CATEGORY 1: LEGAL & COMPLIANCE RISKS

| ID | Risk | P | I | Sev | Mitigation |
|----|------|---|---|-----|------------|
| L-01 | Play Store rejection: content "harmful beliefs" policy | Med | High | HIGH | Explicit entertainment disclaimer on all screens; category=Entertainment; no "predictions" language |
| L-02 | Asset copyright infringement (Tarot card images) | Low | Critical | HIGH | Use only CC0/SIL-licensed assets; document every source; no scraped images |
| L-03 | GDPR/privacy violation (EU users) | Med | High | HIGH | Minimal PII collection; Privacy Policy; consent screen; Firebase EU region |
| L-04 | Medical/financial advice claims | Low | Critical | HIGH | No advisory language; disclaimer on every reading result; review all copy |
| L-05 | Trademark conflict with app name | Med | Med | MED | Trademark search before branding; multiple name options |
| L-06 | COPPA compliance (under 13) | Low | High | MED | Age gate in onboarding (born after 2013 = block) |

---

## CATEGORY 2: TECHNICAL RISKS

| ID | Risk | P | I | Sev | Mitigation |
|----|------|---|---|-----|------------|
| T-01 | Firebase quota exceeded (free tier) | Med | High | HIGH | Aggressive client-side caching; Firestore rules to minimize reads; monitoring alerts |
| T-02 | Google Play Billing API breaking change | Low | High | MED | Use official in_app_purchase Flutter plugin; pin plugin version; monitor changelogs |
| T-03 | Purchase verification bypass (client tampering) | Med | High | HIGH | Server-side validation via Firebase Functions (mandatory, not optional) |
| T-04 | Offline data corruption / migration failure | Med | Med | MED | Drift migrations with version tracking; e2e migration tests |
| T-05 | Cold start > 3 sec (performance) | Med | Med | MED | Lazy loading; defer non-critical init; cache today's content |
| T-06 | Push notification delivery failure | Med | Low | LOW | FCM is reliable; log delivery metrics; fallback to in-app prompt |
| T-07 | Flutter version breaking changes | Low | Med | MED | Pin Flutter version; use Renovate bot for controlled updates |
| T-08 | 78 Tarot card images too large (APK/AAB size) | High | Med | MED | Compress to WebP ≤ 100KB each; lazy load; CDN delivery via Firebase Storage |
| T-09 | Daily content seed collision (same card 2 days) | Med | Low | LOW | DailyGenerationRule with exclusion window (≥3 days between repeats) |
| T-10 | Firebase Auth token expiry during purchase | Low | High | MED | Handle token refresh before any purchase call |

---

## CATEGORY 3: PRODUCT & UX RISKS

| ID | Risk | P | I | Sev | Mitigation |
|----|------|---|---|-----|------------|
| P-01 | Low D7 retention (no daily hook) | High | High | CRIT | Push notifications + streak system; personalized content |
| P-02 | Paywall too aggressive (early churn) | Med | High | HIGH | Show value first (full Today screen free); paywall only on premium features |
| P-03 | Content feels repetitive after 2 weeks | High | Med | HIGH | Template engine with seeds; seasonal variations; LLM generation v2 |
| P-04 | Onboarding abandonment > 30% | Med | High | HIGH | ≤3 steps; optional fields skippable; immediate value |
| P-05 | Low ad revenue (insufficient traffic) | Med | Low | LOW | Subscription is primary; ads are supplementary |
| P-06 | Poor localization quality (ES/PT) | Med | Med | MED | Professional translation for store listing + key copy; community translation v2 |

---

## CATEGORY 4: MONETIZATION RISKS

| ID | Risk | P | I | Sev | Mitigation |
|----|------|---|---|-----|------------|
| M-01 | Google Play refund abuse | Low | Med | MED | Server-side revocation handling; grace period logic |
| M-02 | Subscription cancellation spikes | Med | Med | MED | Win-back notifications; pause subscription option |
| M-03 | AdMob account suspension | Low | High | MED | Follow AdMob policies strictly; no click incentives; frequency caps |
| M-04 | Low subscription ARPU | High | Med | HIGH | A/B test pricing; annual plan incentive; trial period |

---

## CATEGORY 5: SECURITY RISKS (Threat Model)

| ID | Threat | Attack Vector | Impact | Mitigation |
|----|--------|---------------|--------|------------|
| S-01 | Premium unlock bypass | APK reverse engineering | Revenue loss | Server-side subscription status; no client-only premium flag |
| S-02 | Firebase API key exposure | Decompiled APK | Firestore abuse | Firebase Security Rules restrict access; API key restrictions in Google Console |
| S-03 | PII leakage via logs | Debug builds / Crashlytics | Privacy violation | Disable verbose logging in release; mask/exclude PII from crash reports |
| S-04 | Man-in-the-middle (content injection) | Network intercept | Content manipulation | HTTPS only; Firebase SDK uses certificate pinning |
| S-05 | Fake purchase receipt | Crafted purchase token | Revenue loss | Server-side Google Play API validation (mandatory) |
| S-06 | Secrets in client APK | Static analysis | API abuse | No secrets in Flutter code; all sensitive ops via Cloud Functions |
| S-07 | SQL injection (local DB) | Malicious input | Data corruption | Drift ORM with parameterized queries; no raw SQL from user input |

---

## RISK HEAT MAP

```
          LOW IMPACT  MED IMPACT  HIGH IMPACT  CRITICAL IMPACT
HIGH P:      P-05        T-08          P-01           -
MED P:       T-06        P-02         L-01,T-01      S-01
LOW P:         -         T-07         T-02,M-03       L-02
```

**TOP 5 RISKS TO MONITOR:**
1. `P-01` — Low retention (mitigation: push + streak)
2. `L-01` — Play Store rejection (mitigation: disclaimer + content review)
3. `T-01` — Firebase quota (mitigation: caching strategy)
4. `S-01` — Premium bypass (mitigation: server validation — MANDATORY)
5. `L-02` — Asset copyright (mitigation: license documentation)

---

*Риски ревьюируются перед каждым Gate Audit.*
