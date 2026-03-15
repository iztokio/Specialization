"""
Order lifecycle management.

Handles order placement, tracking, cancellation, and fill detection
for both live and paper trading modes.
"""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional

from monitoring.logger import get_logger, stream

logger = get_logger("orders")


class OrderStatus(Enum):
    PENDING = "pending"
    OPEN = "open"
    FILLED = "filled"
    PARTIALLY_FILLED = "partially_filled"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
    REJECTED = "rejected"


class OrderSide(Enum):
    BUY = "BUY"
    SELL = "SELL"


@dataclass
class Order:
    """Represents a single order."""

    id: str
    token_id: str
    side: OrderSide
    price: float
    size: float           # in USDC
    status: OrderStatus = OrderStatus.PENDING
    filled_size: float = 0.0
    filled_price: float = 0.0
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)
    ttl: float = 15.0     # seconds before auto-cancel
    polymarket_order_id: str = ""

    @property
    def is_active(self) -> bool:
        return self.status in (OrderStatus.PENDING, OrderStatus.OPEN, OrderStatus.PARTIALLY_FILLED)

    @property
    def is_expired(self) -> bool:
        return time.time() - self.created_at > self.ttl

    @property
    def pnl(self) -> float:
        """Estimated P&L if this order resolves to $1."""
        if self.status != OrderStatus.FILLED:
            return 0.0
        if self.side == OrderSide.BUY:
            return self.filled_size * (1.0 - self.filled_price) / self.filled_price
        else:
            return self.filled_size * self.filled_price / (1.0 - self.filled_price)


class OrderManager:
    """
    Manages the full order lifecycle.

    In paper mode: simulates fills based on orderbook state.
    In live mode: uses py-clob-client to interact with Polymarket CLOB.
    """

    def __init__(self, trading_mode: str = "paper", clob_client=None):
        self.mode = trading_mode
        self.clob_client = clob_client
        self._orders: dict[str, Order] = {}
        self._order_counter = 0
        self._fill_callbacks: list = []

        # Stats
        self.total_orders = 0
        self.total_fills = 0
        self.total_cancels = 0

    def on_fill(self, callback):
        """Register callback(order: Order) called on every fill."""
        self._fill_callbacks.append(callback)

    async def place_order(
        self,
        token_id: str,
        side: str,
        price: float,
        size: float,
        ttl: float = 15.0,
    ) -> Order:
        """
        Place a limit order.

        Args:
            token_id: Polymarket token ID
            side: "BUY" or "SELL"
            price: limit price (0.01–0.99)
            size: order size in USDC
            ttl: time-to-live in seconds
        """
        self._order_counter += 1
        order_id = f"ORD-{self._order_counter:06d}"

        order = Order(
            id=order_id,
            token_id=token_id,
            side=OrderSide(side),
            price=round(price, 4),
            size=round(size, 2),
            ttl=ttl,
        )

        if self.mode == "live" and self.clob_client:
            await self._place_live(order)
        else:
            order.status = OrderStatus.OPEN

        self._orders[order.id] = order
        self.total_orders += 1

        stream.log(
            "ORDER",
            f"{side} {size:.2f} @ {price:.4f}",
            order_id=order_id,
            token_id=token_id[:8],
            side=side,
            price=price,
            size=size,
        )

        return order

    async def cancel_order(self, order_id: str) -> bool:
        """Cancel an open order."""
        order = self._orders.get(order_id)
        if not order or not order.is_active:
            return False

        if self.mode == "live" and self.clob_client and order.polymarket_order_id:
            try:
                self.clob_client.cancel(order.polymarket_order_id)
            except Exception:
                logger.exception(f"Failed to cancel {order_id} on Polymarket")
                return False

        order.status = OrderStatus.CANCELLED
        order.updated_at = time.time()
        self.total_cancels += 1
        return True

    async def cancel_all(self):
        """Cancel all active orders."""
        for order_id, order in list(self._orders.items()):
            if order.is_active:
                await self.cancel_order(order_id)

    async def check_fills(self, current_mid: float = 0.0):
        """
        Check for fills and handle expired orders.

        In paper mode: simulate fills if price crosses our limit.
        In live mode: poll Polymarket for order status updates.
        """
        for order in list(self._orders.values()):
            if not order.is_active:
                continue

            # Auto-cancel expired orders
            if order.is_expired:
                order.status = OrderStatus.EXPIRED
                order.updated_at = time.time()
                self.total_cancels += 1
                continue

            if self.mode == "paper":
                self._simulate_fill(order, current_mid)
            else:
                await self._check_live_fill(order)

    def get_active_orders(self) -> list[Order]:
        return [o for o in self._orders.values() if o.is_active]

    def get_recent_fills(self, n: int = 20) -> list[Order]:
        fills = [o for o in self._orders.values() if o.status == OrderStatus.FILLED]
        fills.sort(key=lambda o: o.updated_at, reverse=True)
        return fills[:n]

    @property
    def active_count(self) -> int:
        return sum(1 for o in self._orders.values() if o.is_active)

    # ── Paper trading simulation ─────────────────────────────

    def _simulate_fill(self, order: Order, current_mid: float):
        """
        Simulate fill in paper mode.

        BUY fills when market ask <= our bid price.
        SELL fills when market bid >= our ask price.
        """
        if current_mid <= 0:
            return

        filled = False
        if order.side == OrderSide.BUY and current_mid <= order.price:
            filled = True
        elif order.side == OrderSide.SELL and current_mid >= order.price:
            filled = True

        if filled:
            order.status = OrderStatus.FILLED
            order.filled_size = order.size
            order.filled_price = order.price
            order.updated_at = time.time()
            self.total_fills += 1

            stream.log(
                "FILL",
                f"{order.side.value} {order.size:.2f} @ {order.price:.4f}",
                order_id=order.id,
                side=order.side.value,
                price=order.price,
                size=order.size,
            )

            for cb in self._fill_callbacks:
                try:
                    cb(order)
                except Exception:
                    logger.exception("Fill callback error")

    # ── Live trading ─────────────────────────────────────────

    async def _place_live(self, order: Order):
        """Place order on Polymarket via py-clob-client."""
        try:
            from py_clob_client.order_builder.constants import BUY, SELL

            side = BUY if order.side == OrderSide.BUY else SELL

            resp = self.clob_client.create_and_post_order(
                order.token_id,
                side,
                order.price,
                order.size,
            )

            if resp and resp.get("orderID"):
                order.polymarket_order_id = resp["orderID"]
                order.status = OrderStatus.OPEN
            else:
                order.status = OrderStatus.REJECTED
                logger.warning(f"Order rejected: {resp}")

        except Exception:
            logger.exception(f"Failed to place order on Polymarket")
            order.status = OrderStatus.REJECTED

    async def _check_live_fill(self, order: Order):
        """Check order status on Polymarket."""
        if not order.polymarket_order_id:
            return
        try:
            resp = self.clob_client.get_order(order.polymarket_order_id)
            status = resp.get("status", "")

            if status == "matched":
                order.status = OrderStatus.FILLED
                order.filled_size = float(resp.get("matchedAmount", order.size))
                order.filled_price = order.price
                order.updated_at = time.time()
                self.total_fills += 1

                for cb in self._fill_callbacks:
                    try:
                        cb(order)
                    except Exception:
                        logger.exception("Fill callback error")

        except Exception:
            logger.exception(f"Failed to check order {order.polymarket_order_id}")
