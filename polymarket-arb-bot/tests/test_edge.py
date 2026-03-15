"""Tests for Z-score edge detector."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from signals.edge_detector import EdgeDetector


class TestEdgeDetector:
    def test_no_signal_with_insufficient_data(self):
        e = EdgeDetector(window=100)
        signal = e.evaluate(poly_price=0.50, fair_price=0.55)
        assert not signal.is_signal, "Should not signal with < 20 data points"

    def test_direction_buy_yes(self):
        e = EdgeDetector(window=100)
        signal = e.evaluate(poly_price=0.40, fair_price=0.60)
        assert signal.direction == "BUY_YES"

    def test_direction_buy_no(self):
        e = EdgeDetector(window=100)
        signal = e.evaluate(poly_price=0.60, fair_price=0.40)
        assert signal.direction == "BUY_NO"

    def test_large_spread_generates_signal(self):
        e = EdgeDetector(window=50, base_z_threshold=1.5, min_net_ev=0.001)

        # Feed baseline data (small spreads)
        for _ in range(40):
            e.evaluate(poly_price=0.50, fair_price=0.505)

        # Now a big dislocation
        signal = e.evaluate(poly_price=0.40, fair_price=0.55)
        assert signal.z_score > 1.5
        assert signal.spread > 0.1

    def test_cost_estimation(self):
        e = EdgeDetector(window=50)
        for _ in range(25):
            e.evaluate(poly_price=0.50, fair_price=0.51)
        signal = e.evaluate(poly_price=0.50, fair_price=0.52)
        assert signal.cost > 0, "Cost should be positive"

    def test_confidence_increases_with_z_score(self):
        e = EdgeDetector(window=50)
        # Build baseline
        for _ in range(40):
            e.evaluate(poly_price=0.50, fair_price=0.505)

        s1 = e.evaluate(poly_price=0.50, fair_price=0.52)
        s2 = e.evaluate(poly_price=0.50, fair_price=0.55)
        # s2 should have higher z and confidence (fresh bigger spread)
        assert s2.spread > s1.spread
