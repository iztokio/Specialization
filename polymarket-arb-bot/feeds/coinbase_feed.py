"""Secondary BTC/USD price feed from Coinbase WebSocket for cross-validation."""

from __future__ import annotations

import asyncio
import time
from collections import deque

import orjson
import websockets

from feeds.binance_feed import PriceTick
from monitoring.logger import get_logger

logger = get_logger("coinbase")


class CoinbaseFeed:
    """Streams BTC-USD matches from Coinbase Advanced Trade WebSocket."""

    def __init__(
        self,
        url: str = "wss://ws-feed.exchange.coinbase.com",
        history_seconds: int = 300,
    ):
        self.url = url
        self._history: deque[PriceTick] = deque(maxlen=50_000)
        self._last_tick: PriceTick | None = None
        self._history_seconds = history_seconds
        self._running = False
        self._connected = asyncio.Event()

    @property
    def last_price(self) -> float | None:
        return self._last_tick.price if self._last_tick else None

    @property
    def connected(self) -> bool:
        return self._connected.is_set()

    def get_delta(self, seconds: float = 10.0) -> float:
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
                logger.warning(f"Coinbase WS disconnected: {exc}. Reconnecting in 2s…")
                self._connected.clear()
                await asyncio.sleep(2)

    async def stop(self):
        self._running = False
        self._connected.clear()

    async def wait_ready(self, timeout: float = 10.0):
        await asyncio.wait_for(self._connected.wait(), timeout)

    async def _connect(self):
        async with websockets.connect(self.url, ping_interval=20) as ws:
            subscribe = {
                "type": "subscribe",
                "product_ids": ["BTC-USD"],
                "channels": ["matches"],
            }
            await ws.send(orjson.dumps(subscribe).decode())
            logger.info("Coinbase WS connected")
            self._connected.set()

            async for raw in ws:
                if not self._running:
                    break
                data = orjson.loads(raw)
                if data.get("type") != "match":
                    continue
                tick = PriceTick(
                    price=float(data["price"]),
                    timestamp=time.time(),
                    volume=float(data.get("size", 0)),
                )
                self._last_tick = tick
                self._history.append(tick)
                self._prune_history()

    def _prune_history(self):
        cutoff = time.time() - self._history_seconds
        while self._history and self._history[0].timestamp < cutoff:
            self._history.popleft()
