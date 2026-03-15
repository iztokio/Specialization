"""EWMA volatility estimator — adapts faster than simple rolling window."""

from __future__ import annotations

import math
import time
from collections import deque


class VolatilityEstimator:
    """
    Exponentially Weighted Moving Average volatility.

    Improvement over simple rolling std: reacts faster to regime changes
    (e.g., sudden volatility spike after news).
    """

    def __init__(self, span: int = 60, min_samples: int = 10):
        """
        Args:
            span: EWMA span in ticks (higher = smoother, slower to adapt)
            min_samples: minimum observations before emitting estimate
        """
        self._alpha = 2.0 / (span + 1)
        self._min_samples = min_samples
        self._ewma_var: float | None = None
        self._last_price: float | None = None
        self._count = 0
        self._returns: deque[float] = deque(maxlen=span * 3)

    def update(self, price: float) -> float | None:
        """
        Feed a new price tick.

        Returns: current volatility estimate (annualized-ish), or None if
                 not enough data yet.
        """
        if self._last_price is not None and self._last_price > 0:
            ret = math.log(price / self._last_price)
            self._returns.append(ret)
            self._count += 1

            if self._ewma_var is None:
                self._ewma_var = ret * ret
            else:
                self._ewma_var = (
                    self._alpha * ret * ret + (1 - self._alpha) * self._ewma_var
                )

        self._last_price = price

        if self._count < self._min_samples:
            return None
        return math.sqrt(self._ewma_var) if self._ewma_var else None

    @property
    def current(self) -> float | None:
        """Current volatility estimate."""
        if self._ewma_var is None or self._count < self._min_samples:
            return None
        return math.sqrt(self._ewma_var)

    @property
    def variance(self) -> float | None:
        """Current variance (sigma^2) for Stoikov model."""
        if self._count < self._min_samples:
            return None
        return self._ewma_var

    def realized_vol(self, window: int | None = None) -> float | None:
        """Simple realized volatility over last N returns (for comparison)."""
        data = list(self._returns)
        if window:
            data = data[-window:]
        if len(data) < 2:
            return None
        mean = sum(data) / len(data)
        var = sum((x - mean) ** 2 for x in data) / (len(data) - 1)
        return math.sqrt(var)
