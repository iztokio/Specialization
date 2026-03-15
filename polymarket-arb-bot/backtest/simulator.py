"""
Backtester: replays recorded data through the signal pipeline.

Loads JSONL tick/book data and simulates the full trading loop
to evaluate strategy performance on historical data.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

import orjson

from monitoring.logger import get_logger
from signals.bayesian import BayesianSignal
from signals.edge_detector import EdgeDetector
from signals.volatility import VolatilityEstimator
from risk.kelly import KellySizer

logger = get_logger("backtest")


@dataclass
class BacktestResult:
    """Backtesting output."""

    total_trades: int
    wins: int
    losses: int
    total_pnl: float
    max_drawdown: float
    sharpe: float
    win_rate: float
    final_bankroll: float
    avg_trade_pnl: float
    signals_generated: int
    signals_rejected: int


class Backtester:
    """
    Replays recorded data and simulates trading decisions.

    Usage:
        bt = Backtester(bankroll=2050)
        result = bt.run("./data/20260315/")
        print(result)
    """

    def __init__(
        self,
        bankroll: float = 2050.0,
        kelly_fraction: float = 0.5,
        z_threshold: float = 2.0,
        min_net_ev: float = 0.003,
    ):
        self.initial_bankroll = bankroll
        self.bankroll = bankroll
        self.kelly_fraction = kelly_fraction

        self.bayesian = BayesianSignal(prior=0.5)
        self.edge_detector = EdgeDetector(
            base_z_threshold=z_threshold,
            min_net_ev=min_net_ev,
        )
        self.volatility = VolatilityEstimator(span=60)
        self.kelly = KellySizer(fraction=kelly_fraction)

        self.trades: list[dict] = []
        self.pnl_curve: list[float] = []
        self.signals = 0
        self.rejected = 0

    def run(self, data_dir: str) -> BacktestResult:
        """
        Run backtest on recorded data.

        Args:
            data_dir: path to directory containing JSONL files
        """
        data_path = Path(data_dir)

        # Load ticks
        ticks = self._load_jsonl(data_path, "ticks")
        books = self._load_jsonl(data_path, "books")

        logger.info(f"Loaded {len(ticks)} ticks, {len(books)} book snapshots")

        if not ticks:
            logger.error("No tick data found")
            return self._empty_result()

        # Merge and sort by timestamp
        events = []
        for t in ticks:
            events.append(("tick", t))
        for b in books:
            events.append(("book", b))
        events.sort(key=lambda x: x[1].get("t", 0))

        # Replay
        last_book = None
        peak = self.bankroll

        for event_type, data in events:
            if event_type == "tick":
                price = data["p"]
                vol = self.volatility.update(price)

                if vol is None or last_book is None:
                    continue

                # Bayesian update
                spot_delta = data.get("delta", 0)
                book_imbalance = last_book.get("imbalance", 0)

                self.bayesian.update(
                    spot_delta=spot_delta,
                    volatility=vol,
                    book_imbalance=book_imbalance,
                )

                fair_price = self.bayesian.fair_price_yes
                poly_mid = last_book.get("mid", 0.5)

                # Edge check
                edge = self.edge_detector.evaluate(poly_mid, fair_price, vol)

                if not edge.is_signal:
                    self.rejected += 1
                    continue

                self.signals += 1

                # Kelly sizing
                buy_price = poly_mid if edge.direction == "BUY_YES" else (1 - poly_mid)
                odds = KellySizer.binary_odds(buy_price)
                win_prob = fair_price if edge.direction == "BUY_YES" else (1 - fair_price)

                k = self.kelly.size(win_prob, odds, self.bankroll)
                if k.position_size <= 0:
                    continue

                # Simulate trade outcome
                # Simple model: win if edge direction matches actual price movement
                actual_move = data.get("future_delta", spot_delta)
                predicted_up = edge.direction == "BUY_YES"
                actual_up = actual_move >= 0

                won = predicted_up == actual_up
                if won:
                    profit = k.position_size * (1 - buy_price) / buy_price * 0.5
                    self.bankroll += profit
                else:
                    loss = k.position_size * 0.8  # partial loss assumption
                    self.bankroll -= loss

                self.trades.append({
                    "time": data["t"],
                    "direction": edge.direction,
                    "size": k.position_size,
                    "won": won,
                    "bankroll": self.bankroll,
                })
                self.pnl_curve.append(self.bankroll)

                if self.bankroll > peak:
                    peak = self.bankroll

            elif event_type == "book":
                # Precompute derived fields
                bids = data.get("bids", [])
                asks = data.get("asks", [])
                bid_vol = sum(s for _, s in bids) if bids else 0
                ask_vol = sum(s for _, s in asks) if asks else 0
                total = bid_vol + ask_vol

                last_book = {
                    "mid": (bids[0][0] + asks[0][0]) / 2 if bids and asks else 0.5,
                    "imbalance": (bid_vol - ask_vol) / total if total > 0 else 0,
                }

        return self._compute_result(peak)

    def _compute_result(self, peak: float) -> BacktestResult:
        wins = sum(1 for t in self.trades if t["won"])
        losses = len(self.trades) - wins
        total_pnl = self.bankroll - self.initial_bankroll
        max_dd = (peak - min(self.pnl_curve)) / peak if self.pnl_curve and peak > 0 else 0

        avg_pnl = total_pnl / len(self.trades) if self.trades else 0

        # Simplified Sharpe
        if self.pnl_curve and len(self.pnl_curve) > 1:
            import numpy as np
            returns = np.diff(self.pnl_curve) / np.array(self.pnl_curve[:-1])
            sharpe = float(np.mean(returns) / np.std(returns)) if np.std(returns) > 0 else 0
        else:
            sharpe = 0

        return BacktestResult(
            total_trades=len(self.trades),
            wins=wins,
            losses=losses,
            total_pnl=round(total_pnl, 2),
            max_drawdown=round(max_dd, 4),
            sharpe=round(sharpe, 3),
            win_rate=round(wins / len(self.trades), 4) if self.trades else 0,
            final_bankroll=round(self.bankroll, 2),
            avg_trade_pnl=round(avg_pnl, 4),
            signals_generated=self.signals,
            signals_rejected=self.rejected,
        )

    def _empty_result(self) -> BacktestResult:
        return BacktestResult(0, 0, 0, 0, 0, 0, 0, self.bankroll, 0, 0, 0)

    def _load_jsonl(self, base_path: Path, prefix: str) -> list[dict]:
        """Load all JSONL files matching prefix."""
        records = []
        for f in sorted(base_path.glob(f"{prefix}_*.jsonl")):
            with open(f, "rb") as fh:
                for line in fh:
                    line = line.strip()
                    if line:
                        records.append(orjson.loads(line))
        return records
