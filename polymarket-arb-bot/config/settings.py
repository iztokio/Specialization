"""Centralized configuration loaded from environment variables."""

from __future__ import annotations

import os
from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # ── Polymarket ───────────────────────────────────────────
    polymarket_api_key: str = ""
    polymarket_secret: str = ""
    polymarket_passphrase: str = ""
    private_key: str = ""
    polymarket_funder: str = ""
    clob_url: str = "https://clob.polymarket.com"
    gamma_url: str = "https://gamma-api.polymarket.com"
    chain_id: int = 137  # Polygon

    # ── Trading mode ─────────────────────────────────────────
    trading_mode: Literal["paper", "live"] = "paper"

    # ── Risk parameters ──────────────────────────────────────
    initial_bankroll: float = 2050.0
    max_position_size: float = 5000.0
    max_drawdown_pct: float = 0.20
    kelly_fraction: float = 0.5
    max_kelly_f: float = 0.05  # absolute cap per trade
    max_consecutive_losses: int = 10
    max_inventory: float = 3.0

    # ── Signal parameters ────────────────────────────────────
    z_score_threshold: float = 2.0
    min_net_ev: float = 0.003
    bayesian_prior: float = 0.5
    edge_window: int = 100  # rolling window for Z-score
    vol_ewma_span: int = 60  # seconds for EWMA volatility

    # ── Execution ────────────────────────────────────────────
    gamma_risk: float = 0.18  # Stoikov gamma
    order_ttl_seconds: float = 15.0  # cancel unfilled orders after
    poll_interval: float = 0.5  # main loop sleep (seconds)
    market_scan_interval: float = 30.0  # re-scan markets every N seconds

    # ── Feeds ────────────────────────────────────────────────
    binance_ws_url: str = "wss://stream.binance.com:9443/ws/btcusdt@trade"
    coinbase_ws_url: str = "wss://ws-feed.exchange.coinbase.com"
    feed_timeout: float = 5.0  # reconnect if no data for N seconds

    # ── Circuit breakers ─────────────────────────────────────
    circuit_breaker_enabled: bool = True
    circuit_max_drawdown: float = 0.20  # stop if bankroll drops 20%
    circuit_max_consecutive_losses: int = 15
    circuit_cooldown_seconds: float = 300.0  # 5 min cooldown

    # ── Logging / Data ───────────────────────────────────────
    log_level: str = "INFO"
    data_record_dir: str = "./data"
    record_data: bool = True

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
