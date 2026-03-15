"""
Web dashboard for the Polymarket Arbitrage Bot.

Flask + Socket.IO for real-time updates.
Serves a single-page dashboard with:
- Live metrics (balance, ROI, win rate, trades/hr)
- P&L chart
- Training stream (live log)
- Order history
- Controls (start/stop, mode switch, config editor)
- System status (feed connections, module health)
"""

from __future__ import annotations

import asyncio
import json
import os
import sys
import threading
import time
from pathlib import Path

from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO, emit

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from eth_account import Account

from config.settings import Settings
from engine.arbitrage import ArbitrageEngine
from monitoring.logger import TrainingStream, get_logger

logger = get_logger("web")

app = Flask(
    __name__,
    template_folder="templates",
    static_folder="static",
)
app.config["SECRET_KEY"] = os.urandom(24).hex()
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")

# ── Global state ─────────────────────────────────────────────
engine: ArbitrageEngine | None = None
engine_thread: threading.Thread | None = None
engine_loop: asyncio.AbstractEventLoop | None = None
settings: Settings | None = None
pnl_history: list[dict] = []
wallet_state: dict | None = None


def get_or_create_settings() -> Settings:
    global settings
    if settings is None:
        settings = Settings()
    return settings


# ── Routes ───────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/config", methods=["GET"])
def get_config():
    s = get_or_create_settings()
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
    global settings
    data = request.json
    if not data:
        return jsonify({"error": "No data"}), 400

    s = get_or_create_settings()

    # Update mutable fields
    for key, value in data.items():
        if hasattr(s, key):
            expected_type = type(getattr(s, key))
            try:
                setattr(s, key, expected_type(value))
            except (ValueError, TypeError):
                pass

    settings = s
    logger.info(f"Config updated: {list(data.keys())}")
    return jsonify({"status": "ok"})


@app.route("/api/stats")
def get_stats():
    if engine is None:
        return jsonify({"running": False})
    s = engine.stats
    return jsonify({
        "running": True,
        "bankroll": round(s.bankroll, 2),
        "initial_bankroll": round(s.initial_bankroll, 2),
        "roi_pct": round(s.roi_pct, 2),
        "win_rate": round(s.win_rate * 100, 1),
        "total_trades": s.total_trades,
        "wins": s.wins,
        "losses": s.losses,
        "total_pnl": round(s.total_pnl, 2),
        "trades_per_hour": round(s.trades_per_hour, 1),
        "max_drawdown": round(s.max_drawdown * 100, 2),
        "current_drawdown": round(s.current_drawdown * 100, 2),
        "cycles": s.cycles,
        "signals_generated": s.signals_generated,
        "signals_rejected": s.signals_rejected,
        "consecutive_losses": s.consecutive_losses,
        "peak_bankroll": round(s.peak_bankroll, 2),
    })


@app.route("/api/stream")
def get_stream():
    entries = TrainingStream.get().last(50)
    return jsonify([
        {
            "timestamp": e.timestamp,
            "tag": e.tag,
            "message": e.message,
            "values": e.values,
        }
        for e in entries
    ])


@app.route("/api/orders")
def get_orders():
    if engine is None:
        return jsonify([])
    fills = engine.order_manager.get_recent_fills(30)
    active = engine.order_manager.get_active_orders()
    return jsonify({
        "active": [
            {
                "id": o.id,
                "token_id": o.token_id[:12] + "...",
                "side": o.side.value,
                "price": o.price,
                "size": o.size,
                "status": o.status.value,
                "age_seconds": round(time.time() - o.created_at, 1),
            }
            for o in active
        ],
        "fills": [
            {
                "id": o.id,
                "side": o.side.value,
                "price": o.filled_price,
                "size": o.filled_size,
                "status": o.status.value,
                "time": o.updated_at,
            }
            for o in fills
        ],
    })


@app.route("/api/pnl_history")
def get_pnl_history():
    return jsonify(pnl_history[-500:])


@app.route("/api/module_status")
def get_module_status():
    if engine is None:
        return jsonify({"running": False})
    return jsonify({
        "running": True,
        "binance_connected": engine.binance.connected,
        "coinbase_connected": engine.coinbase.connected,
        "binance_price": engine.binance.last_price,
        "bayesian_posterior": round(engine.bayesian.posterior, 4),
        "volatility": round(engine.volatility.current, 8) if engine.volatility.current else None,
        "stoikov_inventory": round(engine.stoikov.inventory, 2),
        "hedge_net_exposure": round(engine.hedge.net_exposure, 2),
        "circuit_tripped": engine.circuit.is_tripped,
        "circuit_reason": engine.circuit.reason if engine.circuit.is_tripped else "",
        "active_orders": engine.order_manager.active_count,
        "trading_mode": engine.settings.trading_mode,
    })


# ── Wallet API ──────────────────────────────────────────────

@app.route("/api/wallet/connect", methods=["POST"])
def wallet_connect():
    global wallet_state
    data = request.json or {}

    try:
        if data.get("source") == "env":
            pk = os.environ.get("PRIVATE_KEY", "")
            if not pk or pk == "your_polygon_private_key_here":
                return jsonify({"status": "error", "error": "No PRIVATE_KEY in .env"}), 400
        else:
            pk = data.get("private_key", "")

        if not pk:
            return jsonify({"status": "error", "error": "No private key provided"}), 400

        if not pk.startswith("0x"):
            pk = "0x" + pk

        acct = Account.from_key(pk)
        wallet_state = {"address": acct.address, "private_key": pk}

        os.environ["PRIVATE_KEY"] = pk

        funder = data.get("funder")
        if funder:
            os.environ["POLYMARKET_FUNDER"] = funder

        logger.info(f"Wallet connected: {acct.address[:10]}...")

        return jsonify({
            "status": "ok",
            "address": acct.address,
            "usdc_balance": "Check on Polygon",
            "matic_balance": "Check on Polygon",
            "allowance": "Will be set on first trade",
            "api_keys": False,
        })
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 400


@app.route("/api/wallet/generate", methods=["POST"])
def wallet_generate():
    try:
        acct = Account.create()
        return jsonify({
            "status": "ok",
            "address": acct.address,
            "private_key": acct.key.hex() if isinstance(acct.key, bytes) else str(acct.key),
        })
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 400


@app.route("/api/wallet/disconnect", methods=["POST"])
def wallet_disconnect():
    global wallet_state
    wallet_state = None
    logger.info("Wallet disconnected")
    return jsonify({"status": "ok"})


# ── Socket.IO events ────────────────────────────────────────

@socketio.on("connect")
def on_connect():
    logger.info("Dashboard client connected")
    emit("connected", {"status": "ok"})


@socketio.on("start_engine")
def on_start_engine(data=None):
    global engine, engine_thread, engine_loop
    if engine is not None:
        emit("engine_status", {"status": "already_running"})
        return

    s = get_or_create_settings()
    engine = ArbitrageEngine(s)

    # Record P&L periodically
    original_on_fill = engine._on_fill

    def patched_on_fill(order):
        original_on_fill(order)
        pnl_history.append({
            "time": time.time(),
            "bankroll": round(engine.stats.bankroll, 2),
            "pnl": round(engine.stats.total_pnl, 2),
            "trade_count": engine.stats.total_trades,
        })
        # Push to client
        socketio.emit("trade_update", {
            "bankroll": round(engine.stats.bankroll, 2),
            "total_pnl": round(engine.stats.total_pnl, 2),
            "trade_count": engine.stats.total_trades,
            "win_rate": round(engine.stats.win_rate * 100, 1),
        })

    engine._on_fill = patched_on_fill
    engine.order_manager._fill_callbacks = [patched_on_fill]

    def run_engine():
        global engine_loop
        engine_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(engine_loop)
        try:
            engine_loop.run_until_complete(engine.start())
        except Exception as e:
            logger.exception("Engine crashed")
            socketio.emit("engine_error", {"error": str(e)})

    engine_thread = threading.Thread(target=run_engine, daemon=True)
    engine_thread.start()

    emit("engine_status", {"status": "started", "mode": s.trading_mode})
    logger.info(f"Engine started in {s.trading_mode} mode")


@socketio.on("stop_engine")
def on_stop_engine():
    global engine, engine_thread, engine_loop
    if engine is None:
        emit("engine_status", {"status": "not_running"})
        return

    if engine_loop:
        engine_loop.call_soon_threadsafe(
            lambda: asyncio.ensure_future(engine.stop())
        )

    engine = None
    engine_thread = None
    engine_loop = None
    emit("engine_status", {"status": "stopped"})
    logger.info("Engine stopped")


@socketio.on("cancel_all_orders")
def on_cancel_all():
    if engine and engine_loop:
        engine_loop.call_soon_threadsafe(
            lambda: asyncio.ensure_future(engine.order_manager.cancel_all())
        )
        emit("orders_cancelled", {"status": "ok"})


# ── Background emitter ───────────────────────────────────────

def background_emitter():
    """Push updates to connected clients every second."""
    while True:
        socketio.sleep(1)
        if engine:
            try:
                stats = engine.stats
                socketio.emit("stats_update", {
                    "bankroll": round(stats.bankroll, 2),
                    "roi_pct": round(stats.roi_pct, 2),
                    "win_rate": round(stats.win_rate * 100, 1),
                    "total_trades": stats.total_trades,
                    "trades_per_hour": round(stats.trades_per_hour, 1),
                    "total_pnl": round(stats.total_pnl, 2),
                    "max_drawdown": round(stats.max_drawdown * 100, 2),
                    "cycles": stats.cycles,
                    "signals_generated": stats.signals_generated,
                    "consecutive_losses": stats.consecutive_losses,
                })

                # Stream entries
                entries = TrainingStream.get().last(5)
                if entries:
                    latest = entries[-1]
                    socketio.emit("stream_entry", {
                        "timestamp": latest.timestamp,
                        "tag": latest.tag,
                        "message": latest.message,
                    })
            except Exception:
                pass


# ── Main ─────────────────────────────────────────────────────

def main():
    print("\n" + "=" * 60)
    print("  ARB ENGINE — WEB DASHBOARD")
    print("  Open http://localhost:5000 in your browser")
    print("=" * 60 + "\n")

    socketio.start_background_task(background_emitter)
    socketio.run(app, host="0.0.0.0", port=5000, debug=False, allow_unsafe_werkzeug=True)


if __name__ == "__main__":
    main()
