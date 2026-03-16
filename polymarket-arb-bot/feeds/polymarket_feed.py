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

    @staticmethod
    def _compute_window_timestamps(interval: int = 300, look_ahead: int = 2) -> list[int]:
        """Compute current and upcoming window-aligned timestamps.

        Args:
            interval: Window size in seconds (300 = 5 min).
            look_ahead: How many future windows to include.
        """
        now = int(time.time())
        current_window = now - (now % interval)
        return [current_window + i * interval for i in range(look_ahead)]

    async def _fetch_market_by_slug(self, slug: str) -> dict | None:
        """Query Gamma API for a specific market by slug."""
        try:
            # Try /events endpoint first (returns event with nested markets)
            resp = await self._client.get(
                f"{self.gamma_url}/events",
                params={"slug": slug},
            )
            if resp.status_code == 200:
                data = resp.json()
                if isinstance(data, list) and data:
                    event = data[0]
                    # Events contain nested markets
                    nested = event.get("markets", [])
                    if nested:
                        return nested[0]
                    return event
                elif isinstance(data, dict) and data:
                    return data
        except Exception:
            pass

        try:
            # Fallback: /markets endpoint with slug parameter
            resp = await self._client.get(
                f"{self.gamma_url}/markets",
                params={"slug": slug},
            )
            if resp.status_code == 200:
                data = resp.json()
                if isinstance(data, list) and data:
                    return data[0]
                elif isinstance(data, dict) and data.get("conditionId"):
                    return data
        except Exception:
            pass

        return None

    async def discover_5min_btc_markets(self) -> list[Market]:
        """Find active 5-minute BTC up/down markets using deterministic slug lookup.

        Polymarket 5-min BTC markets use predictable slugs based on Unix timestamps
        aligned to 300-second windows: btc-updown-5m-{window_ts}
        """
        markets = []

        # Strategy 1: Deterministic slug-based lookup (primary)
        timestamps = self._compute_window_timestamps(interval=300, look_ahead=3)
        slug_patterns = [
            "btc-updown-5m-{ts}",
            "btc-5m-{ts}",
            "bitcoin-5m-{ts}",
            "btc-up-down-5m-{ts}",
        ]

        for ts in timestamps:
            for pattern in slug_patterns:
                slug = pattern.format(ts=ts)
                m = await self._fetch_market_by_slug(slug)
                if m:
                    market = self._parse_market(m)
                    if market:
                        markets.append(market)
                        logger.info(f"Found market via slug: {slug} → {market.question[:60]}")
                    break  # Found a match for this timestamp, skip other patterns

        # Strategy 2: Keyword scan fallback (if slug lookup found nothing)
        if not markets:
            try:
                resp = await self._client.get(
                    f"{self.gamma_url}/markets",
                    params={
                        "tag": "crypto",
                        "active": "true",
                        "closed": "false",
                        "limit": 100,
                    },
                )
                resp.raise_for_status()
                raw_markets = resp.json() if isinstance(resp.json(), list) else []

                # Log what the API returns for diagnostics
                btc_questions = []
                for m in raw_markets:
                    q = m.get("question", "")
                    slug = m.get("slug", "")
                    if any(kw in q.lower() for kw in ("btc", "bitcoin")):
                        btc_questions.append(f"{q[:70]} [slug={slug}]")

                if btc_questions:
                    logger.info(f"Gamma API: {len(raw_markets)} total, {len(btc_questions)} BTC markets:")
                    for q in btc_questions[:10]:
                        logger.info(f"  → {q}")
                else:
                    logger.warning(
                        f"Gamma API: {len(raw_markets)} markets returned, 0 BTC-related. "
                        f"Sample slugs: {[m.get('slug','')[:40] for m in raw_markets[:3]]}"
                    )

                # Try to find ANY tradeable BTC market
                for m in raw_markets:
                    combined = f"{m.get('question', '')} {m.get('slug', '')}".lower()
                    if not any(kw in combined for kw in ("btc", "bitcoin")):
                        continue
                    market = self._parse_market(m)
                    if market:
                        markets.append(market)

            except Exception:
                logger.exception("Fallback market scan failed")

        # Update internal cache
        for market in markets:
            self._markets[market.condition_id] = market

        # Clean up expired markets from cache
        self._markets = {
            k: v for k, v in self._markets.items() if v.seconds_to_expiry > 0
        }

        logger.info(f"Discovered {len(markets)} active BTC markets")
        return markets

    def _parse_market(self, m: dict) -> Market | None:
        """Parse a raw market dict into a Market object."""
        tokens = m.get("clobTokenIds", [])
        # Gamma API may return JSON strings instead of lists — parse them
        if isinstance(tokens, str):
            try:
                tokens = orjson.loads(tokens)
            except Exception:
                logger.warning(f"Failed to parse clobTokenIds: {tokens!r}")
                return None
        if len(tokens) < 2:
            logger.debug(f"Market skipped: <2 tokens. Raw clobTokenIds={m.get('clobTokenIds')!r}")
            return None

        logger.info(f"Parsed token IDs: YES={tokens[0][:16]}... NO={tokens[1][:16]}...")

        prices = m.get("outcomePrices", ["0.5", "0.5"])
        if isinstance(prices, str):
            try:
                prices = orjson.loads(prices)
            except Exception:
                prices = ["0.5", "0.5"]
        try:
            price_tuple = (float(prices[0]), float(prices[1]))
        except (ValueError, IndexError):
            price_tuple = (0.5, 0.5)

        end_time = self._parse_end_time(m)

        return Market(
            condition_id=m.get("conditionId", m.get("id", "")),
            question=m.get("question", ""),
            yes_token_id=tokens[0],
            no_token_id=tokens[1],
            end_time=end_time,
            active=True,
            outcome_prices=price_tuple,
        )

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
