"""Tests for Avellaneda-Stoikov quoting model."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from execution.stoikov import StoikovQuoter


class TestStoikovQuoter:
    def test_zero_inventory_symmetric_quotes(self):
        s = StoikovQuoter(gamma=0.18)
        s.inventory = 0
        q = s.quote(mid_price=0.50, sigma2=0.001, time_remaining=0.5)
        # With zero inventory, bid and ask should be roughly symmetric
        mid = (q.bid + q.ask) / 2
        assert abs(mid - 0.50) < 0.05

    def test_positive_inventory_lowers_bid(self):
        s = StoikovQuoter(gamma=0.18)

        s.inventory = 0
        q0 = s.quote(mid_price=0.50, sigma2=0.001, time_remaining=0.5)

        s.inventory = 2.0
        q2 = s.quote(mid_price=0.50, sigma2=0.001, time_remaining=0.5)

        assert q2.reservation_price < q0.reservation_price, \
            "Positive inventory should lower reservation price"

    def test_spread_increases_with_volatility(self):
        s = StoikovQuoter(gamma=0.18)

        q_low = s.quote(mid_price=0.50, sigma2=0.0001, time_remaining=0.5)
        q_high = s.quote(mid_price=0.50, sigma2=0.01, time_remaining=0.5)

        assert q_high.spread >= q_low.spread, \
            "Higher volatility should produce wider spread"

    def test_spread_decreases_near_expiry(self):
        s = StoikovQuoter(gamma=0.18)

        q_far = s.quote(mid_price=0.50, sigma2=0.001, time_remaining=0.9)
        q_near = s.quote(mid_price=0.50, sigma2=0.001, time_remaining=0.1)

        assert q_near.spread <= q_far.spread, \
            "Spread should shrink as expiry approaches"

    def test_prices_bounded(self):
        s = StoikovQuoter(gamma=0.18)
        s.inventory = 5.0  # extreme inventory
        q = s.quote(mid_price=0.50, sigma2=0.1, time_remaining=1.0)
        assert q.bid >= 0.01
        assert q.ask <= 0.99

    def test_on_fill_updates_inventory(self):
        s = StoikovQuoter(gamma=0.18)
        assert s.inventory == 0
        s.on_fill("BUY", 1.5)
        assert s.inventory == 1.5
        s.on_fill("SELL", 0.5)
        assert s.inventory == 1.0

    def test_on_expiry_resets(self):
        s = StoikovQuoter(gamma=0.18)
        s.inventory = 3.0
        s.on_expiry()
        assert s.inventory == 0.0
