# PRD-Lite — Horoscope & Tarot App
**Version:** 0.1.0
**Date:** 2026-02-16
**Status:** APPROVED FOR DEVELOPMENT

---

## 1. EXECUTIVE SUMMARY

Ежедневное персонализированное мобильное приложение: гороскоп + гадание на картах ТАРО.
**Ценностное предложение:** быстрый ежедневный ритуал — гороскоп и карта дня за 10–15 секунд после открытия.
**Платформа:** Android (primary) + iOS-ready архитектура.
**Стек:** Flutter + Firebase + Google Play Billing.

---

## 2. ЦЕЛЕВАЯ АУДИТОРИЯ

| Сегмент | Описание | Размер | Приоритет |
|---------|----------|--------|-----------|
| Core | Женщины 22–38, интерес к эзотерике, ежедневные ритуалы | Large | P0 |
| Secondary | Мужчины 25–40, self-reflection, casual | Medium | P1 |
| Casual | Все возрасты, развлечение/любопытство | Large | P2 |

**Гео:** Global. Приоритет языков: EN, ES, PT, RU (равноправно).

---

## 3. КЛЮЧЕВЫЕ МЕТРИКИ УСПЕХА

| Метрика | MVP Target | v1 Target |
|---------|-----------|-----------|
| D1 Retention | ≥ 40% | ≥ 50% |
| D7 Retention | ≥ 20% | ≥ 30% |
| D30 Retention | ≥ 10% | ≥ 15% |
| Onboarding completion | ≥ 70% | ≥ 80% |
| Paywall CTR | ≥ 5% | ≥ 8% |
| Subscription conversion | ≥ 2% MAU | ≥ 4% MAU |
| Crash-free rate | ≥ 99% | ≥ 99.5% |
| App Rating | ≥ 4.2 | ≥ 4.5 |

---

## 4. ПОЛЬЗОВАТЕЛЬСКИЕ ИСТОРИИ (MVP)

### US-01: Онбординг
> Как новый пользователь, я хочу ввести дату рождения за ≤3 экрана, чтобы немедленно получить персонализированный контент.

**Acceptance Criteria:**
- [ ] Экран приветствия → выбор даты рождения → (опц.) пол/время/место → согласие с дисклеймером → Today
- [ ] Дисклеймер виден и читаем, пользователь должен явно принять
- [ ] Онбординг ≤ 3 шагов до первого гороскопа
- [ ] Валидация: дата не в будущем, не старше 120 лет

### US-02: Экран Today
> Как пользователь, я хочу видеть гороскоп дня и карту ТАРО сразу при открытии.

**Acceptance Criteria:**
- [ ] Гороскоп дня виден без скролла (above the fold)
- [ ] Карта дня — 1 карта ТАРО (free tier)
- [ ] Загрузка из кэша если оффлайн
- [ ] Одни и те же результаты при перезапуске (seed по дате+знаку)

### US-03: Расширенный расклад (Premium)
> Как Premium-пользователь, я хочу раскладывать 3 карты с детальными значениями.

**Acceptance Criteria:**
- [ ] 3-карточный расклад доступен только с подпиской
- [ ] Для free — paywall с ценностным предложением
- [ ] Значения карт: upright/reversed, категории love/work/health

### US-04: История
> Как пользователь, я хочу видеть историю гороскопов и карт за последние 7 дней.

**Acceptance Criteria:**
- [ ] 7 дней истории (free) / 90 дней (premium)
- [ ] Работает оффлайн для последних 7 дней

### US-05: Push-уведомления
> Как пользователь, я хочу получать напоминание о ежедневном ритуале в выбранное время.

**Acceptance Criteria:**
- [ ] Запрос разрешения на уведомления (не в момент установки)
- [ ] Настраиваемое время (09:00 default)
- [ ] Персонализированный текст уведомления по знаку зодиака

### US-06: Подписка
> Как пользователь, я хочу подписаться через привычный Google Play интерфейс.

**Acceptance Criteria:**
- [ ] Monthly / Yearly варианты
- [ ] 3-дневный бесплатный trial (опц., A/B)
- [ ] Restore purchases работает
- [ ] Grace period обрабатывается (контент доступен 3 дня после просрочки)
- [ ] Серверная проверка через Firebase Functions

### US-07: Реклама (условная)
> Как пользователь без подписки (после 7 дней), я вижу ненавязчивую рекламу.

**Acceptance Criteria:**
- [ ] Реклама показывается только после 7 дней активного использования
- [ ] Только banner/interstitial от AdMob (Google)
- [ ] С подпиской — реклама полностью отключена
- [ ] Не более 1 interstitial за сессию

---

## 5. OUT OF SCOPE (MVP)

- iOS билд в стор (архитектура готова, но сборка/публикация — v2)
- Нумерология / астрология совместимости партнёров
- Социальные функции / sharing
- LLM-генерация контента (v2, с модерацией)
- Web версия
- Уведомления через email

---

## 6. ТЕХНИЧЕСКИЕ ТРЕБОВАНИЯ

### Performance
- Cold start ≤ 2 сек
- Today screen LCP ≤ 1 сек (from cache)
- API response ≤ 500ms (p95)

### Localization
- EN, ES, PT, RU — полный перевод UI + контент
- RTL — не требуется (все 4 языка LTR)
- Date/time форматирование по локали

### Offline
- "Сегодня" доступен оффлайн
- История последних 7 дней доступна оффлайн
- Карты ТАРО (изображения) кэшируются при первом запуске

### Security
- Нет хранения PII сверх необходимого
- Firebase Auth (anonymous → upgraded с email/Google)
- Покупки верифицируются на сервере
- Никаких секретов в клиентском коде

---

## 7. DISCLAIMER (ОБЯЗАТЕЛЬНЫЙ)

```
[EN] This app is for entertainment purposes only. Horoscopes and Tarot readings
     do not constitute medical, financial, legal, or any other professional advice.
     Results are generated for entertainment and should not be used as the basis
     for any real-world decisions.

[RU] Приложение предназначено исключительно для развлечения. Гороскопы и
     расклады ТАРО не являются медицинской, финансовой, юридической или иной
     профессиональной консультацией. Результаты носят развлекательный характер.

[ES] Esta aplicación es solo para entretenimiento. Los horóscopos y las tiradas
     de Tarot no constituyen asesoramiento médico, financiero, legal ni de ningún
     otro tipo profesional.

[PT] Este aplicativo é apenas para entretenimento. Horóscopos e leituras de Tarot
     não constituem aconselhamento médico, financeiro, jurídico ou qualquer outro
     tipo de aconselhamento profissional.
```

---

## 8. ЗАВИСИМОСТИ И РИСКИ (верхний уровень)

| Зависимость | Риск | Митигация |
|-------------|------|-----------|
| Firebase quota | Превышение free tier | Мониторинг + правила Firestore |
| AdMob approval | Отказ в подключении | Подготовить контент заранее |
| Play Store review | Отклонение из-за контента | Явный дисклеймер, категория Entertainment |
| Asset licenses | Правовые претензии | Документировать все лицензии |
| LLM content | Неприемлемые генерации | Модерация + шаблоны как fallback |

---

*Документ подготовлен: Claude Code (AI architect)*
*Следующий ревью: после Stage 1*
