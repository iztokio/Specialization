"""Integration tests for the arbitrage engine components."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from signals.volatility import VolatilityEstimator
from risk.monte_carlo import MonteCarloSimulator
from risk.lmsr import LMSRImpact
from feeds.polymarket_feed import OrderBook
from execution.hedge import HedgeManager


class TestVolatilityEstimator:
    def test_needs_warmup(self):
        v = VolatilityEstimator(span=60, min_samples=10)
        for i in range(5):
            result = v.update(100.0 + i * 0.1)
        assert v.current is None, "Should return None before min_samples"

    def test_produces_estimate_after_warmup(self):
        v = VolatilityEstimator(span=20, min_samples=5)
        for i in range(20):
            v.update(100.0 + i * 0.01)
        assert v.current is not None
        assert v.current > 0

    def test_higher_vol_with_larger_moves(self):
        v1 = VolatilityEstimator(span=20, min_samples=5)
        v2 = VolatilityEstimator(span=20, min_samples=5)

        # Small moves
        for i in range(20):
            v1.update(100.0 + (i % 2) * 0.01)

        # Large moves
        for i in range(20):
            v2.update(100.0 + (i % 2) * 1.0)

        assert v2.current > v1.current


class TestMonteCarloSimulator:
    def test_profitable_strategy_is_viable(self):
        mc = MonteCarloSimulator(n_simulations=1000, n_trades=200)
        result = mc.simulate(
            win_prob=0.65,
            avg_win=100,
            avg_loss=80,
            kelly_f=0.02,
            bankroll=10000,
        )
        assert result.mean_pnl > 0
        assert result.prob_profit > 0.5
        assert result.is_viable

    def test_losing_strategy_not_viable(self):
        mc = MonteCarloSimulator(n_simulations=1000, n_trades=200)
        result = mc.simulate(
            win_prob=0.35,
            avg_win=80,
            avg_loss=100,
            kelly_f=0.10,  # overleveraged
            bankroll=10000,
        )
        assert result.mean_pnl < 0


class TestLMSRImpact:
    def test_small_order_low_impact(self):
        lmsr = LMSRImpact(max_impact_pct=0.05)
        book = OrderBook(
            token_id="test",
            bids=[(0.49, 5000), (0.48, 10000)],
            asks=[(0.51, 5000), (0.52, 10000)],
        )
        impact = lmsr.estimate(order_size=10, side="BUY", book=book)
        assert impact.is_safe

    def test_empty_book_unsafe(self):
        lmsr = LMSRImpact()
        book = OrderBook(token_id="test", bids=[], asks=[])
        impact = lmsr.estimate(order_size=100, side="BUY", book=book)
        assert not impact.is_safe


class TestHedgeManager:
    def test_no_hedge_when_balanced(self):
        h = HedgeManager(max_net_exposure=5000)
        state = h.check()
        assert state.hedge_side == "NONE"
        assert state.hedge_needed == 0

    def test_hedge_triggered_on_skew(self):
        h = HedgeManager(max_net_exposure=5000, hedge_trigger_pct=0.7)
        # Build up YES exposure
        for _ in range(10):
            h.on_fill("BUY_YES", 400)
        state = h.check()
        assert state.hedge_needed > 0
        assert state.hedge_side == "BUY_NO"

    def test_reset(self):
        h = HedgeManager()
        h.on_fill("BUY_YES", 1000)
        assert h.net_exposure == 1000
        h.reset()
        assert h.net_exposure == 0
