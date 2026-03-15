"""
Monte Carlo P&L simulator.

Runs thousands of simulated trade sequences to estimate:
- Expected P&L distribution
- Probability of ruin
- Max drawdown distribution
- Confidence intervals

Used for pre-trade risk assessment and parameter validation.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from monitoring.logger import stream


@dataclass
class SimulationResult:
    """Monte Carlo simulation output."""

    mean_pnl: float
    median_pnl: float
    std_pnl: float
    percentile_5: float     # 5th percentile (worst case)
    percentile_95: float    # 95th percentile (best case)
    prob_profit: float      # P(total P&L > 0)
    prob_ruin: float        # P(bankroll hits 0)
    mean_max_drawdown: float
    sharpe_estimate: float
    is_viable: bool         # True if risk/reward acceptable


class MonteCarloSimulator:
    """
    Simulates N trade sequences to assess strategy viability.

    Each simulation runs `n_trades` trades with the given win_prob and
    payout structure, tracking bankroll evolution, drawdowns, and ruin.
    """

    def __init__(
        self,
        n_simulations: int = 5000,
        n_trades: int = 500,
        ruin_threshold: float = 0.1,  # ruin = bankroll drops to 10% of start
    ):
        self.n_simulations = n_simulations
        self.n_trades = n_trades
        self.ruin_threshold = ruin_threshold

    def simulate(
        self,
        win_prob: float,
        avg_win: float,       # average win per trade (dollars)
        avg_loss: float,      # average loss per trade (dollars, positive number)
        kelly_f: float,       # Kelly fraction being used
        bankroll: float,
    ) -> SimulationResult:
        """
        Run Monte Carlo simulation.

        Args:
            win_prob: probability of winning each trade
            avg_win: average profit on winning trade
            avg_loss: average loss on losing trade (positive number)
            kelly_f: fraction of bankroll risked per trade
            bankroll: starting capital
        """
        rng = np.random.default_rng()

        final_pnls = np.zeros(self.n_simulations)
        max_drawdowns = np.zeros(self.n_simulations)
        ruin_count = 0

        for i in range(self.n_simulations):
            balance = bankroll
            peak = bankroll
            max_dd = 0.0
            ruined = False

            for _ in range(self.n_trades):
                bet = balance * kelly_f
                if rng.random() < win_prob:
                    balance += bet * (avg_win / avg_loss)  # scale by win/loss ratio
                else:
                    balance -= bet

                # Track drawdown
                if balance > peak:
                    peak = balance
                dd = (peak - balance) / peak if peak > 0 else 0
                max_dd = max(max_dd, dd)

                # Ruin check
                if balance <= bankroll * self.ruin_threshold:
                    ruined = True
                    break

            final_pnls[i] = balance - bankroll
            max_drawdowns[i] = max_dd
            if ruined:
                ruin_count += 1

        # Compute statistics
        mean_pnl = float(np.mean(final_pnls))
        std_pnl = float(np.std(final_pnls))
        sharpe = mean_pnl / std_pnl if std_pnl > 0 else 0.0

        result = SimulationResult(
            mean_pnl=round(mean_pnl, 2),
            median_pnl=round(float(np.median(final_pnls)), 2),
            std_pnl=round(std_pnl, 2),
            percentile_5=round(float(np.percentile(final_pnls, 5)), 2),
            percentile_95=round(float(np.percentile(final_pnls, 95)), 2),
            prob_profit=round(float(np.mean(final_pnls > 0)), 4),
            prob_ruin=round(ruin_count / self.n_simulations, 4),
            mean_max_drawdown=round(float(np.mean(max_drawdowns)), 4),
            sharpe_estimate=round(sharpe, 3),
            is_viable=mean_pnl > 0 and ruin_count / self.n_simulations < 0.05,
        )

        stream.log(
            "MC",
            f"mean_pnl=${mean_pnl:.0f} sharpe={sharpe:.2f} ruin={result.prob_ruin:.2%}",
            mean_pnl=result.mean_pnl,
            sharpe=result.sharpe_estimate,
            prob_ruin=result.prob_ruin,
        )

        return result
