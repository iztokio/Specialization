"""Tests for Kelly criterion position sizing."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from risk.kelly import KellySizer


class TestKellySizer:
    def test_no_edge_returns_zero(self):
        k = KellySizer(fraction=0.5)
        result = k.size(win_prob=0.45, odds=1.0, bankroll=10000)
        assert result.position_size == 0

    def test_positive_edge_returns_nonzero(self):
        k = KellySizer(fraction=0.5, min_edge=0.01)
        result = k.size(win_prob=0.65, odds=1.0, bankroll=10000)
        assert result.position_size > 0

    def test_fractional_kelly(self):
        k_full = KellySizer(fraction=1.0, max_fraction=1.0, min_edge=0.01)
        k_half = KellySizer(fraction=0.5, max_fraction=1.0, min_edge=0.01)

        r_full = k_full.size(win_prob=0.65, odds=1.0, bankroll=10000)
        r_half = k_half.size(win_prob=0.65, odds=1.0, bankroll=10000)

        assert r_half.position_size < r_full.position_size

    def test_cap_at_max_fraction(self):
        k = KellySizer(fraction=1.0, max_fraction=0.05, min_edge=0.001)
        result = k.size(win_prob=0.90, odds=5.0, bankroll=10000)
        assert result.position_size <= 10000 * 0.05

    def test_cap_at_max_absolute(self):
        k = KellySizer(fraction=1.0, max_fraction=1.0, max_absolute=500, min_edge=0.001)
        result = k.size(win_prob=0.80, odds=2.0, bankroll=100000)
        assert result.position_size <= 500

    def test_binary_odds(self):
        assert KellySizer.binary_odds(0.50) == 1.0
        assert KellySizer.binary_odds(0.25) == 3.0
        assert abs(KellySizer.binary_odds(0.80) - 0.25) < 0.01

    def test_tiny_bankroll_rejected(self):
        k = KellySizer(fraction=0.5)
        result = k.size(win_prob=0.55, odds=1.0, bankroll=5)
        # With 5 bankroll and ~5% fraction, size = 0.25 → too small
        assert result.position_size == 0 or result.reason == "size too small"
