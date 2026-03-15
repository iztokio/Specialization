# Plan: Polymarket BTC 5-Min Arbitrage Bot

## Architecture Overview

```
polymarket-arb-bot/
├── config/
│   └── settings.py          # All configuration, env vars
├── feeds/
│   ├── __init__.py
│   ├── binance_feed.py      # Real-time BTC spot price via WebSocket
│   ├── coinbase_feed.py     # Secondary price feed for cross-validation
│   └── polymarket_feed.py   # Polymarket CLOB orderbook + market discovery
├── signals/
│   ├── __init__.py
│   ├── bayesian.py          # Bayesian posterior model P(D|H)
│   ├── edge_detector.py     # Z-score edge detection
│   └── volatility.py        # Real-time volatility estimation (EWMA)
├── risk/
│   ├── __init__.py
│   ├── kelly.py             # Kelly criterion position sizing
│   ├── lmsr.py              # Market impact estimation
│   └── monte_carlo.py       # P&L distribution simulation
├── execution/
│   ├── __init__.py
│   ├── stoikov.py           # Avellaneda-Stoikov optimal quoting
│   ├── order_manager.py     # Order lifecycle management
│   └── hedge.py             # Directional hedge logic
├── engine/
│   ├── __init__.py
│   └── arbitrage.py         # Main orchestrator loop
├── monitoring/
│   ├── __init__.py
│   ├── dashboard.py         # Real-time terminal dashboard
│   └── logger.py            # Structured logging (training stream)
├── backtest/
│   ├── __init__.py
│   ├── simulator.py         # Historical data backtester
│   └── data_recorder.py     # Record live data for backtesting
├── tests/
│   ├── test_bayesian.py
│   ├── test_edge.py
│   ├── test_kelly.py
│   ├── test_stoikov.py
│   └── test_engine.py
├── main.py                  # Entry point
├── requirements.txt
├── .env.example
└── README.md
```

## Implementation Steps

### Phase 1: Foundation
1. Project structure + dependencies + config
2. Binance WebSocket feed (real-time BTC/USDT)
3. Polymarket CLOB feed (orderbook, market discovery for 5-min BTC)
4. Volatility estimator (EWMA)
5. Structured logger + training stream

### Phase 2: Signal Engine
6. Bayesian signal model with multi-factor likelihood
7. Z-score edge detector with adaptive thresholds
8. Signal filter (EV > cost check)

### Phase 3: Risk Management
9. Kelly criterion with fractional sizing + max caps
10. LMSR market impact estimator
11. Monte Carlo P&L simulator

### Phase 4: Execution
12. Avellaneda-Stoikov quoting engine
13. Order manager (place, cancel, track via CLOB API)
14. Inventory/hedge manager

### Phase 5: Orchestrator
15. Main arbitrage engine loop (scan → signal → size → execute)
16. Real-time terminal dashboard (metrics, P&L curve)

### Phase 6: Safety & Testing
17. Paper trading mode (simulate orders without real money)
18. Data recorder for backtesting
19. Unit tests for all core modules
20. Backtester on recorded data

## Improvements Over Original Bot

1. **Dual price feed** (Binance + Coinbase) — cross-validation reduces false signals
2. **EWMA volatility** instead of simple rolling — faster adaptation to regime changes
3. **Adaptive Z-score threshold** — tightens in low-vol, loosens in high-vol
4. **Paper trading mode** — test everything risk-free before deploying real capital
5. **Circuit breakers** — auto-stop on max drawdown, consecutive losses, or anomalous behavior
6. **Data recording** — capture all market data for offline backtesting and parameter tuning
7. **Graceful degradation** — if one feed drops, switch to backup; if edge shrinks, reduce sizing
