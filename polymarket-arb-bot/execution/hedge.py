"""
Directional hedge manager.

Monitors net exposure across all active positions and hedges when
inventory becomes too skewed. On Polymarket, hedging means buying
the opposite side (YES vs NO) to reduce directional risk.
"""

from __future__ import annotations

from dataclasses import dataclass

from monitoring.logger import stream


@dataclass
class HedgeState:
    """Current hedge status."""

    net_exposure: float       # positive = long YES, negative = long NO
    hedge_needed: float       # how much to hedge (0 = balanced)
    hedge_side: str           # "BUY_YES" or "BUY_NO" or "NONE"
    is_within_limits: bool


class HedgeManager:
    """
    Tracks directional exposure and signals when hedging is needed.

    The bot primarily takes directional bets (not market-neutral),
    but limits max net exposure to prevent catastrophic loss on
    a single market resolution.
    """

    def __init__(
        self,
        max_net_exposure: float = 5000.0,
        hedge_trigger_pct: float = 0.7,  # hedge when at 70% of max
    ):
        self.max_net_exposure = max_net_exposure
        self.hedge_trigger = max_net_exposure * hedge_trigger_pct
        self._yes_exposure: float = 0.0
        self._no_exposure: float = 0.0

    @property
    def net_exposure(self) -> float:
        """Net directional exposure: positive = net long YES."""
        return self._yes_exposure - self._no_exposure

    @property
    def gross_exposure(self) -> float:
        return self._yes_exposure + self._no_exposure

    def on_fill(self, side: str, size: float):
        """Update exposure on order fill."""
        if side in ("BUY", "BUY_YES"):
            self._yes_exposure += size
        elif side in ("SELL", "BUY_NO"):
            self._no_exposure += size

    def on_expiry(self, won: bool, side: str, size: float):
        """Update exposure when market resolves."""
        if side in ("BUY", "BUY_YES"):
            self._yes_exposure = max(0, self._yes_exposure - size)
        else:
            self._no_exposure = max(0, self._no_exposure - size)

    def check(self) -> HedgeState:
        """Check if hedging is needed."""
        net = self.net_exposure
        abs_net = abs(net)

        if abs_net < self.hedge_trigger:
            return HedgeState(
                net_exposure=round(net, 2),
                hedge_needed=0,
                hedge_side="NONE",
                is_within_limits=True,
            )

        # Need to hedge
        hedge_amount = abs_net - self.hedge_trigger * 0.5  # bring back to 50% of trigger
        if net > 0:
            hedge_side = "BUY_NO"  # too long YES, buy NO to reduce
        else:
            hedge_side = "BUY_YES"  # too long NO, buy YES to reduce

        state = HedgeState(
            net_exposure=round(net, 2),
            hedge_needed=round(hedge_amount, 2),
            hedge_side=hedge_side,
            is_within_limits=abs_net <= self.max_net_exposure,
        )

        stream.log(
            "HEDGE",
            f"net={net:.0f} need={hedge_amount:.0f} {hedge_side}",
            net_exposure=round(net, 0),
            hedge_needed=round(hedge_amount, 0),
        )

        return state

    def reset(self):
        """Reset for new market cycle."""
        self._yes_exposure = 0.0
        self._no_exposure = 0.0
