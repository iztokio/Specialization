"""
Bayesian signal model: P(D|H) = f(spot_delta, vol, book)

Continuously updates the posterior probability of BTC going UP in the next
5-minute window, using multiple market microstructure signals.

Improvement: uses adaptive weights that shift based on volatility regime —
in high-vol regimes, spot_delta matters more; in low-vol, book imbalance
matters more.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field

from monitoring.logger import stream


@dataclass
class BayesianState:
    """Snapshot of current Bayesian model state."""

    prior: float
    posterior: float
    likelihood_up: float
    likelihood_down: float
    spot_signal: float
    vol_signal: float
    book_signal: float
    reprice_signal: float


class BayesianSignal:
    """
    Multi-factor Bayesian model for estimating P(BTC UP | data).

    Factors:
        1. spot_delta   — BTC price change on CEX (momentum signal)
        2. volatility   — short-term vol (opportunity / regime indicator)
        3. book_imbalance — order book pressure on Polymarket
        4. reprice_speed — how fast nearby mids are repricing (information flow)
    """

    def __init__(self, prior: float = 0.5, decay: float = 0.995):
        """
        Args:
            prior: initial P(UP)
            decay: posterior decays toward 0.5 over time to prevent drift
        """
        self.prior = prior
        self.posterior = prior
        self._decay = decay
        self._update_count = 0

    def update(
        self,
        spot_delta: float,
        volatility: float,
        book_imbalance: float,
        reprice_speed: float = 0.0,
    ) -> BayesianState:
        """
        Bayesian update step.

        Args:
            spot_delta: price change over last ~10s on CEX (e.g., +15.0 = $15 up)
            volatility: current EWMA vol estimate
            book_imbalance: Polymarket orderbook imbalance [-1, +1]
            reprice_speed: rate of mid-price change on Polymarket (optional)

        Returns:
            BayesianState with all intermediate values for logging
        """
        # Prevent division by zero
        vol = max(volatility, 1e-8)

        # ── Individual signals ─────────────────────────────────
        # Spot momentum: normalize by volatility (z-score-like)
        spot_z = spot_delta / (vol * 100)  # scale for typical BTC moves
        spot_signal = self._sigmoid(spot_z * 3.0)  # steepen

        # Volatility regime: higher vol = more directional moves = signal stronger
        vol_signal = min(vol / 0.005, 1.0)  # saturates at 0.5% per-tick vol

        # Book imbalance: directly proportional
        book_signal = self._sigmoid(book_imbalance * 4.0)

        # Reprice speed: fast repricing = informed flow
        reprice_signal = self._sigmoid(reprice_speed * 2.0)

        # ── Adaptive weights ───────────────────────────────────
        # In high-vol: trust spot delta more, book imbalance less
        # In low-vol: trust book imbalance more
        vol_regime = min(vol / 0.003, 1.0)
        w_spot = 0.40 + 0.15 * vol_regime      # 0.40–0.55
        w_book = 0.35 - 0.10 * vol_regime       # 0.25–0.35
        w_reprice = 0.15
        w_vol = 1.0 - w_spot - w_book - w_reprice  # remainder

        # ── Combined likelihood ────────────────────────────────
        likelihood_up = (
            w_spot * spot_signal
            + w_vol * vol_signal
            + w_book * book_signal
            + w_reprice * reprice_signal
        )
        likelihood_up = max(0.01, min(0.99, likelihood_up))
        likelihood_down = 1.0 - likelihood_up

        # ── Bayesian update ────────────────────────────────────
        # P(UP|D) = P(D|UP) * P(UP) / P(D)
        numerator = likelihood_up * self.prior
        evidence = likelihood_up * self.prior + likelihood_down * (1 - self.prior)
        self.posterior = numerator / evidence if evidence > 0 else 0.5

        # Clamp to avoid extreme confidence
        self.posterior = max(0.05, min(0.95, self.posterior))

        # Decay prior toward 0.5 to avoid sticky drift
        self.prior = self._decay * self.posterior + (1 - self._decay) * 0.5

        self._update_count += 1

        state = BayesianState(
            prior=self.prior,
            posterior=self.posterior,
            likelihood_up=likelihood_up,
            likelihood_down=likelihood_down,
            spot_signal=spot_signal,
            vol_signal=vol_signal,
            book_signal=book_signal,
            reprice_signal=reprice_signal,
        )

        # Log to training stream
        stream.log(
            "BAYES",
            f"post={self.posterior:.3f}",
            prior=round(self.prior, 3),
            posterior=round(self.posterior, 3),
            spot_sig=round(spot_signal, 3),
            book_sig=round(book_signal, 3),
        )

        return state

    @property
    def fair_price_yes(self) -> float:
        """Fair price for the YES token (= P(UP))."""
        return self.posterior

    @property
    def fair_price_no(self) -> float:
        """Fair price for the NO token (= P(DOWN))."""
        return 1.0 - self.posterior

    @property
    def confidence(self) -> float:
        """How far from 50/50: 0.0 = no confidence, 0.5 = max confidence."""
        return abs(self.posterior - 0.5)

    def reset(self, prior: float = 0.5):
        """Reset for new market cycle."""
        self.prior = prior
        self.posterior = prior

    @staticmethod
    def _sigmoid(x: float) -> float:
        return 1.0 / (1.0 + math.exp(-x))
