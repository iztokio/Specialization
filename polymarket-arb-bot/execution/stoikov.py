"""
Avellaneda-Stoikov optimal quoting model.

    r = s - q * gamma * sigma^2 * (T - t)

Calculates the reservation price (where you're indifferent to trading)
and optimal spread around it. This ensures the bot:
1. Doesn't accumulate too much inventory in one direction
2. Adjusts quotes dynamically as time-to-expiry shrinks
3. Widens spread when volatility increases (more risk)
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from monitoring.logger import stream


@dataclass
class Quote:
    """Optimal bid/ask quote from Stoikov model."""

    reservation_price: float  # where bot is indifferent
    bid: float               # optimal bid price
    ask: float               # optimal ask price
    spread: float            # ask - bid
    inventory_skew: float    # how much inventory shifts the reservation


class StoikovQuoter:
    """
    Avellaneda-Stoikov market maker quoting.

    The model adjusts quotes based on:
    - Current inventory (q): if long, lower bid to reduce exposure
    - Risk aversion (gamma): higher = wider spreads, more conservative
    - Volatility (sigma^2): higher vol = wider spreads
    - Time remaining (T-t): as expiry approaches, reduce spread
    """

    def __init__(
        self,
        gamma: float = 0.18,
        max_inventory: float = 3.0,
        kappa: float = 1.5,  # order arrival rate parameter
    ):
        self.gamma = gamma
        self.max_inventory = max_inventory
        self.kappa = kappa
        self.inventory: float = 0.0  # net position in contracts

    def quote(
        self,
        mid_price: float,
        sigma2: float,
        time_remaining: float,
    ) -> Quote:
        """
        Calculate optimal bid and ask.

        Args:
            mid_price: current market mid price
            sigma2: price variance (from volatility estimator)
            time_remaining: normalized [0, 1] time to expiry
        """
        # Reservation price: shift away from inventory direction
        inventory_skew = self.inventory * self.gamma * sigma2 * time_remaining
        reservation = mid_price - inventory_skew

        # Optimal spread: wider when vol is high, time is long
        spread = self.gamma * sigma2 * time_remaining
        spread += (2.0 / self.gamma) * math.log(1.0 + self.gamma / self.kappa)

        # Ensure minimum spread (don't trade at zero edge)
        spread = max(spread, 0.005)

        # Clamp to valid price range [0.01, 0.99]
        half = spread / 2.0
        bid = max(0.01, reservation - half)
        ask = min(0.99, reservation + half)

        # If inventory is at max, only quote the reducing side
        if self.inventory >= self.max_inventory:
            ask = mid_price  # eager to sell
            bid = max(0.01, reservation - half * 2)  # reluctant to buy more
        elif self.inventory <= -self.max_inventory:
            bid = mid_price  # eager to buy
            ask = min(0.99, reservation + half * 2)

        quote = Quote(
            reservation_price=round(reservation, 5),
            bid=round(bid, 4),
            ask=round(ask, 4),
            spread=round(ask - bid, 4),
            inventory_skew=round(inventory_skew, 5),
        )

        stream.log(
            "STOIKOV",
            f"r={reservation:.4f} q={self.inventory:.1f}",
            reservation=round(reservation, 4),
            bid=round(bid, 4),
            ask=round(ask, 4),
            q=round(self.inventory, 1),
            gamma=self.gamma,
        )

        return quote

    def on_fill(self, side: str, size: float):
        """Update inventory on fill."""
        if side == "BUY":
            self.inventory += size
        else:
            self.inventory -= size
        stream.log("STOIKOV", f"inventory updated q={self.inventory:.1f}")

    def on_expiry(self):
        """Reset inventory when market expires."""
        self.inventory = 0.0

    @property
    def is_inventory_safe(self) -> bool:
        return abs(self.inventory) < self.max_inventory
