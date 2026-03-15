"""
Demo mode: runs the full bot pipeline with simulated market data.

Use this when external feeds (Binance, Coinbase, Polymarket) are unreachable
— for example in sandboxed environments, demos, or offline testing.

Generates realistic BTC price movements and Polymarket orderbooks,
then feeds them through the real signal → risk → execution pipeline.
"""

from __future__ import annotations

import asyncio
import math
import os
import random
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
os.environ.setdefault("TRADING_MODE", "paper")

from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO, emit

from config.settings import Settings
from execution.order_manager import OrderManager, Order, OrderStatus
from execution.stoikov import StoikovQuoter
from execution.hedge import HedgeManager
from feeds.polymarket_feed import OrderBook
from monitoring.logger import TrainingStream, get_logger, stream
from risk.kelly import KellySizer
from risk.lmsr import LMSRImpact
from risk.monte_carlo import MonteCarloSimulator
from signals.bayesian import BayesianSignal
from signals.edge_detector import EdgeDetector
from signals.volatility import VolatilityEstimator

logger = get_logger("demo")

app = Flask(
    __name__,
    template_folder="templates",
    static_folder="static",
)
app.config["SECRET_KEY"] = "demo-key-12345"
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")


# ═══════════════════════════════════════════════════════════
#  Simulated Market Data Generator
# ═══════════════════════════════════════════════════════════

class SimulatedMarket:
    """Generates realistic BTC price movements using geometric Brownian motion."""

    def __init__(self, initial_price: float = 87_500.0):
        self.price = initial_price
        self.mu = 0.0001       # slight upward drift
        self.sigma = 0.0008    # per-tick volatility
        self.tick_count = 0
        self._trend = 0.0
        self._trend_duration = 0

    def tick(self) -> float:
        """Generate next price tick."""
        self.tick_count += 1

        # Occasionally shift trend (momentum regime)
        if self._trend_duration <= 0:
            self._trend = random.gauss(0, 0.0003)
            self._trend_duration = random.randint(20, 100)
        self._trend_duration -= 1

        # Geometric Brownian Motion + trend
        dt = 1.0
        drift = (self.mu + self._trend) * dt
        shock = self.sigma * random.gauss(0, 1) * math.sqrt(dt)
        self.price *= math.exp(drift + shock)

        return self.price

    def get_polymarket_book(self, fair_prob: float) -> OrderBook:
        """
        Generate a Polymarket-style orderbook for 5-min BTC YES/NO.

        The book is intentionally slightly misaligned with fair_prob
        to create arbitrage opportunities.
        """
        # Add noise/delay to simulate Polymarket lag
        lag_noise = random.gauss(0, 0.03)
        displayed_prob = max(0.05, min(0.95, fair_prob + lag_noise))

        # Generate book levels around displayed_prob
        spread = random.uniform(0.02, 0.05)
        best_bid = max(0.01, displayed_prob - spread / 2)
        best_ask = min(0.99, displayed_prob + spread / 2)

        bids = []
        asks = []
        for i in range(5):
            bid_price = round(best_bid - i * 0.01, 2)
            ask_price = round(best_ask + i * 0.01, 2)
            bid_size = random.uniform(500, 3000)
            ask_size = random.uniform(500, 3000)
            if bid_price > 0:
                bids.append((bid_price, round(bid_size, 0)))
            if ask_price < 1:
                asks.append((ask_price, round(ask_size, 0)))

        return OrderBook(
            token_id="demo-btc-5m-yes",
            bids=bids,
            asks=asks,
            timestamp=time.time(),
        )


# ═══════════════════════════════════════════════════════════
#  Demo Engine State
# ═══════════════════════════════════════════════════════════

class DemoEngine:
    """Full trading pipeline with simulated data."""

    def __init__(self):
        self.settings = Settings()
        self.market = SimulatedMarket()
        self.volatility = VolatilityEstimator(span=60, min_samples=5)
        self.bayesian = BayesianSignal(prior=0.5)
        self.edge_detector = EdgeDetector(window=80, base_z_threshold=1.8, min_net_ev=0.002)
        self.kelly = KellySizer(fraction=0.5, max_fraction=0.05, max_absolute=5000)
        self.lmsr = LMSRImpact()
        self.stoikov = StoikovQuoter(gamma=0.18, max_inventory=3.0)
        self.order_manager = OrderManager(trading_mode="paper")
        self.hedge = HedgeManager(max_net_exposure=10000)

        self.bankroll = self.settings.initial_bankroll
        self.initial_bankroll = self.settings.initial_bankroll
        self.peak_bankroll = self.bankroll
        self.total_pnl = 0.0
        self.total_trades = 0
        self.wins = 0
        self.losses = 0
        self.consecutive_losses = 0
        self.max_drawdown = 0.0
        self.cycles = 0
        self.signals_generated = 0
        self.signals_rejected = 0
        self.start_time = time.time()
        self.running = False

        self.pnl_history = []
        self.btc_price = 87_500.0
        self.binance_connected = True
        self.coinbase_connected = True

        # Warm up volatility
        for i in range(20):
            p = 87_500 + random.gauss(0, 20)
            self.volatility.update(p)

    @property
    def win_rate(self) -> float:
        return self.wins / self.total_trades if self.total_trades > 0 else 0.0

    @property
    def roi_pct(self) -> float:
        return (self.bankroll - self.initial_bankroll) / self.initial_bankroll * 100

    @property
    def trades_per_hour(self) -> float:
        elapsed = time.time() - self.start_time
        return self.total_trades / (elapsed / 3600) if elapsed > 60 else 0.0

    @property
    def current_drawdown(self) -> float:
        if self.peak_bankroll <= 0:
            return 0.0
        return (self.peak_bankroll - self.bankroll) / self.peak_bankroll

    def run_cycle(self):
        """Execute one full trading cycle."""
        self.cycles += 1

        # 1. Generate price tick
        self.btc_price = self.market.tick()
        vol = self.volatility.update(self.btc_price)

        if vol is None or vol == 0:
            return

        # 2. Compute spot delta (last 10 ticks)
        spot_delta = random.gauss(0, vol * self.btc_price * 5)

        # 3. Generate Polymarket orderbook with lag
        # Fair probability based on recent momentum
        momentum = spot_delta / (vol * self.btc_price * 10 + 1e-8)
        fair_up_prob = 0.5 + 0.5 * math.tanh(momentum)
        book = self.market.get_polymarket_book(fair_up_prob)

        # 4. Bayesian update
        bayes_state = self.bayesian.update(
            spot_delta=spot_delta,
            volatility=vol,
            book_imbalance=book.get_imbalance(),
        )
        fair_price = self.bayesian.fair_price_yes

        # 5. Edge detection
        edge = self.edge_detector.evaluate(
            poly_price=book.mid_price,
            fair_price=fair_price,
            volatility=vol,
        )

        if not edge.is_signal:
            self.signals_rejected += 1
            return

        self.signals_generated += 1

        # 6. Kelly sizing
        buy_price = book.best_ask if edge.direction == "BUY_YES" else (1 - book.best_bid)
        buy_price = max(0.01, min(0.99, buy_price))
        odds = KellySizer.binary_odds(buy_price)
        win_prob = fair_price if edge.direction == "BUY_YES" else (1 - fair_price)
        kelly_result = self.kelly.size(win_prob=win_prob, odds=odds, bankroll=self.bankroll)

        if kelly_result.position_size <= 0:
            return

        # 7. LMSR impact
        impact = self.lmsr.estimate(
            order_size=kelly_result.position_size,
            side="BUY",
            book=book,
        )
        position_size = min(kelly_result.position_size, impact.recommended_size)
        if position_size < 1.0:
            return

        # 8. Stoikov quote
        sigma2 = vol ** 2
        time_remaining = random.uniform(0.2, 0.9)
        quote = self.stoikov.quote(mid_price=book.mid_price, sigma2=sigma2, time_remaining=time_remaining)

        # 9. Simulate trade outcome
        # Win probability is edge-dependent: higher edge → higher chance
        actual_win_prob = 0.5 + edge.net_ev * 8  # scale net_ev into probability boost
        actual_win_prob = max(0.4, min(0.95, actual_win_prob))
        won = random.random() < actual_win_prob

        if won:
            profit = position_size * (1 - buy_price) / buy_price * 0.3
            profit = max(0.5, min(profit, position_size * 0.5))
            self.bankroll += profit
            self.total_pnl += profit
            self.wins += 1
            self.consecutive_losses = 0
            self.stoikov.on_fill("BUY", 1)

            stream.log("FILL", f"{edge.direction} ${position_size:.0f} @ {buy_price:.3f} WIN +${profit:.2f}",
                        direction=edge.direction, size=round(position_size, 0), profit=round(profit, 2))
        else:
            loss = position_size * 0.15
            loss = max(0.5, min(loss, position_size * 0.3))
            self.bankroll -= loss
            self.total_pnl -= loss
            self.losses += 1
            self.consecutive_losses += 1

            stream.log("FILL", f"{edge.direction} ${position_size:.0f} @ {buy_price:.3f} LOSS -${loss:.2f}",
                        direction=edge.direction, size=round(position_size, 0), loss=round(loss, 2))

        self.total_trades += 1
        self.hedge.on_fill(edge.direction, position_size)

        # Track peak / drawdown
        if self.bankroll > self.peak_bankroll:
            self.peak_bankroll = self.bankroll
        dd = self.current_drawdown
        if dd > self.max_drawdown:
            self.max_drawdown = dd

        # Record P&L point
        self.pnl_history.append({
            "time": time.time(),
            "bankroll": round(self.bankroll, 2),
            "pnl": round(self.total_pnl, 2),
            "trade_count": self.total_trades,
        })

        # Hedge check
        hedge_state = self.hedge.check()
        if hedge_state.hedge_needed > 0:
            stream.log("HEDGE", f"Rebalancing: {hedge_state.hedge_side} ${hedge_state.hedge_needed:.0f}")
            self.hedge.reset()
            self.stoikov.on_expiry()

        # Market expiry (every ~60 cycles, reset for new 5-min window)
        if self.cycles % 60 == 0:
            self.bayesian.reset()
            self.stoikov.on_expiry()
            stream.log("SCAN", f"New 5-min market window, cycle #{self.cycles}")


# ═══════════════════════════════════════════════════════════
#  Global State
# ═══════════════════════════════════════════════════════════

engine: DemoEngine | None = None
engine_running = False


# ═══════════════════════════════════════════════════════════
#  Routes
# ═══════════════════════════════════════════════════════════

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/config", methods=["GET"])
def get_config():
    s = Settings()
    return jsonify({
        "trading_mode": s.trading_mode,
        "initial_bankroll": s.initial_bankroll,
        "max_position_size": s.max_position_size,
        "max_drawdown_pct": s.max_drawdown_pct,
        "kelly_fraction": s.kelly_fraction,
        "z_score_threshold": s.z_score_threshold,
        "min_net_ev": s.min_net_ev,
        "gamma_risk": s.gamma_risk,
        "max_inventory": s.max_inventory,
        "order_ttl_seconds": s.order_ttl_seconds,
        "poll_interval": s.poll_interval,
        "circuit_breaker_enabled": s.circuit_breaker_enabled,
        "circuit_max_drawdown": s.circuit_max_drawdown,
        "circuit_max_consecutive_losses": s.circuit_max_consecutive_losses,
    })


@app.route("/api/config", methods=["POST"])
def update_config():
    return jsonify({"status": "ok"})


@app.route("/api/stats")
def get_stats():
    if engine is None:
        return jsonify({"running": False})
    return jsonify({
        "running": engine.running,
        "bankroll": round(engine.bankroll, 2),
        "initial_bankroll": round(engine.initial_bankroll, 2),
        "roi_pct": round(engine.roi_pct, 2),
        "win_rate": round(engine.win_rate * 100, 1),
        "total_trades": engine.total_trades,
        "wins": engine.wins,
        "losses": engine.losses,
        "total_pnl": round(engine.total_pnl, 2),
        "trades_per_hour": round(engine.trades_per_hour, 1),
        "max_drawdown": round(engine.max_drawdown * 100, 2),
        "current_drawdown": round(engine.current_drawdown * 100, 2),
        "cycles": engine.cycles,
        "signals_generated": engine.signals_generated,
        "signals_rejected": engine.signals_rejected,
        "consecutive_losses": engine.consecutive_losses,
        "peak_bankroll": round(engine.peak_bankroll, 2),
    })


@app.route("/api/stream")
def get_stream():
    entries = TrainingStream.get().last(50)
    return jsonify([{
        "timestamp": e.timestamp,
        "tag": e.tag,
        "message": e.message,
    } for e in entries])


@app.route("/api/orders")
def get_orders():
    if engine is None:
        return jsonify({"active": [], "fills": []})
    # Generate sample from recent stream entries
    fills = []
    for e in TrainingStream.get().last(20):
        if e.tag == "FILL":
            fills.append({
                "id": f"ORD-{len(fills)+1:04d}",
                "side": "BUY",
                "price": round(random.uniform(0.35, 0.65), 3),
                "size": round(random.uniform(50, 300), 2),
                "status": "filled",
                "time": e.timestamp,
            })
    return jsonify({"active": [], "fills": fills[-15:]})


@app.route("/api/pnl_history")
def get_pnl_history():
    if engine is None:
        return jsonify([])
    return jsonify(engine.pnl_history[-500:])


@app.route("/api/module_status")
def get_module_status():
    if engine is None:
        return jsonify({"running": False})
    return jsonify({
        "running": engine.running,
        "binance_connected": engine.binance_connected,
        "coinbase_connected": engine.coinbase_connected,
        "binance_price": round(engine.btc_price, 2),
        "bayesian_posterior": round(engine.bayesian.posterior, 4),
        "volatility": round(engine.volatility.current, 8) if engine.volatility.current else None,
        "stoikov_inventory": round(engine.stoikov.inventory, 2),
        "hedge_net_exposure": round(engine.hedge.net_exposure, 2),
        "circuit_tripped": engine.consecutive_losses >= 15,
        "circuit_reason": "CONSECUTIVE_LOSSES" if engine.consecutive_losses >= 15 else "",
        "active_orders": 0,
        "trading_mode": "paper",
        "signals_generated": engine.signals_generated,
    })


# ═══════════════════════════════════════════════════════════
#  Socket.IO
# ═══════════════════════════════════════════════════════════

@socketio.on("connect")
def on_connect():
    emit("connected", {"status": "ok"})


@socketio.on("start_engine")
def on_start_engine(data=None):
    global engine, engine_running
    if engine_running:
        emit("engine_status", {"status": "already_running"})
        return
    engine = DemoEngine()
    engine.running = True
    engine_running = True
    emit("engine_status", {"status": "started", "mode": "paper"})
    logger.info("Demo engine started")


@socketio.on("stop_engine")
def on_stop_engine():
    global engine_running
    if engine:
        engine.running = False
    engine_running = False
    emit("engine_status", {"status": "stopped"})
    logger.info("Demo engine stopped")


@socketio.on("cancel_all_orders")
def on_cancel_all():
    emit("orders_cancelled", {"status": "ok"})


# ═══════════════════════════════════════════════════════════
#  Background Trading Loop
# ═══════════════════════════════════════════════════════════

def trading_loop():
    """Run trading cycles in background."""
    while True:
        socketio.sleep(0.3)  # ~3 cycles/second → ~200/min
        if engine and engine.running:
            try:
                engine.run_cycle()

                # Push real-time update on trades
                if engine.total_trades > 0 and engine.cycles % 3 == 0:
                    socketio.emit("trade_update", {
                        "bankroll": round(engine.bankroll, 2),
                        "total_pnl": round(engine.total_pnl, 2),
                        "trade_count": engine.total_trades,
                        "win_rate": round(engine.win_rate * 100, 1),
                    })
            except Exception as e:
                logger.exception(f"Cycle error: {e}")


def stats_emitter():
    """Push stats to clients every second."""
    while True:
        socketio.sleep(1)
        if engine and engine.running:
            socketio.emit("stats_update", {
                "bankroll": round(engine.bankroll, 2),
                "roi_pct": round(engine.roi_pct, 2),
                "win_rate": round(engine.win_rate * 100, 1),
                "total_trades": engine.total_trades,
                "trades_per_hour": round(engine.trades_per_hour, 1),
                "total_pnl": round(engine.total_pnl, 2),
                "max_drawdown": round(engine.max_drawdown * 100, 2),
                "cycles": engine.cycles,
                "signals_generated": engine.signals_generated,
                "consecutive_losses": engine.consecutive_losses,
            })

            # Stream latest
            entries = TrainingStream.get().last(3)
            for e in entries:
                socketio.emit("stream_entry", {
                    "timestamp": e.timestamp,
                    "tag": e.tag,
                    "message": e.message,
                })


# ═══════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════

def main():
    print()
    print("═" * 60)
    print("  ARB ENGINE — DEMO MODE")
    print("  Simulated BTC market data (no external connections needed)")
    print()
    print("  Open http://localhost:5000 in your browser")
    print("  Click 'Start' to begin trading")
    print("═" * 60)
    print()

    socketio.start_background_task(trading_loop)
    socketio.start_background_task(stats_emitter)
    socketio.run(app, host="0.0.0.0", port=5000, debug=False, allow_unsafe_werkzeug=True)


if __name__ == "__main__":
    main()
