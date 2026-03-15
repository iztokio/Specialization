"""Real-time BTC/USDT price feed from Binance WebSocket."""

from __future__ import annotations

import asyncio
import time
from collections import deque
from dataclasses import dataclass, field

import orjson
import websockets

from monitoring.logger import get_logger

logger = get_logger("binance")


@dataclass
class PriceTick:
    price: float
    timestamp: float  # unix seconds
    volume: float = 0.0


class BinanceFeed:
    """Streams BTC/USDT trades from Binance and maintains recent price history."""

    def __init__(
        self,
        url: str = "wss://stream.binance.com:9443/ws/btcusdt@trade",
        history_seconds: int = 300,
    ):
        self.url = url
        self._history: deque[PriceTick] = deque(maxlen=50_000)
        self._last_tick: PriceTick | None = None
        self._history_seconds = history_seconds
        self._running = False
        self._connected = asyncio.Event()
        self._callbacks: list = []

    # ── Public API ───────────────────────────────────────────

    @property
    def last_price(self) -> float | None:
        return self._last_tick.price if self._last_tick else None

    @property
    def last_tick(self) -> PriceTick | None:
        return self._last_tick

    @property
    def connected(self) -> bool:
        return self._connected.is_set()

    def on_tick(self, callback):
        """Register callback(tick: PriceTick) called on every new trade."""
        self._callbacks.append(callback)

    def get_delta(self, seconds: float = 10.0) -> float:
        """Price change over the last N seconds."""
        if not self._history:
            return 0.0
        now = time.time()
        cutoff = now - seconds
        past_price = None
        for tick in self._history:
            if tick.timestamp >= cutoff:
                past_price = tick.price
                break
        if past_price is None:
            return 0.0
        return self._last_tick.price - past_price

    def get_prices(self, seconds: float = 60.0) -> list[float]:
        """Return price series for the last N seconds."""
        now = time.time()
        cutoff = now - seconds
        return [t.price for t in self._history if t.timestamp >= cutoff]

    def get_vwap(self, seconds: float = 60.0) -> float | None:
        """Volume-weighted average price over last N seconds."""
        now = time.time()
        cutoff = now - seconds
        total_vol = 0.0
        total_pv = 0.0
        for t in self._history:
            if t.timestamp >= cutoff:
                total_pv += t.price * t.volume
                total_vol += t.volume
        return total_pv / total_vol if total_vol > 0 else None

    # ── Lifecycle ────────────────────────────────────────────

    async def start(self):
        self._running = True
        while self._running:
            try:
                await self._connect()
            except (
                websockets.ConnectionClosed,
                websockets.InvalidStatusCode,
                OSError,
            ) as exc:
                logger.warning(f"Binance WS disconnected: {exc}. Reconnecting in 2s…")
                self._connected.clear()
                await asyncio.sleep(2)

    async def stop(self):
        self._running = False
        self._connected.clear()

    async def wait_ready(self, timeout: float = 10.0):
        await asyncio.wait_for(self._connected.wait(), timeout)

    # ── Internal ─────────────────────────────────────────────

    async def _connect(self):
        async with websockets.connect(self.url, ping_interval=20) as ws:
            logger.info("Binance WS connected")
            self._connected.set()
            async for raw in ws:
                if not self._running:
                    break
                data = orjson.loads(raw)
                tick = PriceTick(
                    price=float(data["p"]),
                    timestamp=float(data["T"]) / 1000.0,
                    volume=float(data["q"]),
                )
                self._last_tick = tick
                self._history.append(tick)
                self._prune_history()
                for cb in self._callbacks:
                    try:
                        cb(tick)
                    except Exception:
                        logger.exception("Tick callback error")

    def _prune_history(self):
        cutoff = time.time() - self._history_seconds
        while self._history and self._history[0].timestamp < cutoff:
            self._history.popleft()
