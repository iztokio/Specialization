"""
Kelly Criterion position sizing with safety caps.

f* = (p * b - q) / b

Improvement: uses fractional Kelly (default 50%) plus absolute and
relative caps to prevent ruin from model miscalibration.
"""

from __future__ import annotations

from dataclasses import dataclass

from monitoring.logger import stream


@dataclass
class KellyResult:
    """Output of Kelly calculation."""

    full_kelly_f: float       # raw Kelly fraction
    adjusted_f: float         # after fractional + caps
    position_size: float      # dollar amount to risk
    bankroll: float
    win_prob: float
    reason: str = ""          # why it was capped/rejected


class KellySizer:
    """
    Fractional Kelly Criterion with multiple safety layers.

    Safety layers:
        1. Fractional Kelly (default 50% of optimal f*)
        2. Per-trade cap (default 5% of bankroll)
        3. Absolute dollar cap
        4. Minimum edge threshold
    """

    def __init__(
        self,
        fraction: float = 0.5,
        max_fraction: float = 0.05,
        max_absolute: float = 5000.0,
        min_edge: float = 0.01,
    ):
        self.fraction = fraction
        self.max_fraction = max_fraction
        self.max_absolute = max_absolute
        self.min_edge = min_edge

    def size(
        self,
        win_prob: float,
        odds: float,
        bankroll: float,
    ) -> KellyResult:
        """
        Calculate optimal position size.

        Args:
            win_prob: estimated probability of winning (from Bayesian model)
            odds: payout ratio (for binary markets at price p, odds ≈ (1-p)/p)
            bankroll: current total capital
        """
        q = 1.0 - win_prob

        # Kelly formula
        if odds <= 0:
            return KellyResult(0, 0, 0, bankroll, win_prob, "zero odds")

        full_f = (win_prob * odds - q) / odds

        # Negative Kelly = negative edge → don't trade
        if full_f <= 0:
            stream.log("KELLY", f"f={full_f:.3f}, NO EDGE", f=round(full_f, 3))
            return KellyResult(full_f, 0, 0, bankroll, win_prob, "negative edge")

        # Edge too small → skip (avoid noise trades)
        edge = win_prob * odds - q
        if edge < self.min_edge:
            stream.log("KELLY", f"f={full_f:.3f}, edge too small", f=round(full_f, 3))
            return KellyResult(full_f, 0, 0, bankroll, win_prob, "edge below minimum")

        # Apply fractional Kelly
        adjusted_f = full_f * self.fraction

        # Cap at max fraction of bankroll
        reason = "safe"
        if adjusted_f > self.max_fraction:
            adjusted_f = self.max_fraction
            reason = "capped at max fraction"

        # Dollar amount
        position = adjusted_f * bankroll

        # Absolute dollar cap
        if position > self.max_absolute:
            position = self.max_absolute
            adjusted_f = position / bankroll
            reason = "capped at max absolute"

        # Minimum viable order ($1)
        if position < 1.0:
            stream.log("KELLY", f"f={full_f:.3f}, size too small", f=round(full_f, 3))
            return KellyResult(full_f, 0, 0, bankroll, win_prob, "size too small")

        stream.log(
            "KELLY",
            f"f={adjusted_f:.3f}, {reason}",
            f=round(adjusted_f, 3),
            full_f=round(full_f, 3),
            size=round(position, 2),
        )

        return KellyResult(
            full_kelly_f=round(full_f, 4),
            adjusted_f=round(adjusted_f, 4),
            position_size=round(position, 2),
            bankroll=bankroll,
            win_prob=win_prob,
            reason=reason,
        )

    @staticmethod
    def binary_odds(price: float) -> float:
        """
        Convert binary market price to Kelly odds.

        If you buy YES at price p, and it resolves to $1:
            profit = 1 - p
            loss = p
            odds = profit / loss = (1 - p) / p
        """
        price = max(0.01, min(0.99, price))
        return (1.0 - price) / price
