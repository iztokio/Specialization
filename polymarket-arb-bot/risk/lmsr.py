"""
LMSR (Logarithmic Market Scoring Rule) market impact estimator.

Estimates how much a trade will move the market price, allowing the bot
to adjust position size to avoid adverse price impact.

On Polymarket's CLOB, this is approximated using orderbook depth analysis.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from feeds.polymarket_feed import OrderBook
from monitoring.logger import stream


@dataclass
class ImpactEstimate:
    """Result of market impact estimation."""

    impact_price: float     # estimated price impact (cents)
    impact_pct: float       # as percentage of mid price
    effective_price: float  # actual average fill price
    slippage: float         # effective_price - mid_price
    recommended_size: float # suggested max size for acceptable impact
    is_safe: bool           # True if impact is within tolerance


class LMSRImpact:
    """
    Market impact estimator using orderbook depth.

    For CLOB markets, we walk the book to estimate fill price and slippage.
    The LMSR b-parameter analogy maps to orderbook liquidity.
    """

    def __init__(
        self,
        max_impact_pct: float = 0.02,   # max 2% price impact allowed
        liquidity_param: float = 0.1,    # LMSR b parameter
    ):
        self.max_impact_pct = max_impact_pct
        self.b = liquidity_param

    def estimate(
        self,
        order_size: float,
        side: str,
        book: OrderBook,
    ) -> ImpactEstimate:
        """
        Estimate market impact of placing an order.

        Args:
            order_size: dollar size of the order
            side: "BUY" or "SELL"
            book: current orderbook snapshot
        """
        mid = book.mid_price

        # Walk the book to find effective fill price
        if side == "BUY":
            levels = book.asks  # buying lifts asks
        else:
            levels = book.bids  # selling hits bids

        if not levels:
            return ImpactEstimate(
                impact_price=0.05,
                impact_pct=0.05 / max(mid, 0.01),
                effective_price=mid,
                slippage=0.05,
                recommended_size=0,
                is_safe=False,
            )

        # Walk levels
        filled = 0.0
        cost = 0.0
        for price, size in levels:
            level_value = price * size
            remaining = order_size - filled
            if level_value >= remaining:
                fill_at_level = remaining
            else:
                fill_at_level = level_value
            cost += fill_at_level  # simplified: cost in dollar terms
            filled += fill_at_level
            if filled >= order_size:
                break

        if filled <= 0:
            effective = mid
        else:
            # Shares bought = cost / avg_price, but for binary we approximate
            last_level_price = levels[min(len(levels) - 1, 3)][0] if levels else mid
            effective = last_level_price if filled >= order_size else mid

        slippage = abs(effective - mid)
        impact_pct = slippage / max(mid, 0.01)

        # LMSR-inspired: impact scales logarithmically with size relative to depth
        total_depth = sum(s for _, s in levels)
        if total_depth > 0:
            lmsr_impact = self.b * math.log(1 + order_size / (self.b * total_depth + 1e-8))
        else:
            lmsr_impact = 0.1

        # Recommended max size for acceptable impact
        if impact_pct > 0 and order_size > 0:
            recommended = order_size * (self.max_impact_pct / max(impact_pct, 1e-8))
        else:
            recommended = order_size

        is_safe = impact_pct <= self.max_impact_pct

        stream.log(
            "LMSR",
            f"b={self.b}, impact={lmsr_impact:.3f}",
            impact=round(lmsr_impact, 3),
            slippage=round(slippage, 4),
            depth=round(total_depth, 1),
        )

        return ImpactEstimate(
            impact_price=round(slippage, 5),
            impact_pct=round(impact_pct, 5),
            effective_price=round(effective, 5),
            slippage=round(slippage, 5),
            recommended_size=round(min(recommended, order_size), 2),
            is_safe=is_safe,
        )
