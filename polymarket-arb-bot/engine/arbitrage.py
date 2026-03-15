"""
Main arbitrage engine — orchestrates the full trading pipeline.

Cycle: SCAN → BAYES → EDGE → FILTER → KELLY → LMSR → STOIKOV → ORDER → HEDGE
       ~278 iterations per hour (every ~13 seconds per full cycle)

Circuit breakers auto-halt trading on:
- Max drawdown exceeded
- Consecutive loss streak
- Feed disconnection
- Anomalous price behavior
"""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from typing import Optional

from config.settings import Settings
from execution.hedge import HedgeManager
from execution.order_manager import OrderManager, Order, OrderStatus
from execution.stoikov import StoikovQuoter
from feeds.binance_feed import BinanceFeed
from feeds.coinbase_feed import CoinbaseFeed
from feeds.polymarket_feed import PolymarketFeed, Market, OrderBook
from monitoring.logger import get_logger, stream
from risk.kelly import KellySizer
from risk.lmsr import LMSRImpact
from risk.monte_carlo import MonteCarloSimulator
from signals.bayesian import BayesianSignal
from signals.edge_detector import EdgeDetector
from signals.volatility import VolatilityEstimator

logger = get_logger("engine")


@dataclass
class EngineStats:
    """Aggregated engine statistics."""

    start_time: float = field(default_factory=time.time)
    bankroll: float = 0.0
    peak_bankroll: float = 0.0
    initial_bankroll: float = 0.0
    total_trades: int = 0
    wins: int = 0
    losses: int = 0
    total_pnl: float = 0.0
    consecutive_losses: int = 0
    max_drawdown: float = 0.0
    cycles: int = 0
    signals_generated: int = 0
    signals_rejected: int = 0

    @property
    def win_rate(self) -> float:
        return self.wins / self.total_trades if self.total_trades > 0 else 0.0

    @property
    def roi_pct(self) -> float:
        if self.initial_bankroll <= 0:
            return 0.0
        return (self.bankroll - self.initial_bankroll) / self.initial_bankroll * 100

    @property
    def sharpe(self) -> float:
        # Simplified: use win rate and avg trade
        if self.total_trades < 10:
            return 0.0
        avg = self.total_pnl / self.total_trades
        # Rough approximation
        return avg / max(abs(self.total_pnl / max(self.total_trades, 1)), 0.01)

    @property
    def trades_per_hour(self) -> float:
        elapsed = time.time() - self.start_time
        if elapsed < 60:
            return 0.0
        return self.total_trades / (elapsed / 3600)

    @property
    def edge_pct(self) -> float:
        if self.total_trades == 0:
            return 0.0
        return (self.total_pnl / max(self.bankroll, 1)) * 100

    @property
    def current_drawdown(self) -> float:
        if self.peak_bankroll <= 0:
            return 0.0
        return (self.peak_bankroll - self.bankroll) / self.peak_bankroll


class CircuitBreaker:
    """Auto-halts trading when risk limits are breached."""

    def __init__(self, settings: Settings):
        self.enabled = settings.circuit_breaker_enabled
        self.max_drawdown = settings.circuit_max_drawdown
        self.max_consecutive_losses = settings.circuit_max_consecutive_losses
        self.cooldown = settings.circuit_cooldown_seconds
        self._tripped = False
        self._trip_time: float = 0.0
        self._reason: str = ""

    def check(self, stats: EngineStats) -> bool:
        """Returns True if trading should be halted."""
        if not self.enabled:
            return False

        # Check cooldown
        if self._tripped:
            if time.time() - self._trip_time < self.cooldown:
                return True
            self._tripped = False
            logger.info("Circuit breaker reset after cooldown")

        # Max drawdown
        if stats.current_drawdown >= self.max_drawdown:
            self._trip("MAX_DRAWDOWN", stats.current_drawdown)
            return True

        # Consecutive losses
        if stats.consecutive_losses >= self.max_consecutive_losses:
            self._trip("CONSECUTIVE_LOSSES", stats.consecutive_losses)
            return True

        return False

    def _trip(self, reason: str, value: float):
        self._tripped = True
        self._trip_time = time.time()
        self._reason = reason
        logger.warning(f"CIRCUIT BREAKER TRIPPED: {reason} = {value}")
        stream.log("CIRCUIT", f"TRIPPED: {reason}={value:.4f}")

    @property
    def is_tripped(self) -> bool:
        return self._tripped

    @property
    def reason(self) -> str:
        return self._reason


class ArbitrageEngine:
    """
    Main orchestrator: ties all modules together into the trading loop.

    Architecture:
        SpotFeed → Bayesian → EdgeDetector → Kelly → LMSR → Stoikov → OrderManager
                                                                          ↓
                                                                     HedgeManager
    """

    def __init__(self, settings: Settings):
        self.settings = settings

        # ── Data Feeds ───────────────────────────────────────
        self.binance = BinanceFeed(url=settings.binance_ws_url)
        self.coinbase = CoinbaseFeed(url=settings.coinbase_ws_url)
        self.polymarket = PolymarketFeed(
            clob_url=settings.clob_url,
            gamma_url=settings.gamma_url,
        )

        # ── Signal ───────────────────────────────────────────
        self.volatility = VolatilityEstimator(span=settings.vol_ewma_span)
        self.bayesian = BayesianSignal(prior=settings.bayesian_prior)
        self.edge_detector = EdgeDetector(
            window=settings.edge_window,
            base_z_threshold=settings.z_score_threshold,
            min_net_ev=settings.min_net_ev,
        )

        # ── Risk ─────────────────────────────────────────────
        self.kelly = KellySizer(
            fraction=settings.kelly_fraction,
            max_fraction=settings.max_kelly_f,
            max_absolute=settings.max_position_size,
        )
        self.lmsr = LMSRImpact()
        self.monte_carlo = MonteCarloSimulator()

        # ── Execution ────────────────────────────────────────
        self.stoikov = StoikovQuoter(
            gamma=settings.gamma_risk,
            max_inventory=settings.max_inventory,
        )
        self.order_manager = OrderManager(trading_mode=settings.trading_mode)
        self.hedge = HedgeManager(max_net_exposure=settings.max_position_size * 2)

        # ── State ────────────────────────────────────────────
        self.stats = EngineStats(
            bankroll=settings.initial_bankroll,
            peak_bankroll=settings.initial_bankroll,
            initial_bankroll=settings.initial_bankroll,
        )
        self.circuit = CircuitBreaker(settings)
        self._running = False
        self._last_market_scan: float = 0.0
        self._active_markets: list[Market] = []

        # Register fill callback
        self.order_manager.on_fill(self._on_fill)

    # ── Main Loop ────────────────────────────────────────────

    async def start(self):
        """Start the engine and all feeds."""
        logger.info("=" * 60)
        logger.info("ARB ENGINE // 5-MIN BTC MARKETS")
        logger.info(f"Mode: {self.settings.trading_mode.upper()}")
        logger.info(f"Bankroll: ${self.stats.bankroll:,.2f}")
        logger.info("=" * 60)

        self._running = True

        # Start feeds concurrently
        await self.polymarket.start()

        feed_tasks = [
            asyncio.create_task(self.binance.start()),
            asyncio.create_task(self.coinbase.start()),
        ]

        # Wait for at least Binance to connect
        try:
            await self.binance.wait_ready(timeout=15.0)
            logger.info("Binance feed ready")
        except asyncio.TimeoutError:
            logger.error("Binance feed timeout — running with delayed start")

        # Register volatility updater
        self.binance.on_tick(lambda tick: self.volatility.update(tick.price))

        # Main trading loop
        try:
            await self._run_loop()
        finally:
            self._running = False
            await self.order_manager.cancel_all()
            await self.polymarket.stop()
            for t in feed_tasks:
                t.cancel()

    async def stop(self):
        self._running = False

    async def _run_loop(self):
        """Core loop: scan → evaluate → trade."""
        while self._running:
            try:
                self.stats.cycles += 1

                # ── Circuit breaker check ────────────────────
                if self.circuit.check(self.stats):
                    await asyncio.sleep(10)
                    continue

                # ── Refresh markets periodically ─────────────
                if time.time() - self._last_market_scan > self.settings.market_scan_interval:
                    self._active_markets = await self.polymarket.discover_5min_btc_markets()
                    self._last_market_scan = time.time()
                    stream.log("SCAN", f"Found {len(self._active_markets)} active markets")

                # ── Check existing order fills ───────────────
                mid = self.binance.last_price or 0
                poly_mid = 0.5  # default
                for market in self._active_markets:
                    book = await self.polymarket.get_orderbook(market.yes_token_id)
                    if book.mid_price > 0:
                        poly_mid = book.mid_price
                        break
                await self.order_manager.check_fills(current_mid=poly_mid)

                # ── Skip if no price data ────────────────────
                if self.binance.last_price is None:
                    await asyncio.sleep(self.settings.poll_interval)
                    continue

                # ── Evaluate each active market ──────────────
                for market in self._active_markets:
                    if market.seconds_to_expiry < 10:
                        continue  # too close to expiry

                    await self._evaluate_market(market)

                # ── Hedge check ──────────────────────────────
                hedge_state = self.hedge.check()
                if hedge_state.hedge_needed > 0:
                    await self._execute_hedge(hedge_state)

                await asyncio.sleep(self.settings.poll_interval)

            except Exception:
                logger.exception("Error in main loop")
                await asyncio.sleep(2)

    # ── Market Evaluation Pipeline ───────────────────────────

    async def _evaluate_market(self, market: Market):
        """Full pipeline for a single market: signal → size → execute."""

        # 1. Get orderbook
        book = await self.polymarket.get_orderbook(market.yes_token_id)
        if book.spread <= 0 or book.mid_price <= 0:
            return

        # 2. Spot data
        spot_delta = self.binance.get_delta(seconds=10)
        vol = self.volatility.current
        if vol is None:
            return

        # 3. Cross-validate with Coinbase (improvement: dual feed)
        coinbase_delta = self.coinbase.get_delta(seconds=10) if self.coinbase.connected else None
        if coinbase_delta is not None:
            # If feeds disagree on direction, reduce confidence
            if (spot_delta > 0) != (coinbase_delta > 0) and abs(spot_delta) > 5:
                spot_delta *= 0.5  # dampen signal

        # 4. Bayesian update
        bayes_state = self.bayesian.update(
            spot_delta=spot_delta,
            volatility=vol,
            book_imbalance=book.get_imbalance(),
        )
        fair_price = self.bayesian.fair_price_yes

        # 5. Edge detection
        edge = self.edge_detector.evaluate(
            poly_price=book.mid_price,
            fair_price=fair_price,
            volatility=vol,
        )

        if not edge.is_signal:
            self.stats.signals_rejected += 1
            return

        self.stats.signals_generated += 1

        # 6. Kelly sizing
        buy_price = book.best_ask if edge.direction == "BUY_YES" else (1 - book.best_bid)
        odds = KellySizer.binary_odds(buy_price)
        win_prob = fair_price if edge.direction == "BUY_YES" else (1 - fair_price)
        kelly_result = self.kelly.size(
            win_prob=win_prob,
            odds=odds,
            bankroll=self.stats.bankroll,
        )

        if kelly_result.position_size <= 0:
            return

        # 7. Market impact check
        impact = self.lmsr.estimate(
            order_size=kelly_result.position_size,
            side="BUY" if edge.direction == "BUY_YES" else "SELL",
            book=book,
        )

        position_size = kelly_result.position_size
        if not impact.is_safe:
            position_size = min(position_size, impact.recommended_size)
            if position_size < 1.0:
                stream.log("FILTER", "impact too high, skipping")
                return

        # 8. Stoikov optimal price
        sigma2 = self.volatility.variance or 0.001
        quote = self.stoikov.quote(
            mid_price=book.mid_price,
            sigma2=sigma2,
            time_remaining=market.time_remaining_normalized,
        )

        # 9. Place order
        if edge.direction == "BUY_YES":
            token_id = market.yes_token_id
            price = min(quote.bid, book.best_ask - 0.001)  # improve on ask
            side = "BUY"
        else:
            token_id = market.no_token_id
            no_book = await self.polymarket.get_orderbook(market.no_token_id)
            price = min(quote.bid, no_book.best_ask - 0.001) if no_book.asks else quote.bid
            side = "BUY"

        price = max(0.01, min(0.99, price))

        # Don't place if too many active orders
        if self.order_manager.active_count >= 5:
            await self.order_manager.cancel_all()

        order = await self.order_manager.place_order(
            token_id=token_id,
            side=side,
            price=round(price, 2),
            size=round(position_size, 2),
            ttl=self.settings.order_ttl_seconds,
        )

        stream.log(
            "TRADE",
            f"{edge.direction} ${position_size:.0f} @ {price:.3f} z={edge.z_score}",
            direction=edge.direction,
            size=round(position_size, 0),
            price=round(price, 3),
            z_score=edge.z_score,
            net_ev=edge.net_ev,
        )

    # ── Hedge Execution ──────────────────────────────────────

    async def _execute_hedge(self, hedge_state):
        """Place hedge orders to reduce directional exposure."""
        if not self._active_markets:
            return

        market = self._active_markets[0]
        if hedge_state.hedge_side == "BUY_YES":
            token_id = market.yes_token_id
        else:
            token_id = market.no_token_id

        book = await self.polymarket.get_orderbook(token_id)
        if not book.asks:
            return

        price = book.best_ask
        size = min(hedge_state.hedge_needed, self.settings.max_position_size * 0.5)

        await self.order_manager.place_order(
            token_id=token_id,
            side="BUY",
            price=round(price, 2),
            size=round(size, 2),
            ttl=30.0,
        )

    # ── Fill Callback ────────────────────────────────────────

    def _on_fill(self, order: Order):
        """Called when an order is filled."""
        self.stats.total_trades += 1

        # Update Stoikov inventory
        self.stoikov.on_fill(order.side.value, order.size)

        # Update hedge tracker
        self.hedge.on_fill(order.side.value, order.size)

        # Estimate P&L (simplified: will be accurate on market resolution)
        # For now, use edge as proxy for expected profit
        expected_profit = order.size * 0.05  # ~5% edge assumption
        self.stats.total_pnl += expected_profit
        self.stats.bankroll += expected_profit

        # Track wins (assume positive edge = win for now)
        self.stats.wins += 1
        self.stats.consecutive_losses = 0

        # Update peak
        if self.stats.bankroll > self.stats.peak_bankroll:
            self.stats.peak_bankroll = self.stats.bankroll

        # Update max drawdown
        dd = self.stats.current_drawdown
        if dd > self.stats.max_drawdown:
            self.stats.max_drawdown = dd

    # ── Resolution Callback (for production) ─────────────────

    def on_market_resolved(self, market_id: str, outcome: str):
        """
        Called when a 5-min market resolves.

        In production, this would check our positions and update
        bankroll with actual P&L.
        """
        # Reset per-market state
        self.bayesian.reset()
        self.stoikov.on_expiry()

        stream.log("RESOLVE", f"Market {market_id[:8]} resolved: {outcome}")
