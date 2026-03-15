"""
Records live market data to disk for offline backtesting.

Captures:
- Binance BTC/USDT trades (price, volume, timestamp)
- Polymarket orderbook snapshots
- All signal/decision events

Format: JSONL (one JSON object per line) for easy streaming reads.
"""

from __future__ import annotations

import os
import time
from pathlib import Path

import orjson

from monitoring.logger import get_logger

logger = get_logger("recorder")


class DataRecorder:
    """Records market data and events to JSONL files."""

    def __init__(self, base_dir: str = "./data"):
        self.base_dir = Path(base_dir)
        self._files: dict[str, object] = {}
        self._enabled = True

    async def start(self):
        """Initialize recording directories and files."""
        date_str = time.strftime("%Y%m%d")
        self._session_dir = self.base_dir / date_str
        self._session_dir.mkdir(parents=True, exist_ok=True)

        ts = time.strftime("%H%M%S")
        self._files = {
            "ticks": open(self._session_dir / f"ticks_{ts}.jsonl", "ab"),
            "books": open(self._session_dir / f"books_{ts}.jsonl", "ab"),
            "signals": open(self._session_dir / f"signals_{ts}.jsonl", "ab"),
            "trades": open(self._session_dir / f"trades_{ts}.jsonl", "ab"),
        }
        logger.info(f"Recording to {self._session_dir}")

    async def stop(self):
        for f in self._files.values():
            f.close()

    def record_tick(self, price: float, volume: float, source: str = "binance"):
        if not self._enabled:
            return
        self._write("ticks", {
            "t": time.time(),
            "p": price,
            "v": volume,
            "src": source,
        })

    def record_book(self, token_id: str, bids: list, asks: list):
        if not self._enabled:
            return
        self._write("books", {
            "t": time.time(),
            "token": token_id,
            "bids": bids[:5],  # top 5 levels
            "asks": asks[:5],
        })

    def record_signal(self, signal_type: str, **kwargs):
        if not self._enabled:
            return
        self._write("signals", {
            "t": time.time(),
            "type": signal_type,
            **kwargs,
        })

    def record_trade(self, **kwargs):
        if not self._enabled:
            return
        self._write("trades", {
            "t": time.time(),
            **kwargs,
        })

    def _write(self, stream: str, data: dict):
        f = self._files.get(stream)
        if f:
            f.write(orjson.dumps(data) + b"\n")
