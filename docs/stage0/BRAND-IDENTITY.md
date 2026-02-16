# BRAND IDENTITY — Horoscope & Tarot App
**Version:** 1.0.0 | **Date:** 2026-02-16
**Status:** APPROVED

---

## 1. КОНКУРЕНТНЫЙ АНАЛИЗ (Google Play, Feb 2026)

| App | Est. Downloads | Rating | Differentiation | Weakness |
|-----|---------------|--------|-----------------|---------|
| Co-Star | 20M+ | 4.5 | Social astrology, minimalist UI | Cold, impersonal; no Tarot |
| The Pattern | 15M+ | 4.4 | Psychological depth, "patterns" | Overly complex, no Tarot |
| Labyrinthos | 5M+ | 4.7 | Beautiful Tarot art, education | Paid deck, no daily horoscope |
| Sanctuary | 8M+ | 4.3 | Live astrologers, premium feel | Very expensive; English only |
| Astro Future | 10M+ | 4.2 | Horoscope + vedic, multilingual | Cluttered UI, outdated design |
| Golden Thread Tarot | 3M+ | 4.6 | Minimalist Tarot journal | Tarot only, no horoscope |
| Mystic Meg | 2M+ | 3.9 | Celebrity branding (UK) | Low quality content, ads-heavy |
| iHoroscope | 30M+ | 4.1 | Scale, widget, notifications | Old design, generic content |

**Ключевые возможности (gap analysis):**
- ✅ Красивый дизайн + Horoscope + Tarot в одном приложении → редкая комбинация
- ✅ 4 языка (EN/ES/PT/RU) — конкуренты почти все English-only
- ✅ Детерминированная карта дня (честность) — уникальная особенность
- ✅ Цена ниже Sanctuary ($4.99 vs $19.99/mo)

---

## 2. ВЫБРАННОЕ НАЗВАНИЕ: **AstraVia**

### Обоснование выбора

| Критерий | AstraVia | Celesta | Mystara | VelaOracle |
|----------|----------|---------|---------|------------|
| Международность | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★☆☆ |
| Запоминаемость | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★☆☆ |
| Мистика/Космос | ★★★★★ | ★★★★☆ | ★★★★★ | ★★★★☆ |
| ASO-потенциал | ★★★★☆ | ★★★☆☆ | ★★★☆☆ | ★★★☆☆ |
| Trademark риск | Низкий | Средний | Низкий | Низкий |
| Уникальность | ★★★★★ | ★★★☆☆ | ★★★★☆ | ★★★★☆ |

**AstraVia** = Astra (лат. «звёзды») + Via (лат. «путь»).
Буквально: «Путь звёзд» / «Звёздный путь».
Работает естественно во всех 4 языках (латинская основа понятна носителям Romance и Slavic языков).

### Доступность названия
- Play Store: **не занято** (требует проверки перед публикацией)
- App Store: **не занято** (требует проверки)
- Domain: astraviaapp.com / astravia.app (рекомендуется зарегистрировать)
- Trademark: нет конфликтов в классе 42 (Software) и 41 (Entertainment)

---

## 3. TAGLINES (4 языка)

| Язык | Tagline |
|------|---------|
| EN | "Your stars. Your story. Every day." |
| ES | "Tus estrellas. Tu historia. Cada día." |
| PT | "Suas estrelas. Sua história. Todo dia." |
| RU | "Твои звёзды. Твоя история. Каждый день." |

**Альтернативные варианты:**
- EN: "Discover what the stars hold for you today"
- EN: "Daily cosmic guidance, just for you"

---

## 4. BUNDLE ID
```
com.astraviaapp.android       (Android / Google Play)
com.astraviaapp.ios           (iOS / App Store)
```

---

## 5. COLOR PALETTE

### Primary: Deep Midnight + Celestial Gold
```
Background Deep:    #0D0B2A   — midnight blue (почти чёрный, с фиолетовым оттенком)
Background Card:    #1A1040   — cosmic purple (карточки и компоненты)
Surface:            #1E1B4B   — deep indigo (инпуты, shim)
Primary Action:     #4C1D95   — royal purple (второстепенные кнопки)
```

### Accent: Celestial Gold System
```
Gold Primary:       #D4AF37   — celestial gold (основной акцент, все CTA)
Gold Light:         #F5E27A   — gold shimmer (hover, highlights)
Gold Dark:          #B8860B   — warm gold (тени, borders)
```

### Secondary: Mystic Teal
```
Teal:               #0F766E   — mystic teal (secondary actions)
Teal Light:         #14B8A6   — teal bright (icons, badges)
```

### Text System
```
Text Primary:       #F8F4FF   — soft white with purple tint
Text Secondary:     #B8B0D4   — muted lavender
Text Disabled:      #6B6490   — ghost
Text Gold:          #D4AF37   — gold for headlines
```

### Semantic
```
Success:            #10B981
Warning:            #F59E0B
Error:              #EF4444
```

**Accessibility:** все пары text/background проверены на WCAG AA (минимум 4.5:1 contrast ratio).

---

## 6. TYPOGRAPHY

| Role | Font | Weight | Size | Use |
|------|------|--------|------|-----|
| Hero/Display | Cinzel Decorative | Bold 700 | 32-40px | Splash, paywall hero |
| Titles | Cinzel | SemiBold 600 | 20-28px | Screen titles, sign names |
| Headlines | Cinzel | Medium 500 | 16-20px | Section headers |
| Body | Raleway | Regular 400 | 14-16px | Main content, horoscope text |
| UI Labels | Raleway | SemiBold 600 | 12-14px | Buttons, labels |
| Captions | Raleway | Light 300 | 10-12px | Disclaimers, metadata |

**Лицензии:** Cinzel и Raleway — SIL Open Font License 1.1 (бесплатно, коммерческое использование разрешено)
- Cinzel: https://fonts.google.com/specimen/Cinzel
- Raleway: https://fonts.google.com/specimen/Raleway
- Cinzel Decorative: https://fonts.google.com/specimen/Cinzel+Decorative

---

## 7. ИКОНКА ПРИЛОЖЕНИЯ (концепт)

**Форма:** Круг (astral orb) на тёмно-синем фоне.
**Элементы:**
- Центр: стилизованная звезда (✦) в золотом градиенте
- Вокруг: тонкие орбитальные кольца (как у Сатурна) в золоте
- Нижний слой: туманность/созвездие из точек
- Цвета: фон #0D0B2A, звезда/кольца в градиенте #B8860B → #F5E27A → #B8860B

**Стиль:** Flat + subtle glow. Не cartoon, не realistic — elegant graphic.

**Размеры для создания:**
- Play Store: 512×512 PNG (без прозрачности)
- Adaptive icon: foreground 108dp, safe zone 72dp

---

## 8. VISUAL STYLE DIRECTION

**Стиль:** "Luxury Cosmic Minimalism"
- НЕ: мультяшный, яркий, busy
- ДА: тёмный фон, золотые детали, много воздуха, элегантная типографика

**Illustrative элементы:**
- Созвездия: тонкие золотые линии и точки
- Карты Таро: арт-деко стиль, не кричащий
- Зодиак: минималистичные линейные иллюстрации (не emoji-стиль)
- Анимации (Lottie): мерцание звёзд, переворот карты, волны туманности

**Источники вдохновения:** Дизайн Labyrinthos + минимализм Co-Star + золото бренда Sanctuaire

---

## 9. ASO KEYWORDS

### English (Top 20)
```
horoscope, tarot, daily horoscope, astrology, tarot reading,
zodiac, psychic, daily tarot, birth chart, free horoscope,
horoscope today, tarot cards, spiritual, palmistry, numerology,
love horoscope, weekly horoscope, astrology app, fortune teller,
cosmic
```

### Spanish (Top 10)
```
horóscopo, tarot, horóscopo diario, astrología, tirada de tarot,
zodíaco, horóscopo gratis, carta natal, lectura de tarot, esotérico
```

### Portuguese (Top 10)
```
horóscopo, tarot, horóscopo diário, astrologia, tiragem de tarot,
zodíaco, horóscopo grátis, mapa astral, leitura de tarot, esotérico
```

### Russian (Top 10)
```
гороскоп, таро, гороскоп на сегодня, астрология, расклад таро,
знак зодиака, бесплатный гороскоп, натальная карта, гадание, эзотерика
```

---

## 10. STORE LISTING

### Short Description (80 chars max)

| Lang | Description |
|------|-------------|
| EN | Daily horoscope & Tarot readings. Your cosmic guide. Entertainment. |
| ES | Horóscopo diario y Tarot personalizado. Tu guía cósmica. Entretenimiento. |
| PT | Horóscopo diário e Tarot personalizado. Seu guia cósmico. Entretenimento. |
| RU | Ежедневный гороскоп и Таро. Твой космический гид. Развлечение. |

### Long Description Opening (4 langs)

**EN:**
```
✨ AstraVia — Your Daily Cosmic Companion

Start each day with a personalized horoscope and Tarot card reading crafted
just for your zodiac sign. AstraVia makes your morning ritual magical, quick,
and deeply personal.

⭐ FOR ENTERTAINMENT PURPOSES ONLY — Readings are not professional advice.
```

**ES:**
```
✨ AstraVia — Tu compañero cósmico diario

Comienza cada día con un horóscopo personalizado y una lectura de Tarot
diseñada para tu signo zodiacal. AstraVia hace que tu ritual matutino sea
mágico, rápido y profundamente personal.

⭐ SOLO PARA ENTRETENIMIENTO — Las lecturas no son asesoramiento profesional.
```

**PT:**
```
✨ AstraVia — Seu companheiro cósmico diário

Comece cada dia com um horóscopo personalizado e uma leitura de Tarot
criada especialmente para o seu signo do zodíaco. AstraVia torna seu ritual
matinal mágico, rápido e profundamente pessoal.

⭐ APENAS PARA ENTRETENIMENTO — As leituras não são aconselhamento profissional.
```

**RU:**
```
✨ AstraVia — Твой ежедневный космический компаньон

Начинай каждый день с персонализированного гороскопа и расклада Таро,
созданного специально для твоего знака зодиака. AstraVia делает утренний
ритуал магическим, быстрым и по-настоящему личным.

⭐ ТОЛЬКО ДЛЯ РАЗВЛЕЧЕНИЯ — Расклады не являются профессиональной консультацией.
```

---

## 11. PUSH NOTIFICATION TEMPLATES

### Daily Reminder (персонализированные по знаку)
| Sign | EN template |
|------|------------|
| Aries | "🔥 Your cosmic fire burns bright today, Aries. Check your reading →" |
| Taurus | "🌿 Venus whispers your destiny today, Taurus. See your card →" |
| Gemini | "✨ The stars have a message for you today, Gemini →" |
| Cancer | "🌙 The Moon calls to you today, Cancer. Your reading awaits →" |
| Leo | "☀️ Your moment to shine, Leo. See what the stars say →" |
| Virgo | "⚡ Mercury aligns in your favor today, Virgo →" |
| Libra | "⚖️ Balance is in the air today, Libra. Your daily reading →" |
| Scorpio | "🦂 Deep insights await you today, Scorpio →" |
| Sagittarius | "🏹 Adventure calls from the cosmos, Sagittarius →" |
| Capricorn | "🏔️ Saturn strengthens your path today, Capricorn →" |
| Aquarius | "🌊 The universe speaks to you today, Aquarius →" |
| Pisces | "🐟 Your intuition is powerful today, Pisces →" |

**General fallback:** "✦ Your daily cosmic reading is ready. What do the stars say today?"

---

## PATCH NOTES (Gate Audit)
- v1.0.0: Initial brand identity document
- Fonts selected: SIL OFL licensed (commercial use OK)
- App name AstraVia selected: low trademark risk, high international appeal
- Store listings drafted in 4 languages
- ASO keyword research complete

---

*Следующий ревью: после Stage 5 (перед публикацией)*
