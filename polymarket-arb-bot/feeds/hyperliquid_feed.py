"""Hyperliquid perpetual futures feed: BTC-PERP orderbook and price data.

Replaces PolymarketFeed for cross-exchange arbitrage:
  Spot (Binance/Coinbase) vs Perp (Hyperliquid BTC-PERP)

Uses the same OrderBook/Market dataclasses so the engine pipeline
(Bayes → Edge → Kelly → Stoikov → Order) works unchanged.
"""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from typing import Optional

import httpx

from monitoring.logger import get_logger

logger = get_logger("hyperliquid")


@dataclass
class OrderBook:
    """Simplified orderbook snapshot."""

    token_id: str
    bids: list[tuple[float, float]] = field(default_factory=list)  # (price, size)
    asks: list[tuple[float, float]] = field(default_factory=list)
    timestamp: float = 0.0

    @property
    def best_bid(self) -> float:
        return self.bids[0][0] if self.bids else 0.0

    @property
    def best_ask(self) -> float:
        return self.asks[0][0] if self.asks else 1.0

    @property
    def mid_price(self) -> float:
        return (self.best_bid + self.best_ask) / 2.0

    @property
    def spread(self) -> float:
        return self.best_ask - self.best_bid

    @property
    def bid_depth(self) -> float:
        return sum(size for _, size in self.bids)

    @property
    def ask_depth(self) -> float:
        return sum(size for _, size in self.asks)

    def get_imbalance(self) -> float:
        """Order book imbalance: +1 = all bids, -1 = all asks, 0 = balanced."""
        total = self.bid_depth + self.ask_depth
        if total == 0:
            return 0.0
        return (self.bid_depth - self.ask_depth) / total


@dataclass
class Market:
    """Represents a virtual arbitrage window for BTC-PERP spread trading.

    Maps to the engine's Market interface: condition_id, token IDs, expiry.
    For perps there's no binary resolution — we use rolling time windows.
    """

    condition_id: str  # e.g., "BTC-PERP"
    question: str  # e.g., "BTC-PERP vs Spot spread"
    yes_token_id: str  # "BTC" — used as coin name for Hyperliquid
    no_token_id: str  # "BTC" — same coin, opposite side
    end_time: float  # virtual window end (for Stoikov time decay)
    active: bool = True
    outcome_prices: tuple[float, float] = (0.5, 0.5)

    @property
    def seconds_to_expiry(self) -> float:
        return max(0, self.end_time - time.time())

    @property
    def time_remaining_normalized(self) -> float:
        """Normalized [0, 1] where 1 = full window."""
        return min(1.0, self.seconds_to_expiry / 300.0)


class HyperliquidFeed:
    """Fetches BTC-PERP orderbook and price data from Hyperliquid API.

    Interface-compatible with PolymarketFeed so the engine works unchanged.
    """

    API_URL = "https://api.hyperliquid.xyz"

    def __init__(
        self,
        api_url: str = "https://api.hyperliquid.xyz",
        coin: str = "BTC",
        window_seconds: int = 300,
    ):
        self.api_url = api_url.rstrip("/")
        self.coin = coin
        self._window_seconds = window_seconds
        self._client: httpx.AsyncClient | None = None
        self._orderbooks: dict[str, OrderBook] = {}
        self._last_mid: float = 0.0

    # ── Lifecycle ────────────────────────────────────────────

    async def start(self):
        self._client = httpx.AsyncClient(timeout=10.0)
        logger.info(f"Hyperliquid feed started (coin={self.coin})")

    async def stop(self):
        if self._client:
            await self._client.aclose()

    # ── Market Discovery (simplified for perps) ──────────────

    async def discover_5min_btc_markets(self) -> list[Market]:
        """Return a single virtual 'market' representing the BTC-PERP spread.

        For perpetual futures, there's no market resolution — we use rolling
        5-minute windows to give the Stoikov quoter a time horizon.
        """
        # Verify connectivity by fetching mid price
        mid = await self.get_midpoint(self.coin)
        if mid is None or mid <= 0:
            logger.warning("Cannot fetch Hyperliquid BTC mid price")
            return []

        self._last_mid = mid

        # Create a rolling window market
        now = time.time()
        window_end = now - (now % self._window_seconds) + self._window_seconds

        market = Market(
            condition_id=f"{self.coin}-PERP",
            question=f"{self.coin}-PERP vs Spot spread",
            yes_token_id=self.coin,  # LONG side
            no_token_id=self.coin,   # SHORT side (same coin)
            end_time=window_end,
            active=True,
            outcome_prices=(0.5, 0.5),
        )

        logger.info(
            f"Hyperliquid {self.coin}-PERP: mid=${mid:,.2f}, "
            f"window expires in {market.seconds_to_expiry:.0f}s"
        )
        return [market]

    # ── Orderbook ─────────────────────────────────────────────

    async def get_orderbook(self, token_id: str) -> OrderBook:
        """Fetch L2 orderbook from Hyperliquid info API."""
        try:
            resp = await self._client.post(
                f"{self.api_url}/info",
                json={"type": "l2Book", "coin": token_id},
            )
            resp.raise_for_status()
            data = resp.json()

            levels = data.get("levels", [[], []])
            # levels[0] = bids, levels[1] = asks
            bids = [
                (float(lvl["px"]), float(lvl["sz"]))
                for lvl in levels[0] if "px" in lvl
            ]
            asks = [
                (float(lvl["px"]), float(lvl["sz"]))
                for lvl in levels[1] if "px" in lvl
            ]

            # Already sorted from API, but ensure order
            bids.sort(key=lambda x: x[0], reverse=True)
            asks.sort(key=lambda x: x[0])

            book = OrderBook(
                token_id=token_id,
                bids=bids,
                asks=asks,
                timestamp=time.time(),
            )
            self._orderbooks[token_id] = book
            return book

        except Exception:
            logger.exception(f"Failed to fetch Hyperliquid orderbook for {token_id}")
            return self._orderbooks.get(
                token_id,
                OrderBook(token_id=token_id),
            )

    async def get_midpoint(self, token_id: str) -> float | None:
        """Fetch current mid price from Hyperliquid allMids."""
        try:
            resp = await self._client.post(
                f"{self.api_url}/info",
                json={"type": "allMids"},
            )
            resp.raise_for_status()
            data = resp.json()
            price_str = data.get(token_id)
            if price_str:
                return float(price_str)
            return None
        except Exception:
            logger.exception(f"Failed to fetch mid for {token_id}")
            return None

    async def get_funding_rate(self) -> float | None:
        """Fetch current funding rate for the coin."""
        try:
            resp = await self._client.post(
                f"{self.api_url}/info",
                json={"type": "metaAndAssetCtxs"},
            )
            resp.raise_for_status()
            data = resp.json()
            # data = [meta, [asset_ctxs...]]
            if isinstance(data, list) and len(data) >= 2:
                meta = data[0]
                ctxs = data[1]
                universe = meta.get("universe", [])
                for i, asset in enumerate(universe):
                    if asset.get("name") == self.coin and i < len(ctxs):
                        return float(ctxs[i].get("funding", 0))
            return None
        except Exception:
            return None
