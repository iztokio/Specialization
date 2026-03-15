# Анализ арбитражного бота для 5-минутных BTC рынков на Polymarket

## 1. Контекст

Бот превратил **$2,050 в $178,000** за один месяц, торгуя на 5-минутных предикшн-рынках BTC на Polymarket. Ключевые метрики со скриншота:

| Метрика | Значение |
|---------|----------|
| Стартовый баланс | $2,050 |
| Итоговый баланс | ~$102,978 (на момент скриншота) → $178,000 (итог) |
| ROI | 4,920% |
| Win Rate | 89.8% |
| Edge (преимущество) | 13.19% |
| Trades/hr | 278 |
| Total trades | 7,991 |
| Sharpe Ratio | 4.08 |
| P/L ratio | 4.2x |
| Тип ордеров | Limit Only |

---

## 2. Как работает рынок

Polymarket предлагает контракты вида: **"BTC будет выше/ниже $X через 5 минут?"**

- Контракт `YES` стоит от $0.01 до $0.99
- Контракт `NO` = 1 - `YES`
- При разрешении контракт стоит **$1.00** (если исход верный) или **$0.00**
- В идеальном рынке: `P(YES) + P(NO) = $1.00`

**Ключевая неэффективность**: цены на Polymarket отстают от спотовых цен BTC на централизованных биржах (Binance, Coinbase) на **секунды-миллисекунды**. Это окно — источник прибыли.

---

## 3. Разбор алгоритма по скриншоту

Скриншот показывает 6 ключевых модулей, работающих в связке:

### 3.1. Байесовская модель (Bayesian Model)

```
P(D|H) = f(spot_delta, vol, book)
```

**Что делает**: Оценивает вероятность того, что BTC пойдёт вверх/вниз в ближайшие 5 минут.

**Входные параметры**:
- `spot_delta` — изменение спотовой цены BTC на CEX
- `vol` — краткосрочная волатильность
- `book` — дисбаланс ордербука (order book imbalance)
- Скорость репрайсинга ближайших mid-цен
- Hash signal probability (сигнал от хешрейта сети)

**Механика**:
- Prior (априорная вероятность): 0.436
- Posterior (после обновления данными): 0.544
- Модель непрерывно обновляет posterior по мере поступления данных (Bayesian updating)

```python
# Псевдокод байесовского обновления
posterior = (likelihood * prior) / evidence
# Если posterior > threshold → генерировать сигнал
```

### 3.2. Edge + Spread (Обнаружение преимущества)

```
Z = (S - mu_S) / sigma_S
```

**Что делает**: Обнаруживает моменты, когда спред между ценой Polymarket и "справедливой" ценой аномально большой.

- `S = P1 - P2` — текущий спред (цена Polymarket vs. справедливая цена из байесовской модели)
- `mu_S` — средний спред (нормальный)
- `sigma_S` — стандартное отклонение спреда
- **Z > 2** → сигнал дислокации (цена сильно отклонилась, есть edge)
- **Z < -support** → вернуться в безопасный режим

**Со скриншота**:
- `EV = 0.0178` (ожидаемая ценность сделки)
- `cost = 0.0126` (стоимость входа: спреды + комиссии)
- `net = 0.0051` → **PASS** (чистая прибыль положительная → входим)
- `Z-score = 2.57`, `p_pass = 0.9659` (96.6% уверенности в сигнале)

### 3.3. Execution Layer — Stoikov Quoting

```
r = s - q * gamma * sigma^2 * (T - t)
```

**Что делает**: Определяет оптимальную цену размещения лимитного ордера (reservation price).

Это модель **Avellaneda-Stoikov** для маркет-мейкинга:
- `s` — mid price (середина стакана)
- `q` — текущая позиция (inventory)
- `gamma` — коэффициент неприятия риска (risk aversion)
- `sigma^2` — дисперсия цены
- `T - t` — оставшееся время до экспирации контракта

**Со скриншота**: `q=1.1, gamma=0.18, sigma^2=0.0072`

**Смысл**: Если у бота уже есть позиция (q > 0), он сдвигает свою цену вниз, чтобы быстрее разгрузить инвентарь. Это предотвращает накопление направленного риска.

### 3.4. Kelly Criterion (Управление размером позиции)

```
f* = (p * b - q) / b
```

Где `p` — вероятность выигрыша, `b` — коэффициент выплат, `q = 1 - p`.

В логах видны записи вида `[KELLY] f=0.31, safe` и `[KELLY] f=0.57, safe` — это доля капитала, которую Kelly рекомендует ставить на каждую сделку.

**Применение**: Не ставить больше, чем Kelly fraction от текущего баланса. Обычно используется fractional Kelly (50-75% от оптимального f*) для дополнительной безопасности.

### 3.5. LMSR (Logarithmic Market Scoring Rule)

В логах: `[LMSR] b=0.1, impact=0.524`, `[LMSR] b=0.1, impact=1.066`

**Что делает**: Оценивает влияние сделки на рыночную цену (market impact). Polymarket использует CLOB (Central Limit Order Book), но LMSR помогает боту предсказать, как его ордер повлияет на цену.

- `b` — параметр ликвидности
- `impact` — ожидаемый сдвиг цены от сделки

Если impact слишком большой → уменьшить размер ордера или разбить на части.

### 3.6. Monte Carlo (Симуляция)

Упоминается в нижней панели: `BAYESIAN + EDGE + SPREAD + STOIKOV + KELLY + MONTE CARLO`

**Что делает**: Прогон тысяч симуляций для оценки распределения P&L и хвостовых рисков перед каждой сделкой или серией сделок.

---

## 4. Полный торговый цикл (пошагово)

```
1. SCAN  → Сканирование спотовой цены BTC на Binance/Coinbase в реальном времени
2. BAYES → Обновление posterior вероятности движения цены
3. EDGE  → Расчёт Z-score спреда между Polymarket и справедливой ценой
4. FILTER → Фильтрация: EV > cost? Z-score > 2? → PASS / REJECT
5. KELLY → Определение оптимального размера позиции
6. LMSR  → Оценка market impact, корректировка размера
7. STOIKOV → Расчёт оптимальной цены лимитного ордера
8. FILL  → Размещение лимитного ордера, ожидание исполнения
9. HEDGE → Направленное хеджирование (если нужно)
10. Repeat → 278 раз в час
```

---

## 5. Архитектура реализации

### 5.1. Стек технологий

```
┌─────────────────────────────────────────────┐
│              Data Layer                      │
│  Binance WS │ Coinbase WS │ Polymarket API  │
└──────┬──────┴──────┬──────┴───────┬─────────┘
       │             │              │
┌──────▼─────────────▼──────────────▼─────────┐
│           Signal Engine                      │
│  Bayesian Model │ Z-Score │ Edge Calculator  │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│          Risk & Sizing                       │
│  Kelly Criterion │ LMSR Impact │ Monte Carlo │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│         Execution Engine                     │
│  Stoikov Quoting │ Order Management │ Hedge  │
└─────────────────────────────────────────────┘
```

### 5.2. Ключевые компоненты

#### A. Сбор данных (Data Feeds)

```python
import asyncio
import websockets
import json

class SpotFeed:
    """Реал-тайм спотовая цена BTC с CEX"""

    async def connect_binance(self):
        uri = "wss://stream.binance.com:9443/ws/btcusdt@trade"
        async with websockets.connect(uri) as ws:
            async for msg in ws:
                data = json.loads(msg)
                self.last_price = float(data['p'])
                self.last_time = data['T']
                await self.on_price_update()

class PolymarketFeed:
    """Мониторинг ордербука Polymarket через CLOB API"""

    async def get_orderbook(self, token_id: str):
        # Polymarket CLOB API
        url = f"https://clob.polymarket.com/book?token_id={token_id}"
        # Парсим bids/asks, считаем mid price, spread, depth
        pass

    async def get_active_5min_markets(self):
        # Поиск активных 5-минутных BTC контрактов
        # Контракты обновляются каждые 5 минут
        pass
```

#### B. Байесовская модель

```python
import numpy as np

class BayesianSignal:
    def __init__(self):
        self.prior = 0.5  # начальная вероятность UP

    def compute_likelihood(self, spot_delta, volatility, book_imbalance):
        """
        P(D|H) = f(spot_delta, vol, book)

        spot_delta: изменение цены BTC за последние N секунд
        volatility: краткосрочная реализованная волатильность
        book_imbalance: (bid_volume - ask_volume) / total_volume
        """
        # Взвешенная комбинация сигналов
        w_spot = 0.5
        w_vol = 0.2
        w_book = 0.3

        # Нормализация сигналов в [0, 1]
        spot_signal = self._sigmoid(spot_delta / volatility)
        vol_signal = self._vol_regime(volatility)
        book_signal = self._sigmoid(book_imbalance * 5)

        likelihood = (w_spot * spot_signal +
                      w_vol * vol_signal +
                      w_book * book_signal)
        return likelihood

    def update(self, spot_delta, volatility, book_imbalance):
        """Байесовское обновление"""
        likelihood_up = self.compute_likelihood(spot_delta, volatility, book_imbalance)
        likelihood_down = 1 - likelihood_up

        # P(H|D) = P(D|H) * P(H) / P(D)
        numerator = likelihood_up * self.prior
        evidence = (likelihood_up * self.prior +
                    likelihood_down * (1 - self.prior))

        self.posterior = numerator / evidence
        self.prior = self.posterior  # для следующей итерации
        return self.posterior

    @staticmethod
    def _sigmoid(x):
        return 1 / (1 + np.exp(-x))

    @staticmethod
    def _vol_regime(vol):
        # Высокая волатильность = больше возможностей
        return min(vol / 0.02, 1.0)
```

#### C. Edge Detection (Z-Score)

```python
from collections import deque

class EdgeDetector:
    def __init__(self, window=100):
        self.spreads = deque(maxlen=window)

    def compute_edge(self, polymarket_price, fair_price, cost=0.0126):
        """
        Z = (S - mu_S) / sigma_S
        """
        spread = abs(polymarket_price - fair_price)
        self.spreads.append(spread)

        if len(self.spreads) < 20:
            return None, None, False

        mu = np.mean(self.spreads)
        sigma = np.std(self.spreads)

        if sigma == 0:
            return None, None, False

        z_score = (spread - mu) / sigma
        ev = spread  # ожидаемая прибыль
        net = ev - cost

        # Сигнал: Z > 2 и чистый EV > 0
        is_signal = z_score > 2.0 and net > 0

        return z_score, net, is_signal
```

#### D. Stoikov Execution (Оптимальная цена ордера)

```python
class StoikovQuoter:
    def __init__(self, gamma=0.18):
        self.gamma = gamma  # risk aversion
        self.inventory = 0  # текущая позиция

    def reservation_price(self, mid_price, sigma2, time_remaining):
        """
        r = s - q * gamma * sigma^2 * (T - t)

        mid_price: середина стакана
        sigma2: дисперсия цены
        time_remaining: секунды до экспирации / макс_время
        """
        r = mid_price - self.inventory * self.gamma * sigma2 * time_remaining
        return r

    def optimal_spread(self, sigma2, time_remaining):
        """Оптимальный спред вокруг reservation price"""
        spread = self.gamma * sigma2 * time_remaining
        spread += (2 / self.gamma) * np.log(1 + self.gamma / 1.0)
        return spread

    def get_quotes(self, mid_price, sigma2, time_remaining):
        r = self.reservation_price(mid_price, sigma2, time_remaining)
        half_spread = self.optimal_spread(sigma2, time_remaining) / 2

        bid = r - half_spread
        ask = r + half_spread
        return bid, ask
```

#### E. Kelly Criterion (Размер позиции)

```python
class KellySizer:
    def __init__(self, fraction=0.5):
        """fraction: доля от полного Kelly (0.5 = half Kelly)"""
        self.fraction = fraction

    def optimal_size(self, win_prob, odds, bankroll):
        """
        f* = (p * b - q) / b

        win_prob: вероятность выигрыша (из Bayes)
        odds: коэффициент выплат (обычно ~1 для бинарного рынка)
        bankroll: текущий баланс
        """
        q = 1 - win_prob
        f_star = (win_prob * odds - q) / odds

        # Ограничиваем: не больше fractional Kelly
        f = max(0, f_star * self.fraction)

        # Абсолютный лимит: не больше 5% банкролла на сделку
        f = min(f, 0.05)

        return f * bankroll
```

#### F. Главный цикл

```python
class ArbitrageEngine:
    def __init__(self):
        self.spot_feed = SpotFeed()
        self.poly_feed = PolymarketFeed()
        self.bayes = BayesianSignal()
        self.edge = EdgeDetector()
        self.stoikov = StoikovQuoter(gamma=0.18)
        self.kelly = KellySizer(fraction=0.5)
        self.bankroll = 2050.0

    async def run(self):
        """Основной цикл: ~278 итераций в час"""
        while True:
            # 1. Получить текущие данные
            spot_price = self.spot_feed.last_price
            spot_delta = self.spot_feed.get_delta(seconds=10)
            volatility = self.spot_feed.get_volatility(seconds=60)

            # 2. Сканировать активные 5-мин контракты
            markets = await self.poly_feed.get_active_5min_markets()

            for market in markets:
                book = await self.poly_feed.get_orderbook(market.token_id)
                book_imbalance = book.get_imbalance()
                poly_price = book.mid_price
                time_remaining = market.seconds_to_expiry / 300  # normalized

                # 3. Байесовский сигнал
                posterior = self.bayes.update(spot_delta, volatility, book_imbalance)
                fair_price = posterior  # для YES контракта

                # 4. Проверка edge
                z_score, net_ev, has_edge = self.edge.compute_edge(
                    poly_price, fair_price
                )

                if not has_edge:
                    continue  # [FILTER] rejected

                # 5. Размер позиции по Kelly
                win_prob = 0.5 + net_ev  # упрощение
                position_size = self.kelly.optimal_size(
                    win_prob, odds=1.0, bankroll=self.bankroll
                )

                # 6. Оценка market impact (LMSR)
                impact = self.estimate_impact(position_size, book)
                if impact > 0.5:
                    position_size *= 0.5  # уменьшить если impact большой

                # 7. Stoikov: оптимальная цена
                sigma2 = volatility ** 2
                bid, ask = self.stoikov.get_quotes(
                    poly_price, sigma2, time_remaining
                )

                # 8. Размещение лимитного ордера
                if fair_price > poly_price:  # Polymarket недооценивает YES
                    await self.place_limit_order(
                        market.token_id,
                        side="BUY",
                        price=bid,
                        size=position_size
                    )
                else:  # Polymarket переоценивает YES → покупаем NO
                    await self.place_limit_order(
                        market.token_id,
                        side="SELL",
                        price=ask,
                        size=position_size
                    )

            await asyncio.sleep(0.5)  # ~2 итерации в секунду
```

---

## 6. Критические факторы успеха

### Почему это работает:

1. **Latency Edge** — спотовые данные с CEX поступают быстрее, чем участники Polymarket обновляют свои ордера. Окно — секунды.

2. **Тонкая ликвидность** — ордербук 5-мин контрактов на Polymarket: $5,000–$15,000 на сторону. Малый капитал ($2–5K на сделку) не двигает рынок.

3. **Частота** — 278 сделок/час × малый edge на каждую = аккумуляция прибыли. При net EV = $0.51 на $100 ставки → ~$142/час.

4. **Limit Only** — бот НИКОГДА не берёт рыночные ордера. Только лимитные. Это снижает cost of execution и даёт ребейт.

5. **Compound Growth** — прибыль реинвестируется (Kelly sizing масштабирует позиции с ростом банкролла), что создаёт экспоненциальную кривую P&L.

### Риски и ограничения:

1. **Capacity ceiling** — стратегия не масштабируется выше ~$200K из-за ликвидности ордербука
2. **Competition** — другие боты вытесняют edge (гонка вооружений по latency)
3. **Platform risk** — Polymarket может изменить правила, API, комиссии
4. **Smart contract risk** — средства на Polygon, зависимость от инфраструктуры
5. **Регуляторный риск** — предикшн-рынки находятся в серой зоне
6. **Overfitting** — параметры могут быть переоптимизированы под исторические данные

---

## 7. Минимальный стек для реализации

| Компонент | Технология |
|-----------|-----------|
| Язык | Python (asyncio) или Rust (для минимальной latency) |
| Data feeds | Binance/Coinbase WebSocket API |
| Polymarket | [CLOB API](https://docs.polymarket.com/) + py-clob-client |
| Wallet | Polygon (MATIC) wallet с USDC |
| Hosting | VPS в том же датацентре, что и Polymarket (US East) |
| Мониторинг | Grafana / custom dashboard |

---

## 8. Выводы

Данный бот — это **высокочастотный маркет-мейкер / latency-арбитражёр** для предикшн-рынков. Его прибыль основана не на предсказании цены BTC, а на **эксплуатации задержки** обновления цен на Polymarket относительно спотовых бирж.

Основная формула успеха:
```
Profit = Frequency × Edge × Compound Growth
       = 278/hr × 13.19% × Kelly Reinvestment
```

Это легитимная стратегия маркет-мейкинга, адаптированная для предикшн-рынков. Она требует:
- Глубокого понимания микроструктуры рынка
- Инфраструктуры с низкой задержкой
- Строгого управления рисками (Kelly + Stoikov)
- Постоянной адаптации параметров по мере роста конкуренции
