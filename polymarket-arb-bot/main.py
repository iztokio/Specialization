#!/usr/bin/env python3
"""
Polymarket BTC 5-Minute Arbitrage Bot
======================================

Entry point. Starts the arbitrage engine and live dashboard.

Usage:
    # Paper trading (default):
    python main.py

    # Live trading:
    TRADING_MODE=live python main.py

    # With custom bankroll:
    INITIAL_BANKROLL=5000 python main.py

    # Run Monte Carlo validation first:
    python main.py --validate

    # Record data only (no trading):
    python main.py --record-only
"""

from __future__ import annotations

import argparse
import asyncio
import signal
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from config.settings import get_settings
from engine.arbitrage import ArbitrageEngine
from monitoring.dashboard import Dashboard
from monitoring.logger import get_logger
from risk.monte_carlo import MonteCarloSimulator

logger = get_logger("main")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Polymarket BTC 5-Min Arbitrage Bot"
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Run Monte Carlo validation before starting",
    )
    parser.add_argument(
        "--no-dashboard",
        action="store_true",
        help="Disable live terminal dashboard",
    )
    parser.add_argument(
        "--record-only",
        action="store_true",
        help="Only record market data, don't trade",
    )
    return parser.parse_args()


async def run_validation(settings):
    """Run Monte Carlo simulation to validate strategy before trading."""
    logger.info("Running pre-flight Monte Carlo validation...")

    mc = MonteCarloSimulator(n_simulations=10_000, n_trades=1000)
    result = mc.simulate(
        win_prob=0.60,       # conservative assumption
        avg_win=50.0,        # $50 avg win
        avg_loss=45.0,       # $45 avg loss
        kelly_f=settings.kelly_fraction * 0.03,  # half kelly of ~3%
        bankroll=settings.initial_bankroll,
    )

    logger.info(f"Monte Carlo Results ({mc.n_simulations} simulations, {mc.n_trades} trades):")
    logger.info(f"  Mean P&L:      ${result.mean_pnl:,.2f}")
    logger.info(f"  Median P&L:    ${result.median_pnl:,.2f}")
    logger.info(f"  5th percentile: ${result.percentile_5:,.2f}")
    logger.info(f"  95th percentile: ${result.percentile_95:,.2f}")
    logger.info(f"  P(profit):     {result.prob_profit:.1%}")
    logger.info(f"  P(ruin):       {result.prob_ruin:.1%}")
    logger.info(f"  Sharpe:        {result.sharpe_estimate:.2f}")
    logger.info(f"  Max Drawdown:  {result.mean_max_drawdown:.1%}")
    logger.info(f"  Viable:        {'YES' if result.is_viable else 'NO'}")

    if not result.is_viable:
        logger.warning("Strategy did NOT pass Monte Carlo validation!")
        logger.warning("Consider adjusting parameters before live trading.")
        return False

    logger.info("Strategy PASSED Monte Carlo validation.")
    return True


async def main():
    args = parse_args()
    settings = get_settings()

    # Banner
    print("\n" + "=" * 60)
    print("  ARB ENGINE // 5-MIN BTC MARKETS")
    print(f"  Mode: {settings.trading_mode.upper()}")
    print(f"  Bankroll: ${settings.initial_bankroll:,.2f}")
    print("=" * 60 + "\n")

    # Safety check for live mode
    if settings.trading_mode == "live":
        if not settings.private_key:
            logger.error("PRIVATE_KEY not set. Cannot run in live mode.")
            sys.exit(1)
        logger.warning("*** LIVE TRADING MODE ***")
        logger.warning("Real money will be used. Press Ctrl+C within 5 seconds to abort.")
        await asyncio.sleep(5)

    # Pre-flight validation
    if args.validate:
        passed = await run_validation(settings)
        if not passed and settings.trading_mode == "live":
            logger.error("Aborting: Monte Carlo validation failed in live mode.")
            sys.exit(1)

    # Initialize engine
    engine = ArbitrageEngine(settings)

    # Setup live CLOB client for live mode
    if settings.trading_mode == "live":
        try:
            from py_clob_client.client import ClobClient

            clob_client = ClobClient(
                settings.clob_url,
                key=settings.private_key,
                chain_id=settings.chain_id,
                signature_type=0,
                funder=settings.polymarket_funder or None,
            )

            # Set API credentials
            clob_client.set_api_creds(
                clob_client.create_or_derive_api_creds()
            )

            engine.order_manager.clob_client = clob_client
            engine.order_manager.mode = "live"
            logger.info("Polymarket CLOB client initialized")
        except Exception:
            logger.exception("Failed to initialize CLOB client")
            sys.exit(1)

    # Graceful shutdown
    shutdown_event = asyncio.Event()

    def on_signal(sig):
        logger.info(f"Received {sig.name}, shutting down...")
        shutdown_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, on_signal, sig)

    # Start tasks
    tasks = []
    tasks.append(asyncio.create_task(engine.start()))

    if not args.no_dashboard:
        dashboard = Dashboard(engine)
        tasks.append(asyncio.create_task(dashboard.start()))

    # Wait for shutdown
    await shutdown_event.wait()

    # Cleanup
    logger.info("Shutting down engine...")
    await engine.stop()
    if not args.no_dashboard:
        dashboard.stop()

    for task in tasks:
        task.cancel()

    logger.info(f"Final bankroll: ${engine.stats.bankroll:,.2f}")
    logger.info(f"Total trades: {engine.stats.total_trades}")
    logger.info(f"Total P&L: ${engine.stats.total_pnl:,.2f}")
    logger.info("Goodbye!")


if __name__ == "__main__":
    asyncio.run(main())
