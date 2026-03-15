# Полный гайд: Polymarket BTC 5-Min Arbitrage Bot

## Содержание

1. [Требования](#1-требования)
2. [Создание кошелька](#2-создание-крипто-кошелька)
3. [Пополнение кошелька USDC](#3-пополнение-кошелька-usdc)
4. [Регистрация на Polymarket](#4-регистрация-на-polymarket)
5. [Получение API ключей](#5-получение-api-ключей-polymarket)
6. [Установка бота](#6-установка-бота)
7. [Настройка .env](#7-настройка-env-файла)
8. [Запуск в Paper Mode](#8-запуск-в-paper-mode-симуляция)
9. [Веб-дашборд](#9-веб-дашборд)
10. [Запуск в Live Mode](#10-запуск-в-live-mode-реальные-деньги)
11. [Параметры и тюнинг](#11-параметры-и-тюнинг)
12. [Мониторинг и обслуживание](#12-мониторинг-и-обслуживание)
13. [Устранение неполадок](#13-устранение-неполадок)
14. [Безопасность](#14-безопасность)

---

## 1. Требования

### Железо
- **VPS** (рекомендуется): US East (Нью-Йорк / Вирджиния) — ближе к серверам Polymarket
- **RAM**: минимум 1 GB
- **CPU**: 1 vCPU достаточно
- **OS**: Ubuntu 22.04+ / Debian 12+
- **Python**: 3.10+

### Программное обеспечение
- Python 3.10+
- pip
- git
- Любой браузер (для веб-дашборда)

### Капитал
- **Минимум**: $100 (для тестирования)
- **Рекомендуемый старт**: $500–$2,000
- **Потолок стратегии**: ~$200,000 (ограничение ликвидности)

---

## 2. Создание крипто-кошелька

Бот работает на **Polygon (MATIC) сети**. Вам нужен кошелёк с приватным ключом.

### Вариант A: MetaMask (для начинающих)

1. Установите расширение [MetaMask](https://metamask.io/) в браузер
2. Создайте новый кошелёк → **запишите seed-фразу на бумаге** (12 слов)
3. Добавьте сеть Polygon:
   ```
   Network Name:     Polygon Mainnet
   RPC URL:          https://polygon-rpc.com
   Chain ID:         137
   Currency Symbol:  MATIC
   Block Explorer:   https://polygonscan.com
   ```
4. Экспортируйте приватный ключ:
   - MetaMask → ⋮ → Account Details → Export Private Key
   - Введите пароль → скопируйте ключ (начинается с `0x...`)
   - **НИКОГДА не делитесь этим ключом**

### Вариант B: Отдельный кошелёк через Python (безопаснее)

```bash
pip install eth-account
python3 -c "
from eth_account import Account
acct = Account.create()
print(f'Address:     {acct.address}')
print(f'Private Key: {acct.key.hex()}')
print()
print('⚠ СОХРАНИТЕ приватный ключ в безопасном месте!')
"
```

> **Важно**: Используйте ОТДЕЛЬНЫЙ кошелёк только для бота. Не храните в нём больше, чем готовы потерять.

---

## 3. Пополнение кошелька USDC

Бот торгует в **USDC** на сети **Polygon**. Вам нужны:
- **USDC (Polygon)** — основная валюта для торговли
- **MATIC** (~$1-2) — для оплаты газа транзакций

### Способ 1: Через биржу (Binance / Coinbase / Bybit)

1. Купите USDC на бирже
2. Выведите USDC на ваш адрес кошелька:
   - **Сеть вывода: Polygon** (НЕ Ethereum, НЕ BNB Smart Chain!)
   - Адрес: ваш Polygon адрес из шага 2
   - Сумма: $100+ для теста
3. Также выведите ~$2 в MATIC для газа (сеть: Polygon)

### Способ 2: Через мост (Bridge)

Если USDC на Ethereum:
1. Откройте [Polygon Bridge](https://portal.polygon.technology/bridge)
2. Подключите кошелёк
3. Переведите USDC из Ethereum → Polygon
4. Ждите ~30 минут

### Способ 3: Покупка напрямую

1. Через [MoonPay](https://www.moonpay.com/) или [Ramp](https://ramp.network/)
2. Купите USDC, укажите сеть Polygon и ваш адрес

### Проверка баланса

Откройте https://polygonscan.com и введите ваш адрес. Вы должны увидеть:
- USDC баланс (в разделе Token)
- MATIC баланс (для газа)

---

## 4. Регистрация на Polymarket

1. Откройте https://polymarket.com
2. Нажмите **"Sign Up"**
3. Подключите кошелёк (MetaMask) **ИЛИ** войдите через email
4. Подтвердите электронную почту
5. Пройдите верификацию (KYC) если требуется

### Важно про Proxy Wallet

Polymarket использует **proxy wallet** систему:
- Ваш **основной кошелёк** (signing wallet) — подписывает транзакции
- **Proxy wallet** — адрес, на котором хранятся ваши средства на Polymarket

После первого входа Polymarket создаст proxy wallet автоматически. Его адрес понадобится для настройки бота.

### Внесение средств на Polymarket

1. На polymarket.com нажмите **"Deposit"**
2. Выберите USDC
3. Подтвердите транзакцию в кошельке

---

## 5. Получение API ключей Polymarket

Бот взаимодействует с Polymarket через CLOB API. Нужны API credentials.

### Автоматическая генерация (рекомендуется)

Бот может сам сгенерировать ключи при первом запуске. Для этого достаточно приватного ключа кошелька.

```python
from py_clob_client.client import ClobClient

client = ClobClient(
    "https://clob.polymarket.com",
    key="0x_ваш_приватный_ключ",
    chain_id=137,
)

# Создаст или получит API ключи
api_creds = client.create_or_derive_api_creds()
print(f"API Key:    {api_creds.api_key}")
print(f"Secret:     {api_creds.api_secret}")
print(f"Passphrase: {api_creds.api_passphrase}")
```

### Ручная генерация

1. Откройте https://polymarket.com
2. Войдите с кошельком
3. Settings → API → Generate API Keys
4. Сохраните: API Key, Secret, Passphrase

---

## 6. Установка бота

### Шаг 1: Клонирование репозитория

```bash
git clone https://github.com/iztokio/Specialization.git
cd Specialization
git checkout claude/crypto-arbitrage-analysis-eNZkF
cd polymarket-arb-bot
```

### Шаг 2: Создание виртуального окружения

```bash
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows
```

### Шаг 3: Установка зависимостей

```bash
pip install -r requirements.txt
```

### Шаг 4: Проверка установки

```bash
python -m pytest tests/ -v
```

Все 38 тестов должны пройти:
```
tests/test_bayesian.py     ✓ 8 passed
tests/test_edge.py         ✓ 6 passed
tests/test_kelly.py        ✓ 7 passed
tests/test_stoikov.py      ✓ 7 passed
tests/test_engine.py       ✓ 10 passed
```

---

## 7. Настройка .env файла

```bash
cp .env.example .env
nano .env  # или любой редактор
```

### Минимальная конфигурация (Paper Mode)

```env
# Кошелёк (нужен даже для paper mode для запросов к API)
PRIVATE_KEY=0xваш_приватный_ключ_64_символа

# Режим
TRADING_MODE=paper

# Стартовый капитал (симулированный)
INITIAL_BANKROLL=2050.0
```

### Полная конфигурация (Live Mode)

```env
# ═══ Кошелёк ═══════════════════════════════════════════
PRIVATE_KEY=0xваш_приватный_ключ_64_символа
POLYMARKET_FUNDER=0xваш_proxy_wallet_адрес

# ═══ API ключи (опционально — бот сгенерирует сам) ════
POLYMARKET_API_KEY=ваш_api_key
POLYMARKET_SECRET=ваш_api_secret
POLYMARKET_PASSPHRASE=ваш_passphrase

# ═══ Режим ═════════════════════════════════════════════
TRADING_MODE=live

# ═══ Капитал ═══════════════════════════════════════════
INITIAL_BANKROLL=500.0
MAX_POSITION_SIZE=1000.0

# ═══ Риск ══════════════════════════════════════════════
MAX_DRAWDOWN_PCT=0.20
KELLY_FRACTION=0.5

# ═══ Сигналы ═══════════════════════════════════════════
Z_SCORE_THRESHOLD=2.0
MIN_NET_EV=0.003

# ═══ Исполнение ════════════════════════════════════════
GAMMA=0.18
MAX_INVENTORY=3.0

# ═══ Логирование ═══════════════════════════════════════
LOG_LEVEL=INFO
DATA_RECORD_DIR=./data
```

---

## 8. Запуск в Paper Mode (симуляция)

Paper mode имитирует торговлю без реальных денег. **Начните здесь.**

### Терминальный режим

```bash
cd polymarket-arb-bot
source venv/bin/activate
python main.py
```

Вы увидите:
```
============================================================
  ARB ENGINE // 5-MIN BTC MARKETS
  Mode: PAPER
  Bankroll: $2,050.00
============================================================
```

И далее Rich-дашборд в терминале с:
- Метриками в реальном времени
- Training stream (лог всех решений)
- Статусами модулей

### С предварительной валидацией Monte Carlo

```bash
python main.py --validate
```

Бот прогонит 10,000 симуляций и покажет:
```
Monte Carlo Results (10000 simulations, 1000 trades):
  Mean P&L:       $1,245.30
  P(profit):      87.2%
  P(ruin):        1.3%
  Sharpe:         2.41
  Viable:         YES
```

Если стратегия не прошла валидацию → **не запускайте в live**.

### Без дашборда (только логи)

```bash
python main.py --no-dashboard
```

---

## 9. Веб-дашборд

Веб-интерфейс — удобнее терминала, работает в браузере.

### Запуск

```bash
cd polymarket-arb-bot
source venv/bin/activate
pip install flask flask-socketio  # если ещё не установлены
python web/app.py
```

### Открытие

В браузере: **http://localhost:5000**

Или с VPS: **http://ваш_ip:5000**

### Интерфейс

Дашборд показывает:

```
┌─────────────────────────────────────────────────────────┐
│ ARB ENGINE // 5-MIN BTC    [PAPER]  ● Running    [Start] [Stop] [Settings] │
├─────────────────────────────────────────────────────────┤
│ Balance    P&L      ROI     Win Rate  Trades/hr  Total  │
│ $2,534   +$484    23.6%    87.3%     142        1,891  │
├──────────────────────────┬──────────────────────────────┤
│                          │ SYSTEM STATUS                │
│  P&L CURVE              │  Binance    ONLINE           │
│  [chart with growth]    │  Coinbase   ONLINE           │
│                          │  BTC Price  $87,432          │
│                          │  Bayesian   post=0.623       │
│                          │  Stoikov    q=1.2            │
│                          │  Circuit    OK               │
├──────────────────────────┼──────────────────────────────┤
│ TRAINING STREAM          │ ORDERS                       │
│ 14:23:05 [BAYES ] ...   │ Active:                      │
│ 14:23:05 [EDGE  ] ...   │  ORD-001 BUY 0.42 $150      │
│ 14:23:06 [KELLY ] ...   │ Recent Fills:                │
│ 14:23:06 [FILL  ] ...   │  ORD-000 BUY 0.39 $200 ✓    │
└──────────────────────────┴──────────────────────────────┘
```

### Управление через дашборд

1. **Start** — запускает движок (в paper или live, в зависимости от настроек)
2. **Stop** — останавливает движок, отменяет все ордера
3. **Settings** — открывает панель настроек:
   - Переключение Paper / Live mode
   - Размер банкролла
   - Z-score порог
   - Kelly fraction
   - Gamma (Stoikov)
   - Circuit breakers
4. **Cancel All** — отменяет все активные ордера

### Удалённый доступ (VPS)

Если бот на VPS, пробросьте порт:
```bash
# На локальной машине:
ssh -L 5000:localhost:5000 user@ваш_vps_ip

# Затем откройте http://localhost:5000 в браузере
```

Или откройте порт в файрволе (менее безопасно):
```bash
sudo ufw allow 5000
```

---

## 10. Запуск в Live Mode (реальные деньги)

> **⚠ ВНИМАНИЕ**: Live mode использует реальные деньги. Вы можете потерять весь капитал.

### Чеклист перед запуском

- [ ] Paper mode работал стабильно 7+ дней
- [ ] Monte Carlo валидация пройдена (`--validate`)
- [ ] Win rate в paper > 60%
- [ ] Кошелёк создан и пополнен USDC на Polygon
- [ ] Proxy wallet на Polymarket активирован
- [ ] Allowances установлены (бот сделает это автоматически)
- [ ] .env заполнен полностью
- [ ] Начинаете с МАЛОЙ суммы ($100-500)

### Запуск

```bash
# Через терминал:
TRADING_MODE=live python main.py --validate

# Через веб-дашборд:
TRADING_MODE=live python web/app.py
# → Открыть http://localhost:5000 → нажать Start
```

Бот выдаст предупреждение:
```
*** LIVE TRADING MODE ***
Real money will be used. Press Ctrl+C within 5 seconds to abort.
```

### Allowances (разрешения)

При первом запуске в live mode, бот должен установить allowances —
разрешения для смарт-контрактов Polymarket на использование ваших USDC:

```python
# Это происходит автоматически при инициализации ClobClient
# Но можно сделать вручную:
client.set_allowances()
```

Это одноразовая транзакция, потребует ~0.01 MATIC для газа.

### Масштабирование

| Неделя | Банкролл | Max Position | Действие |
|--------|----------|-------------|----------|
| 1 | $100-500 | $50 | Наблюдение, сбор данных |
| 2-3 | $500-2,000 | $200 | Увеличение если win rate > 60% |
| 4+ | $2,000-10,000 | $1,000 | Полная скорость |
| 8+ | $10,000+ | $5,000 | Только если Sharpe > 2.0 |

---

## 11. Параметры и тюнинг

### Ключевые параметры

| Параметр | По умолчанию | Диапазон | Что делает |
|----------|-------------|----------|-----------|
| `Z_SCORE_THRESHOLD` | 2.0 | 1.5–3.0 | Порог срабатывания. Ниже = больше сделок, но меньше edge |
| `MIN_NET_EV` | 0.003 | 0.001–0.01 | Мин. чистый EV. Ниже = больше сделок |
| `KELLY_FRACTION` | 0.5 | 0.2–0.8 | Доля от Kelly. 0.5 = half-Kelly (безопаснее) |
| `GAMMA` | 0.18 | 0.05–0.50 | Risk aversion Stoikov. Выше = шире спреды, осторожнее |
| `MAX_INVENTORY` | 3.0 | 1.0–5.0 | Макс. позиций одновременно |
| `ORDER_TTL_SECONDS` | 15 | 5–60 | Время жизни ордера до автоотмены |
| `MAX_POSITION_SIZE` | 5000 | 100–10000 | Макс. размер одного ордера ($) |
| `CIRCUIT_MAX_DRAWDOWN` | 0.20 | 0.10–0.30 | Стоп при просадке от пика |

### Рекомендации по тюнингу

**Консервативный** (для начала):
```env
Z_SCORE_THRESHOLD=2.5
MIN_NET_EV=0.005
KELLY_FRACTION=0.3
GAMMA=0.25
MAX_POSITION_SIZE=500
```

**Сбалансированный** (после 2 недель paper):
```env
Z_SCORE_THRESHOLD=2.0
MIN_NET_EV=0.003
KELLY_FRACTION=0.5
GAMMA=0.18
MAX_POSITION_SIZE=2000
```

**Агрессивный** (только для опытных, после месяца live):
```env
Z_SCORE_THRESHOLD=1.5
MIN_NET_EV=0.002
KELLY_FRACTION=0.7
GAMMA=0.10
MAX_POSITION_SIZE=5000
```

---

## 12. Мониторинг и обслуживание

### Ежедневные проверки

1. **Win rate** > 55% — если ниже, рынок изменился, нужна рекалибровка
2. **Drawdown** < 15% — если больше, circuit breaker должен сработать
3. **Trades/hr** — должен быть стабильным (~100-300)
4. **Feed status** — оба фида (Binance, Coinbase) должны быть ONLINE

### Запись данных для анализа

Бот автоматически записывает данные в `./data/YYYYMMDD/`:
```
data/
├── 20260315/
│   ├── ticks_143022.jsonl    # все ценовые тики
│   ├── books_143022.jsonl    # снапшоты ордербуков
│   ├── signals_143022.jsonl  # все сигналы
│   └── trades_143022.jsonl   # все сделки
```

### Бэктестинг

После сбора данных, прогоните бэктестер для оптимизации:

```python
from backtest.simulator import Backtester

bt = Backtester(bankroll=2050, kelly_fraction=0.5)
result = bt.run("./data/20260315/")

print(f"Trades:     {result.total_trades}")
print(f"Win Rate:   {result.win_rate:.1%}")
print(f"P&L:        ${result.total_pnl:,.2f}")
print(f"Max DD:     {result.max_drawdown:.1%}")
print(f"Sharpe:     {result.sharpe:.2f}")
```

### Автозапуск (systemd)

Для автозапуска на VPS:

```bash
sudo nano /etc/systemd/system/arb-bot.service
```

```ini
[Unit]
Description=Polymarket Arbitrage Bot
After=network.target

[Service]
Type=simple
User=botuser
WorkingDirectory=/home/botuser/polymarket-arb-bot
ExecStart=/home/botuser/polymarket-arb-bot/venv/bin/python web/app.py
Restart=always
RestartSec=10
Environment=TRADING_MODE=paper

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable arb-bot
sudo systemctl start arb-bot
sudo journalctl -u arb-bot -f  # логи
```

---

## 13. Устранение неполадок

### Бот не подключается к Binance WS

```
Binance WS disconnected: ... Reconnecting in 2s…
```

**Решение**:
- Проверьте интернет-соединение
- Binance может быть заблокирован в вашей стране → используйте VPN/VPS
- Попробуйте альтернативный URL: `wss://stream.binance.us:9443/ws/btcusdt@trade`

### "No active 5-min BTC markets"

**Решение**:
- 5-минутные рынки обновляются каждые 5 минут
- Подождите до начала следующего 5-мин окна
- Проверьте https://polymarket.com/crypto/5M — рынки должны быть активны

### Circuit breaker срабатывает слишком часто

**Решение**:
- Увеличьте `CIRCUIT_MAX_DRAWDOWN` (например, 0.25)
- Увеличьте `Z_SCORE_THRESHOLD` (меньше сделок, но с большим edge)
- Уменьшите `KELLY_FRACTION` (меньше ставки)

### Ордера не исполняются (0 fills)

**Решение**:
- Цена ордера слишком далеко от рынка → уменьшите `GAMMA`
- `ORDER_TTL_SECONDS` слишком маленький → увеличьте до 30
- Ликвидность слишком низкая → попробуйте 15-мин рынки

### Ошибка allowance

```
Failed to place order: insufficient allowance
```

**Решение**:
```python
from py_clob_client.client import ClobClient
client = ClobClient("https://clob.polymarket.com", key="0x...", chain_id=137)
client.set_allowances()  # установит бесконечный allowance
```

### Нет MATIC для газа

**Решение**:
- Отправьте 0.5-1 MATIC на кошелёк бота
- Используйте [Polygon Faucet](https://faucet.polygon.technology/) для тестовой сети
- На mainnet: купите MATIC на бирже, выведите на Polygon

---

## 14. Безопасность

### Критические правила

1. **Приватный ключ**: Храните только в `.env` файле (он в `.gitignore`).
   **Никогда** не коммитьте, не отправляйте, не показывайте.

2. **Отдельный кошелёк**: Используйте кошелёк ТОЛЬКО для бота.
   Не храните там основные средства.

3. **Начинайте с малого**: $100-500 максимум на первые 2 недели.

4. **VPS безопасность**:
   ```bash
   # Отключите root-логин
   sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
   # Используйте SSH-ключи вместо паролей
   # Включите файрвол
   sudo ufw enable
   sudo ufw allow 22
   sudo ufw allow 5000  # только если нужен внешний доступ к дашборду
   ```

5. **Мониторинг**: Проверяйте бота минимум раз в день. Настройте алерты.

6. **Backups**: Регулярно сохраняйте данные из `./data/`

### Чего НЕ делать

- ❌ Не ставьте весь капитал сразу
- ❌ Не отключайте circuit breakers
- ❌ Не запускайте live без paper-тестирования
- ❌ Не игнорируйте Monte Carlo результаты
- ❌ Не используйте основной кошелёк
- ❌ Не запускайте несколько экземпляров бота на одном кошельке

---

## Схема подключения (итоговая)

```
                    ┌─────────────────┐
                    │  Ваш браузер    │
                    │  localhost:5000  │
                    └────────┬────────┘
                             │ HTTP + WebSocket
                    ┌────────▼────────┐
                    │   Web Dashboard  │
                    │   (Flask app)    │
                    └────────┬────────┘
                             │
              ┌──────────────▼──────────────┐
              │     ARB ENGINE (Python)      │
              │                              │
              │  Bayesian → Edge → Kelly     │
              │  → LMSR → Stoikov → Orders   │
              └──┬──────────┬───────────┬───┘
                 │          │           │
    ┌────────────▼──┐ ┌─────▼─────┐ ┌──▼────────────┐
    │  Binance WS   │ │ Coinbase  │ │  Polymarket    │
    │  BTC/USDT     │ │ BTC-USD   │ │  CLOB API      │
    │  (цена спот)  │ │ (backup)  │ │  (ордербуки,   │
    └───────────────┘ └───────────┘ │   ордера)      │
                                     └───────┬────────┘
                                             │
                                    ┌────────▼────────┐
                                    │  Polygon Chain   │
                                    │  (USDC, MATIC)   │
                                    │                  │
                                    │  Ваш кошелёк:   │
                                    │  0xАдрес...      │
                                    └─────────────────┘
```

---

## Быстрый старт (TL;DR)

```bash
# 1. Клонировать
git clone https://github.com/iztokio/Specialization.git
cd Specialization && git checkout claude/crypto-arbitrage-analysis-eNZkF
cd polymarket-arb-bot

# 2. Установить
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# 3. Настроить
cp .env.example .env
# Вписать PRIVATE_KEY и TRADING_MODE=paper

# 4. Проверить
python -m pytest tests/ -v

# 5. Запустить (paper mode)
python web/app.py
# Открыть http://localhost:5000 → нажать Start

# 6. Когда готовы к live (через 1-2 недели paper):
# Изменить TRADING_MODE=live в .env
# Нажать Settings → Live → Save → Start
```
