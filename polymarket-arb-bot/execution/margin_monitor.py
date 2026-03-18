"""
Hyperliquid margin and liquidation monitor.

Continuously tracks:
- Account margin health (maintenance margin ratio)
- Liquidation prices for open positions
- Funding rate impact on P&L
- Pre-trade margin checks

Designed to run as a background task alongside the trading engine.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Optional

from monitoring.logger import get_logger, stream

logger = get_logger("margin")


@dataclass
class PositionRisk:
    """Risk metrics for a single position."""
    coin: str
    size: float
    entry_price: float
    mark_price: float
    liquidation_price: float
    unrealized_pnl: float
    margin_used: float
    leverage_effective: float
    distance_to_liq_pct: float  # how far from liquidation (%)


@dataclass
class MarginState:
    """Overall account margin health."""
    account_value: float = 0.0
    margin_used: float = 0.0
    margin_available: float = 0.0
    withdrawable: float = 0.0
    unrealized_pnl: float = 0.0
    maintenance_margin_ratio: float = 0.0  # used/value
    positions: list[PositionRisk] = field(default_factory=list)
    is_healthy: bool = True
    warning: str = ""
    funding_rate: float = 0.0
    funding_annualized_pct: float = 0.0
    funding_predicted: float = 0.0
    open_interest: float = 0.0
    mark_price: float = 0.0
    oracle_price: float = 0.0
    last_update: float = 0.0


class MarginMonitor:
    """
    Monitors margin health and liquidation risk on Hyperliquid.

    Thresholds:
    - HEALTHY: margin ratio < 50%
    - WARNING: margin ratio 50-75%
    - DANGER: margin ratio > 75%
    - CRITICAL: margin ratio > 90% (close to liquidation)
    """

    HEALTHY_THRESHOLD = 0.50
    WARNING_THRESHOLD = 0.75
    DANGER_THRESHOLD = 0.90

    def __init__(
        self,
        api_url: str = "https://api.hyperliquid.xyz",
        coin: str = "BTC",
        min_margin_available: float = 50.0,  # minimum free margin in USD
    ):
        self.api_url = api_url
        self.coin = coin
        self.min_margin_available = min_margin_available
        self._state = MarginState()
        self._last_warning_time: float = 0.0
        self._warning_cooldown: float = 60.0  # seconds between repeated warnings

    @property
    def state(self) -> MarginState:
        return self._state

    @property
    def is_safe_to_trade(self) -> bool:
        """Check if it's safe to open new positions."""
        if self._state.account_value <= 0:
            return False
        if self._state.margin_available < self.min_margin_available:
            return False
        if self._state.maintenance_margin_ratio > self.DANGER_THRESHOLD:
            return False
        return True

    def can_open_position(self, size_usd: float, leverage: float = 5.0) -> tuple[bool, str]:
        """
        Pre-trade check: can we afford to open this position?

        Args:
            size_usd: position size in USD
            leverage: effective leverage

        Returns:
            (can_trade, reason)
        """
        if self._state.account_value <= 0:
            return False, "No account value on Hyperliquid"

        required_margin = size_usd / leverage
        if required_margin > self._state.margin_available:
            return False, (
                f"Insufficient margin: need ${required_margin:.2f}, "
                f"have ${self._state.margin_available:.2f}"
            )

        # Check if this would push margin ratio past warning threshold
        new_margin_used = self._state.margin_used + required_margin
        new_ratio = new_margin_used / self._state.account_value if self._state.account_value > 0 else 1.0
        if new_ratio > self.WARNING_THRESHOLD:
            return False, (
                f"Would exceed margin warning: ratio would be {new_ratio:.1%} "
                f"(threshold {self.WARNING_THRESHOLD:.0%})"
            )

        return True, "OK"

    def update(self, hl_balance: dict, funding_data: dict) -> MarginState:
        """
        Update margin state from fresh balance and funding data.

        Args:
            hl_balance: result from fetch_hyperliquid_balance()
            funding_data: result from fetch_funding_rate()
        """
        s = self._state
        s.last_update = time.time()

        if hl_balance.get("error"):
            s.is_healthy = False
            s.warning = f"Balance fetch error: {hl_balance['error']}"
            return s

        s.account_value = hl_balance["account_value"]
        s.margin_used = hl_balance["margin_used"]
        s.margin_available = hl_balance["margin_available"]
        s.withdrawable = hl_balance["withdrawable"]
        s.unrealized_pnl = hl_balance["unrealized_pnl"]

        # Margin ratio
        if s.account_value > 0:
            s.maintenance_margin_ratio = s.margin_used / s.account_value
        else:
            s.maintenance_margin_ratio = 0.0

        # Parse positions into risk metrics
        s.positions = []
        for pos in hl_balance.get("positions", []):
            mark = pos.get("entry_price", 0)  # approximate
            liq = pos.get("liquidation_px", 0)
            entry = pos.get("entry_price", 0)

            # Distance to liquidation
            if liq > 0 and entry > 0:
                if pos["size"] > 0:  # long
                    dist = (entry - liq) / entry * 100
                else:  # short
                    dist = (liq - entry) / entry * 100
            else:
                dist = 100.0  # no liquidation risk

            eff_leverage = 0.0
            lev = pos.get("leverage", {})
            if isinstance(lev, dict):
                eff_leverage = float(lev.get("value", 0))
            elif isinstance(lev, (int, float)):
                eff_leverage = float(lev)

            s.positions.append(PositionRisk(
                coin=pos["coin"],
                size=pos["size"],
                entry_price=entry,
                mark_price=mark,
                liquidation_price=liq,
                unrealized_pnl=pos.get("unrealized_pnl", 0),
                margin_used=pos.get("margin_used", 0),
                leverage_effective=eff_leverage,
                distance_to_liq_pct=dist,
            ))

        # Funding rate
        if not funding_data.get("error"):
            s.funding_rate = funding_data["current_rate"]
            s.funding_annualized_pct = funding_data["annualized_pct"]
            s.funding_predicted = funding_data["predicted_rate"]
            s.open_interest = funding_data["open_interest"]
            s.mark_price = funding_data["mark_price"]
            s.oracle_price = funding_data["oracle_price"]

        # Health assessment
        s.is_healthy = True
        s.warning = ""

        if s.maintenance_margin_ratio > self.DANGER_THRESHOLD:
            s.is_healthy = False
            s.warning = f"DANGER: margin ratio {s.maintenance_margin_ratio:.1%} — close to liquidation!"
            self._emit_warning(s.warning)
        elif s.maintenance_margin_ratio > self.WARNING_THRESHOLD:
            s.warning = f"WARNING: margin ratio {s.maintenance_margin_ratio:.1%} — reduce positions"
            self._emit_warning(s.warning)

        # Check individual position liquidation distances
        for pos in s.positions:
            if pos.distance_to_liq_pct < 5.0:
                s.is_healthy = False
                msg = (
                    f"LIQUIDATION RISK: {pos.coin} position "
                    f"only {pos.distance_to_liq_pct:.1f}% from liquidation "
                    f"(liq=${pos.liquidation_price:,.0f})"
                )
                s.warning = msg
                self._emit_warning(msg)

        # Check if margin available is too low
        if s.account_value > 0 and s.margin_available < self.min_margin_available:
            s.warning = f"Low margin: only ${s.margin_available:.2f} free"
            self._emit_warning(s.warning)

        return s

    def _emit_warning(self, message: str):
        """Emit warning to stream with cooldown to avoid spam."""
        now = time.time()
        if now - self._last_warning_time > self._warning_cooldown:
            stream.log("MARGIN", message)
            self._last_warning_time = now

    def get_funding_cost_estimate(self, position_size_usd: float, hours: int = 24) -> float:
        """
        Estimate funding cost for holding a position.

        Returns cost in USD (negative = you pay, positive = you receive).
        """
        if self._state.funding_rate == 0:
            return 0.0
        # Funding is paid hourly on Hyperliquid
        return position_size_usd * self._state.funding_rate * hours

    def to_dict(self) -> dict:
        """Serialize state for API/dashboard."""
        s = self._state
        return {
            "account_value": round(s.account_value, 2),
            "margin_used": round(s.margin_used, 2),
            "margin_available": round(s.margin_available, 2),
            "withdrawable": round(s.withdrawable, 2),
            "unrealized_pnl": round(s.unrealized_pnl, 2),
            "margin_ratio": round(s.maintenance_margin_ratio * 100, 1),
            "is_healthy": s.is_healthy,
            "warning": s.warning,
            "safe_to_trade": self.is_safe_to_trade,
            "funding_rate": round(s.funding_rate * 10000, 4),  # in bps
            "funding_annualized_pct": round(s.funding_annualized_pct, 2),
            "funding_predicted_bps": round(s.funding_predicted * 10000, 4),
            "open_interest": round(s.open_interest, 0),
            "mark_price": round(s.mark_price, 2),
            "oracle_price": round(s.oracle_price, 2),
            "positions": [
                {
                    "coin": p.coin,
                    "size": round(p.size, 5),
                    "entry_price": round(p.entry_price, 2),
                    "liquidation_price": round(p.liquidation_price, 2),
                    "unrealized_pnl": round(p.unrealized_pnl, 2),
                    "margin_used": round(p.margin_used, 2),
                    "leverage": round(p.leverage_effective, 1),
                    "distance_to_liq_pct": round(p.distance_to_liq_pct, 1),
                }
                for p in s.positions
            ],
            "last_update": s.last_update,
        }
