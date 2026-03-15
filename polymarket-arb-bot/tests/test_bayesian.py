"""Tests for the Bayesian signal model."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from signals.bayesian import BayesianSignal


class TestBayesianSignal:
    def test_initial_state(self):
        b = BayesianSignal(prior=0.5)
        assert b.posterior == 0.5
        assert b.fair_price_yes == 0.5
        assert b.fair_price_no == 0.5

    def test_positive_spot_delta_increases_posterior(self):
        b = BayesianSignal(prior=0.5)
        state = b.update(spot_delta=50.0, volatility=0.003, book_imbalance=0.0)
        assert b.posterior > 0.5, "Positive spot delta should increase P(UP)"

    def test_negative_spot_delta_decreases_posterior(self):
        b = BayesianSignal(prior=0.5)
        state = b.update(spot_delta=-50.0, volatility=0.003, book_imbalance=0.0)
        assert b.posterior < 0.5, "Negative spot delta should decrease P(UP)"

    def test_posterior_bounded(self):
        b = BayesianSignal(prior=0.5)
        # Extreme signal
        for _ in range(100):
            b.update(spot_delta=1000.0, volatility=0.001, book_imbalance=1.0)
        assert b.posterior <= 0.95, "Posterior should be clamped at 0.95"
        assert b.posterior >= 0.05, "Posterior should be clamped at 0.05"

    def test_book_imbalance_affects_posterior(self):
        b1 = BayesianSignal(prior=0.5)
        b2 = BayesianSignal(prior=0.5)

        b1.update(spot_delta=0.0, volatility=0.003, book_imbalance=0.8)
        b2.update(spot_delta=0.0, volatility=0.003, book_imbalance=-0.8)

        assert b1.posterior > b2.posterior, "Positive imbalance should mean higher P(UP)"

    def test_reset(self):
        b = BayesianSignal(prior=0.5)
        b.update(spot_delta=100.0, volatility=0.003, book_imbalance=0.5)
        assert b.posterior != 0.5
        b.reset(0.5)
        assert b.posterior == 0.5

    def test_confidence(self):
        b = BayesianSignal(prior=0.5)
        assert b.confidence == 0.0
        b.update(spot_delta=100.0, volatility=0.003, book_imbalance=0.5)
        assert b.confidence > 0.0

    def test_decay_prevents_drift(self):
        """Posterior should slowly decay toward 0.5 without new signals."""
        b = BayesianSignal(prior=0.5, decay=0.99)
        b.update(spot_delta=100.0, volatility=0.003, book_imbalance=0.5)
        high = b.posterior

        # Feed neutral data
        for _ in range(50):
            b.update(spot_delta=0.0, volatility=0.003, book_imbalance=0.0)

        assert b.posterior < high, "Posterior should decay toward 0.5"
