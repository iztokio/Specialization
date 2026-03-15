"""Polymarket CLOB feed: market discovery and orderbook streaming for 5-min BTC."""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from typing import Optional

import httpx
import orjson

from monitoring.logger import get_logger

logger = get_logger("polymarket")


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
    """A 5-minute BTC prediction market on Polymarket."""

    condition_id: str
    question: str
    yes_token_id: str
    no_token_id: str
    end_time: float  # unix timestamp when the market resolves
    active: bool = True
    outcome_prices: tuple[float, float] = (0.5, 0.5)  # (yes_price, no_price)

    @property
    def seconds_to_expiry(self) -> float:
        return max(0, self.end_time - time.time())

    @property
    def time_remaining_normalized(self) -> float:
        """Normalized [0, 1] where 1 = full 5 minutes left."""
        return min(1.0, self.seconds_to_expiry / 300.0)


class PolymarketFeed:
    """Discovers active 5-min BTC markets and fetches orderbooks from CLOB API."""

    def __init__(
        self,
        clob_url: str = "https://clob.polymarket.com",
        gamma_url: str = "https://gamma-api.polymarket.com",
    ):
        self.clob_url = clob_url.rstrip("/")
        self.gamma_url = gamma_url.rstrip("/")
        self._client: httpx.AsyncClient | None = None
        self._markets: dict[str, Market] = {}
        self._orderbooks: dict[str, OrderBook] = {}

    # ── Lifecycle ────────────────────────────────────────────

    async def start(self):
        self._client = httpx.AsyncClient(timeout=10.0)
        logger.info("Polymarket feed started")

    async def stop(self):
        if self._client:
            await self._client.aclose()

    # ── Market Discovery ─────────────────────────────────────

    async def discover_5min_btc_markets(self) -> list[Market]:
        """Find all active 5-minute BTC up/down markets."""
        try:
            raw_markets = []
            # Try multiple search strategies to find BTC short-term markets
            search_params = [
                {"tag": "crypto", "active": "true", "closed": "false", "limit": 100},
                {"active": "true", "closed": "false", "limit": 100},
            ]
            for params in search_params:
                try:
                    resp = await self._client.get(
                        f"{self.gamma_url}/markets", params=params,
                    )
                    resp.raise_for_status()
                    batch = resp.json()
                    if isinstance(batch, list):
                        raw_markets.extend(batch)
                except Exception:
                    continue
                if raw_markets:
                    break

            # Deduplicate by conditionId
            seen_ids = set()
            unique_markets = []
            for m in raw_markets:
                mid = m.get("conditionId", m.get("id", ""))
                if mid not in seen_ids:
                    seen_ids.add(mid)
                    unique_markets.append(m)
            raw_markets = unique_markets

            # Log what API returned for debugging
            if not raw_markets:
                logger.warning("Gamma API returned 0 markets")
            else:
                btc_related = [
                    m.get("question", "")[:80]
                    for m in raw_markets
                    if any(
                        kw in m.get("question", "").lower()
                        for kw in ("btc", "bitcoin")
                    )
                ]
                logger.info(
                    f"Gamma API returned {len(raw_markets)} markets, "
                    f"{len(btc_related)} BTC-related"
                )
                if btc_related:
                    for q in btc_related[:5]:
                        logger.debug(f"  BTC market: {q}")

            markets = []
            for m in raw_markets:
                slug = m.get("slug", "").lower()
                question = m.get("question", "").lower()
                description = m.get("description", "").lower()
                combined = f"{question} {slug} {description}"

                # Check if BTC-related
                is_btc = any(
                    kw in combined for kw in ("btc", "bitcoin")
                )
                if not is_btc:
                    continue

                # Check if short-term (5-min, 1-min, 15-min, hourly, etc.)
                is_short_term = any(
                    kw in combined
                    for kw in (
                        "5 min", "5-min", "5m",
                        "1 min", "1-min", "1m",
                        "15 min", "15-min", "15m",
                        "minute", "hour", "1 hour", "1-hour", "1h",
                        "short", "next",
                    )
                )

                # Check if directional (up/down/above/below/over/under/higher/lower)
                is_directional = any(
                    kw in combined
                    for kw in (
                        "up", "down", "above", "below",
                        "over", "under", "higher", "lower",
                        "rise", "fall", "reach", "hit", "drop",
                        "yes", "no",
                    )
                )

                if not (is_short_term and is_directional):
                    continue

                tokens = m.get("clobTokenIds", [])
                if len(tokens) < 2:
                    continue

                prices = m.get("outcomePrices", ["0.5", "0.5"])
                end_time = self._parse_end_time(m)

                market = Market(
                    condition_id=m.get("conditionId", m.get("id", "")),
                    question=m.get("question", ""),
                    yes_token_id=tokens[0],
                    no_token_id=tokens[1],
                    end_time=end_time,
                    active=True,
                    outcome_prices=(float(prices[0]), float(prices[1])),
                )
                markets.append(market)
                self._markets[market.condition_id] = market

            logger.info(f"Discovered {len(markets)} active short-term BTC markets")
            return markets

        except Exception:
            logger.exception("Failed to discover markets")
            return list(self._markets.values())

    async def get_orderbook(self, token_id: str) -> OrderBook:
        """Fetch current orderbook for a token from CLOB API."""
        try:
            resp = await self._client.get(
                f"{self.clob_url}/book",
                params={"token_id": token_id},
            )
            resp.raise_for_status()
            data = resp.json()

            bids = [
                (float(o["price"]), float(o["size"]))
                for o in data.get("bids", [])
            ]
            asks = [
                (float(o["price"]), float(o["size"]))
                for o in data.get("asks", [])
            ]

            # Sort: bids descending, asks ascending
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
            logger.exception(f"Failed to fetch orderbook for {token_id}")
            return self._orderbooks.get(
                token_id,
                OrderBook(token_id=token_id),
            )

    async def get_midpoint(self, token_id: str) -> float | None:
        """Quick midpoint fetch from CLOB."""
        try:
            resp = await self._client.get(
                f"{self.clob_url}/midpoint",
                params={"token_id": token_id},
            )
            resp.raise_for_status()
            data = resp.json()
            return float(data.get("mid", 0.5))
        except Exception:
            return None

    # ── Helpers ───────────────────────────────────────────────

    def _parse_end_time(self, market_data: dict) -> float:
        """Extract end time as unix timestamp from market data."""
        # Try multiple fields
        for field_name in ("endDate", "end_date_iso", "resolutionTime"):
            val = market_data.get(field_name)
            if val:
                try:
                    from datetime import datetime, timezone

                    dt = datetime.fromisoformat(val.replace("Z", "+00:00"))
                    return dt.timestamp()
                except (ValueError, AttributeError):
                    pass

        # Fallback: extract from slug (e.g., btc-updown-5m-1773451800)
        slug = market_data.get("slug", "")
        parts = slug.split("-")
        for part in reversed(parts):
            if part.isdigit() and len(part) >= 10:
                return float(part)

        # Default: 5 minutes from now
        return time.time() + 300
