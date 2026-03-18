"""
Z-score edge detection with adaptive threshold.

Detects when the exchange price (Hyperliquid perp) significantly deviates
from the Bayesian fair price (derived from spot feeds), indicating an
exploitable spread for cross-exchange arbitrage.

Improvement over fixed threshold: threshold adapts to volatility regime.
In low-vol environments, even small dislocations are significant.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass

import numpy as np

from monitoring.logger import stream


@dataclass
class EdgeSignal:
    """Result of edge detection."""

    z_score: float
    spread: float          # absolute difference: |poly_price - fair_price|
    ev: float              # expected value of the trade
    cost: float            # estimated cost (spread + fees)
    net_ev: float          # ev - cost
    is_signal: bool        # True if edge is tradeable
    direction: str         # "BUY_YES" or "BUY_NO"
    confidence: float      # p_pass from z-score


class EdgeDetector:
    """
    Detects tradeable edges via Z-score of the spread between Polymarket
    price and Bayesian fair price.

    Z = (S - mu_S) / sigma_S

    Where S = |polymarket_price - fair_price|
    """

    def __init__(
        self,
        window: int = 100,
        base_z_threshold: float = 2.0,
        min_net_ev: float = 0.003,
        fee_rate: float = 0.00035,  # Hyperliquid taker fee 0.035%
        min_confidence: float = 0.60,
    ):
        self._window = window
        self._base_z_threshold = base_z_threshold
        self._min_net_ev = min_net_ev
        self._fee_rate = fee_rate
        self._min_confidence = min_confidence
        self._spreads: deque[float] = deque(maxlen=window)
        self._net_evs: deque[float] = deque(maxlen=window)

    def evaluate(
        self,
        poly_price: float,
        fair_price: float,
        volatility: float | None = None,
    ) -> EdgeSignal:
        """
        Evaluate whether there's a tradeable edge.

        Args:
            poly_price: current Polymarket YES price
            fair_price: Bayesian fair price for YES
            volatility: current vol estimate (for adaptive threshold)
        """
        spread = abs(poly_price - fair_price)
        self._spreads.append(spread)

        # Direction
        if fair_price > poly_price:
            direction = "BUY_YES"  # Polymarket underprices YES
        else:
            direction = "BUY_NO"  # Polymarket overprices YES → buy NO

        # Not enough data yet
        if len(self._spreads) < 10:
            return EdgeSignal(
                z_score=0.0,
                spread=spread,
                ev=spread,
                cost=self._fee_rate,
                net_ev=spread - self._fee_rate,
                is_signal=False,
                direction=direction,
                confidence=0.0,
            )

        # Z-score
        spreads_arr = np.array(self._spreads)
        mu = np.mean(spreads_arr)
        sigma = np.std(spreads_arr)
        z_score = (spread - mu) / sigma if sigma > 1e-8 else 0.0

        # Adaptive threshold based on volatility
        z_threshold = self._adaptive_threshold(volatility)

        # Expected value and cost
        ev = spread
        cost = self._estimate_cost(poly_price)
        net_ev = ev - cost
        self._net_evs.append(net_ev)

        # Confidence (cumulative normal approximation)
        confidence = self._z_to_confidence(z_score)

        is_signal = (
            z_score >= z_threshold
            and net_ev >= self._min_net_ev
            and confidence >= self._min_confidence
        )

        signal = EdgeSignal(
            z_score=round(z_score, 3),
            spread=round(spread, 5),
            ev=round(ev, 5),
            cost=round(cost, 5),
            net_ev=round(net_ev, 5),
            is_signal=is_signal,
            direction=direction,
            confidence=round(confidence, 4),
        )

        # Log
        status = "PASS" if is_signal else "rejected"
        stream.log(
            "EDGE" if is_signal else "FILTER",
            f"z={z_score:.2f} net={net_ev:.4f} {status}",
            z_score=round(z_score, 2),
            ev=round(ev, 4),
            cost=round(cost, 4),
            net=round(net_ev, 4),
        )

        return signal

    @property
    def avg_net_ev(self) -> float:
        """Average net EV over recent trades (for monitoring)."""
        if not self._net_evs:
            return 0.0
        return float(np.mean(self._net_evs))

    def _adaptive_threshold(self, volatility: float | None) -> float:
        """
        Lower threshold in low-vol (smaller dislocations still significant),
        higher in high-vol (noise is louder).
        """
        if volatility is None:
            return self._base_z_threshold

        # vol < 0.0001 → threshold = base * 0.3 (micro-vol, small edges matter)
        # vol = 0.001  → threshold = base * 0.5
        # vol = 0.005  → threshold = base * 1.0 (standard)
        # vol = 0.010  → threshold = base * 1.5
        vol_factor = min(max(volatility / 0.005, 0.3), 1.5)
        return self._base_z_threshold * vol_factor

    def _estimate_cost(self, poly_price: float) -> float:
        """Estimate total cost: spread cost + fees."""
        # Fee rate on Polymarket
        fee_cost = self._fee_rate * poly_price
        # Spread cost (half-spread approximation)
        avg_spread = float(np.mean(self._spreads)) if self._spreads else 0.01
        spread_cost = avg_spread * 0.3  # partial fill assumption
        return fee_cost + spread_cost

    @staticmethod
    def _z_to_confidence(z: float) -> float:
        """Approximate cumulative normal P(Z <= z) using logistic approx."""
        # Fast approximation: Φ(z) ≈ 1 / (1 + exp(-1.7 * z))
        import math
        return 1.0 / (1.0 + math.exp(-1.7 * z))
