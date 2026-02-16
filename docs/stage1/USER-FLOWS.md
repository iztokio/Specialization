# USER FLOWS & INFORMATION ARCHITECTURE — AstraVia
**Version:** 0.1.0 | **Date:** 2026-02-16

---

## 1. USER PERSONAS

### Persona A: "Maya" (Core user, P0)
- Age: 28, Female, Brazil (PT)
- Uses: Astrology apps daily as morning ritual
- Goals: Quick daily dose of cosmic guidance, feels personalized
- Frustration: Generic content, cluttered UI, aggressive ads
- Device: Mid-range Android, 4G
- Session: 2-3 min every morning

### Persona B: "Andrei" (Secondary, P1)
- Age: 34, Male, Russia (RU)
- Uses: Occasional horoscope check, skeptical but curious
- Goals: Entertainment, something to share with partner
- Frustration: Too mystical / cheesy UI, long onboarding
- Device: Flagship Android
- Session: 5 min weekly, longer on weekends

### Persona C: "Sofia" (Casual, P2)
- Age: 22, Female, Spain (ES)
- Uses: Social discovery, first horoscope app
- Goals: Fun, pretty UI, shareable content
- Frustration: Paywall too early, confusing Tarot meanings
- Device: iPhone (iOS-ready architecture)
- Session: 10 min first time, then sporadic

---

## 2. INFORMATION ARCHITECTURE

```
AstraVia
│
├── ONBOARDING (first-time only)
│   ├── Welcome Screen
│   ├── Birth Date Picker
│   ├── Personalization (Optional) — gender / birth time / birth place
│   ├── Disclaimer Accept (REQUIRED)
│   └── Notification Setup
│
├── MAIN APP (Shell with Bottom Nav)
│   │
│   ├── 🌟 TODAY (tab 1 — home)
│   │   ├── Horoscope of the Day (full text)
│   │   │   └── Category pills: General / Love / Work / Wellbeing
│   │   ├── Card of the Day (1 card — free)
│   │   │   ├── Card reveal animation
│   │   │   ├── Upright/Reversed meaning
│   │   │   └── [PREMIUM gate] 3-Card Spread
│   │   └── Disclaimer (always visible, subtle)
│   │
│   ├── 🃏 TAROT (tab 2)
│   │   ├── Quick Draw (1 card — free)
│   │   ├── Three-Card Spread (Past/Present/Future — PREMIUM)
│   │   └── Card Library (browse all 78 cards — PREMIUM)
│   │
│   ├── 📖 HISTORY (tab 3)
│   │   ├── Timeline (last 7 days — free / 90 days — premium)
│   │   └── Day Detail (full reading for selected day)
│   │
│   └── ⚙️ SETTINGS (tab 4)
│       ├── My Profile
│       │   ├── Edit birth date / gender / time / place
│       │   └── Zodiac sign display
│       ├── Notifications
│       │   ├── Enable/disable
│       │   └── Time picker
│       ├── Appearance
│       │   ├── Theme (Dark / Light / System)
│       │   └── Language (EN / ES / PT / RU)
│       ├── Subscription
│       │   ├── Current status
│       │   ├── Manage subscription (link to Play Store)
│       │   └── Restore purchases
│       └── About
│           ├── Privacy Policy
│           ├── Terms of Service
│           ├── Disclaimer
│           └── Version / Licenses
│
├── PAYWALL (modal, from premium gates)
│   ├── Value props
│   ├── Monthly / Yearly toggle
│   ├── CTA (Subscribe / Start Trial)
│   └── Restore purchases
│
└── ZODIAC INFO (from Today screen)
    └── Zodiac sign profile page
```

---

## 3. USER FLOW MAPS

### Flow 1: First Launch → First Horoscope (MVP Critical)
```
App Install
    │
    ▼
Splash (1.5s) → logo animation
    │
    ▼
Welcome Screen
    │ "Begin Your Journey" [CTA]
    ▼
Birth Date Screen
    │ Date picker + "Continue"
    │ [Skip not available — required]
    ▼
Personalization Screen (optional fields)
    │ "Continue" or "Skip"
    ▼
Disclaimer Screen (REQUIRED)
    │ User must scroll to bottom
    │ "I Understand — For Entertainment Only" [CTA]
    │ [Cannot proceed without accepting]
    ▼
Notification Prompt
    │ "Enable" (OS permission dialog) or "Not Now"
    ▼
TODAY SCREEN ← FIRST VALUE DELIVERED!

⏱️ Target: ≤ 90 seconds from install to first horoscope
```

### Flow 2: Daily Return (D2+)
```
Tap notification OR open app
    │
    ▼
Splash (0.3s max — from cache)
    │
    ▼
TODAY SCREEN (instant — from cache)
    │ Horoscope already loaded
    │ Card of day already drawn (deterministic)
    ▼
User reads → closes or explores

⏱️ Target: ≤ 1 second to content from cached state
```

### Flow 3: Premium Unlock
```
User taps premium feature (e.g., 3-card spread)
    │
    ▼
Premium Gate Modal
    │ "This is a Premium feature"
    │ "Unlock Premium" [CTA] or "Maybe Later" [dismiss]
    ▼
Paywall Screen (modal sheet, slides up)
    │ Value props → Price → CTA
    │ "Start Free Trial" or "Subscribe Now"
    ▼
Google Play Billing (native dialog)
    │
    ├─[Success]──► Cloud Function verifyPurchase
    │                   │
    │                   ▼
    │             Firestore subscription status updated
    │                   │
    │                   ▼
    │             Premium features unlocked
    │
    └─[Failed]───► Error toast → Stay on Paywall

⏱️ Paywall → Purchase confirmation: ≤ 5 seconds (after Play dialog)
```

### Flow 4: Tarot Card Draw (Free)
```
TODAY Screen or TAROT tab
    │ "Draw Your Card"
    ▼
Card face-down (animated)
    │ "Tap to reveal" or auto-reveal
    ▼
Card flip animation (Lottie, 0.8s)
    │
    ▼
Card revealed: name + position + meaning
    │ (Deterministic: same card if re-opened same day)
    │
    ▼ [Optional]
"Learn more" → Card detail / Library [PREMIUM gate]
```

### Flow 5: Restore Purchases
```
Settings → Subscription → Restore Purchases
    │
    ▼
Cloud Function restorePurchases called
    │
    ├─[Found]────► Status updated → "Premium restored!" toast
    │
    └─[Not found]─► "No active subscription found" dialog
                      │
                      └──► Paywall (to subscribe)
```

---

## 4. SCREEN CONTENT SPECIFICATIONS

### Screen 1: Welcome
```
┌─────────────────────────────────────┐
│                                     │
│           [Star animation]          │
│                                     │
│      ✦ ASTRAVIA ✦                   │
│    Your stars. Your story.          │
│         Every day.                  │
│                                     │
│                                     │
│  ┌─────────────────────────────┐   │
│  │    Begin Your Journey       │   │
│  └─────────────────────────────┘   │
│                                     │
│   Already have an account? Sign in  │
│                                     │
│  [Entertainment purposes only]      │
└─────────────────────────────────────┘
```

**Content:**
- Hero: Lottie animation (floating stars, orbiting rings)
- H1: "AstraVia" (Cinzel Decorative, celestial gold)
- H2: Tagline (Raleway Light)
- CTA: "Begin Your Journey" (full-width, gold background)
- Secondary: "Sign in" link (for returning users)
- Footer: mini disclaimer (12px, muted)

---

### Screen 2: Birth Date
```
┌─────────────────────────────────────┐
│  ←                                  │
│                                     │
│    "When Were You Born?"            │
│    "Your sign personalizes          │
│     your daily reading."            │
│                                     │
│  ┌─────────────────────────────┐   │
│  │    Month    Day    Year     │   │
│  │    [  6  ]  [ 15 ] [1995]  │   │
│  └─────────────────────────────┘   │
│                                     │
│    ♊ Gemini  ← live preview        │
│                                     │
│  ┌─────────────────────────────┐   │
│  │         Continue            │   │
│  └─────────────────────────────┘   │
│                                     │
│   Min age: 13 years (COPPA)         │
└─────────────────────────────────────┘
```

**Logic:**
- iOS-style scroll picker (3 columns)
- Live zodiac sign preview as user scrolls
- Validate: not future, not < 13 years old
- Show zodiac symbol + name when valid

---

### Screen 3: Personalization (Optional)
```
┌─────────────────────────────────────┐
│  ←                                  │
│                                     │
│    "Tell Us More"                   │
│    "(Optional — skip anytime)"      │
│                                     │
│    Gender           [dropdown] ▼    │
│    Birth Time       [__:__] ⏱️      │
│    Birth Place      [City...] 🔍    │
│                                     │
│    ─────── Why we ask ──────        │
│    These optional details add       │
│    depth to your readings.          │
│    Not required. All data is        │
│    stored securely.                 │
│                                     │
│  ┌─────────────────────────────┐   │
│  │         Continue            │   │
│  └─────────────────────────────┘   │
│      [Skip this step]               │
└─────────────────────────────────────┘
```

---

### Screen 4: Disclaimer (REQUIRED, cannot skip)
```
┌─────────────────────────────────────┐
│  ←                                  │
│                                     │
│    ⚠️ Entertainment Only            │
│                                     │
│  ┌───────────────────────────────┐  │
│  │  This app is for              │  │
│  │  ENTERTAINMENT PURPOSES ONLY. │  │
│  │                               │  │
│  │  Horoscopes and Tarot         │  │
│  │  readings do not constitute   │  │
│  │  medical, financial, legal,   │  │
│  │  or any other professional    │  │
│  │  advice.                      │  │
│  │                               │  │
│  │  Results are generated for    │  │
│  │  entertainment and should     │  │
│  │  not be used as the basis     │  │
│  │  for real-world decisions.    │  │
│  └───────────────────────────────┘  │
│                                     │
│  [Button disabled until scrolled]   │
│  ┌─────────────────────────────┐   │
│  │ I Understand — Entertainment│   │
│  │          Only               │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

**UX Rules:**
- CTA button is DISABLED until user scrolls to bottom
- Cannot tap back without accepting (or show "Exit" option)
- Text is readable (min 14px, contrast ratio ≥ 7:1)

---

### Screen 5: Today (Main screen)
```
┌─────────────────────────────────────┐
│  AstraVia        🔔  👤            │
│                                     │
│  Monday, February 16               │
│  ♊ GEMINI                           │
│                                     │
│  ╔═══════════════════════════════╗  │
│  ║  YOUR HOROSCOPE               ║  │
│  ║                               ║  │
│  ║  Today, Mercury aligns with   ║  │
│  ║  Jupiter, bringing creative   ║  │
│  ║  energy to your path...       ║  │
│  ║                               ║  │
│  ║  [General] [Love] [Work]      ║  │
│  ║  [Wellbeing]                  ║  │
│  ╚═══════════════════════════════╝  │
│                                     │
│  ─── CARD OF THE DAY ───           │
│                                     │
│  ╔═══════════════════════════════╗  │
│  ║   [Card Image]    The Star   ║  │
│  ║                   ↑ Upright  ║  │
│  ║   Hope · Renewal · Faith     ║  │
│  ╚═══════════════════════════════╝  │
│                                     │
│  [🔒 3-Card Spread — Go Premium]   │
│                                     │
│  ⭐ For entertainment only          │
│─────────────────────────────────────│
│  🌟 Today  🃏 Tarot  📖  ⚙️       │
└─────────────────────────────────────┘
```

**UX Notes:**
- Horoscope card: expandable (tap to see full text)
- Category pills: General (default) / Love / Work / Wellbeing
- Card of day: single card, upright or reversed
- 3-card spread: locked, tapping shows paywall
- Disclaimer footer: always visible, subtle

---

### Screen 6: Paywall
```
┌─────────────────────────────────────┐
│                    ✕               │
│                                     │
│  ✦  UNLOCK YOUR FULL POTENTIAL  ✦  │
│                                     │
│  ✓  3-Card Tarot Spreads           │
│  ✓  90 Days Reading History        │
│  ✓  Detailed Card Meanings         │
│  ✓  Love, Work & Wellbeing         │
│  ✓  No Ads                          │
│                                     │
│  ┌─────────────┐  ┌─────────────┐  │
│  │   MONTHLY   │  │   YEARLY ★  │  │
│  │   $4.99/mo  │  │  $29.99/yr  │  │
│  │             │  │  Save 50%   │  │
│  └─────────────┘  └─────────────┘  │
│          [Yearly selected]          │
│                                     │
│  ┌─────────────────────────────┐   │
│  │   Start 3-Day Free Trial    │   │
│  └─────────────────────────────┘   │
│                                     │
│  [Restore Purchases]               │
│                                     │
│  Cancel anytime. Auto-renews.      │
│  Entertainment only. No guarantees.│
└─────────────────────────────────────┘
```

**Paywall Copy Rules:**
- Benefits first, price second
- Annual plan highlighted as default (Best Value)
- Trial CTA if trial available, else direct subscribe
- Legal text visible (not hidden)
- Disclaimer visible

---

## 5. NAVIGATION PATTERNS

### Bottom Navigation Bar
| Tab | Icon | Label EN | Label RU | Label ES | Label PT |
|-----|------|----------|----------|----------|----------|
| Today | ⭐ Star | Today | Сегодня | Hoy | Hoje |
| Tarot | 🃏 Card | Tarot | Таро | Tarot | Tarot |
| History | 📖 Book | Readings | Расклады | Lecturas | Leituras |
| Settings | ⚙️ Gear | Settings | Настройки | Ajustes | Config |

### Navigation Rules
- No deep navigation stacks (max 2 levels)
- Back button always visible on sub-screens
- Paywall = modal bottom sheet (not full screen nav)
- Modals: swipe down to dismiss

---

## 6. UX MICRO-INTERACTIONS

| Moment | Animation | Duration | Sound |
|--------|-----------|----------|-------|
| Card reveal | Flip (3D rotation) | 600ms | None (optional haptic) |
| Horoscope load | Fade in + shimmer | 300ms | None |
| Premium unlock | Gold particle burst | 800ms | None |
| Notification permission | Slide up modal | 400ms | None |
| Paywall open | Bottom sheet slide | 350ms | None |
| Error state | Shake | 200ms | None |

---

## 7. ACCESSIBILITY REQUIREMENTS

| Requirement | Spec |
|------------|------|
| Min tap target | 44×44dp (follows Material 3) |
| Text contrast | ≥ 4.5:1 (WCAG AA) for body, 3:1 for large text |
| Min font size | 12sp (never smaller for production) |
| Screen reader | All interactive elements have contentDescription |
| Color-only info | Never use color alone to convey meaning (add icon/text) |
| Reduced motion | Respect system accessibility setting |
| Font scaling | UI must not break at 1.5× system font scale |

---

*Stage 1 UX document v0.1.0 — Gate Audit follows*
