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
from execution.margin_monitor import MarginMonitor
from execution.order_manager import OrderManager, Order, OrderStatus, OrderSide
from execution.stoikov import StoikovQuoter
from execution.wallet_balance import fetch_hyperliquid_balance, fetch_funding_rate
from feeds.binance_feed import BinanceFeed
from feeds.coinbase_feed import CoinbaseFeed
from feeds.hyperliquid_feed import HyperliquidFeed, Market, OrderBook
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
        self.hyperliquid = HyperliquidFeed(
            api_url=settings.hyperliquid_api_url,
            coin=settings.hyperliquid_coin,
        )
        # Alias for backward compat (web app checks engine.polymarket)
        self.polymarket = self.hyperliquid

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

        # ── Margin Monitor ─────────────────────────────────────
        self.margin_monitor = MarginMonitor(
            api_url=settings.hyperliquid_api_url,
            coin=settings.hyperliquid_coin,
            min_margin_available=settings.min_margin_available,
        )

        # ── State ────────────────────────────────────────────
        self.stats = EngineStats(
            bankroll=settings.initial_bankroll,
            peak_bankroll=settings.initial_bankroll,
            initial_bankroll=settings.initial_bankroll,
        )
        self.circuit = CircuitBreaker(settings)
        self._running = False
        self._last_market_scan: float = 0.0
        self._last_margin_check: float = 0.0
        self._active_markets: list[Market] = []

        # Register fill callback
        self.order_manager.on_fill(self._on_fill)

    # ── Main Loop ────────────────────────────────────────────

    async def start(self):
        """Start the engine and all feeds."""
        logger.info("=" * 60)
        logger.info("ARB ENGINE // SPOT vs PERP ARBITRAGE")
        logger.info(f"Mode: {self.settings.trading_mode.upper()}")
        logger.info(f"Bankroll: ${self.stats.bankroll:,.2f}")
        logger.info(f"Exchange: Hyperliquid ({self.settings.hyperliquid_coin}-PERP)")
        logger.info("=" * 60)

        self._running = True

        # Start feeds concurrently
        await self.hyperliquid.start()

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
            await self.hyperliquid.stop()
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

                # ── Margin & funding check (live mode) ────────
                if (self.settings.trading_mode == "live"
                        and self.order_manager.hl_info
                        and time.time() - self._last_margin_check > self.settings.margin_check_interval):
                    try:
                        hl_bal = fetch_hyperliquid_balance(
                            self.order_manager.hl_address,
                            self.settings.hyperliquid_api_url,
                        )
                        funding = fetch_funding_rate(
                            self.settings.hyperliquid_coin,
                            self.settings.hyperliquid_api_url,
                        )
                        margin_state = self.margin_monitor.update(hl_bal, funding)

                        # Sync bankroll from real account value
                        if hl_bal["account_value"] > 0:
                            self.stats.bankroll = hl_bal["account_value"]
                            if self.stats.bankroll > self.stats.peak_bankroll:
                                self.stats.peak_bankroll = self.stats.bankroll

                        # Log funding cost estimate
                        if margin_state.funding_rate != 0 and self.stats.cycles % 100 == 0:
                            cost_24h = self.margin_monitor.get_funding_cost_estimate(
                                hl_bal.get("margin_used", 0), hours=24
                            )
                            if abs(cost_24h) > 0.01:
                                stream.log(
                                    "FUNDING",
                                    f"Rate: {margin_state.funding_rate*10000:.2f}bps/hr "
                                    f"({margin_state.funding_annualized_pct:.1f}%/yr) "
                                    f"| 24h cost: ${cost_24h:.2f}"
                                )
                    except Exception:
                        logger.exception("Margin check failed")
                    self._last_margin_check = time.time()

                # ── Refresh markets periodically ─────────────
                if time.time() - self._last_market_scan > self.settings.market_scan_interval:
                    self._active_markets = await self.hyperliquid.discover_5min_btc_markets()
                    self._last_market_scan = time.time()
                    if self._active_markets:
                        for m in self._active_markets:
                            stream.log("SCAN", f"{m.question} (window {m.seconds_to_expiry:.0f}s)")
                    else:
                        stream.log("SCAN", "Hyperliquid feed unavailable — retrying...")

                # ── Check existing order fills ───────────────
                hl_mid = await self.hyperliquid.get_midpoint(self.settings.hyperliquid_coin)
                if hl_mid and hl_mid > 0:
                    await self.order_manager.check_fills(current_mid=hl_mid)
                else:
                    await self.order_manager.check_fills(current_mid=self.binance.last_price or 0)

                # ── Skip if no price data ────────────────────
                if self.binance.last_price is None:
                    await asyncio.sleep(self.settings.poll_interval)
                    continue

                # ── Check for expired/resolved markets ─────
                expired = [m for m in self._active_markets if m.seconds_to_expiry <= 0]
                for market in expired:
                    await self._check_market_resolution(market)
                    self._active_markets.remove(market)

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
        """Full pipeline for spot-vs-perp arbitrage: signal → size → execute.

        Instead of binary YES/NO prediction markets, we detect when the
        Hyperliquid BTC-PERP price diverges from Binance/Coinbase spot,
        then trade the convergence.
        """

        # 1. Get Hyperliquid orderbook
        book = await self.hyperliquid.get_orderbook(market.yes_token_id)
        if book.spread <= 0 or book.mid_price <= 0:
            return

        hl_mid = book.mid_price  # Hyperliquid perp price

        # 2. Spot data
        spot_price = self.binance.last_price
        if not spot_price or spot_price <= 0:
            return

        spot_delta = self.binance.get_delta(seconds=10)
        vol = self.volatility.current
        if vol is None:
            return

        # 3. Cross-validate with Coinbase
        coinbase_delta = self.coinbase.get_delta(seconds=10) if self.coinbase.connected else None
        coinbase_price = self.coinbase.last_price if self.coinbase.connected else None
        if coinbase_delta is not None:
            if (spot_delta > 0) != (coinbase_delta > 0) and abs(spot_delta) > 5:
                spot_delta *= 0.5

        # Average spot price from available feeds
        if coinbase_price and coinbase_price > 0:
            avg_spot = (spot_price + coinbase_price) / 2.0
        else:
            avg_spot = spot_price

        # 4. Compute spread: perp premium/discount vs spot
        # Normalized spread: (perp - spot) / spot
        spread_pct = (hl_mid - avg_spot) / avg_spot
        # Map to 0-1 range for Bayesian: 0.5 = no spread, >0.5 = perp premium
        normalized_price = 0.5 + spread_pct * 10  # amplify: 0.1% spread → 0.501
        normalized_price = max(0.01, min(0.99, normalized_price))

        # 5. Bayesian update
        bayes_state = self.bayesian.update(
            spot_delta=spot_delta,
            volatility=vol,
            book_imbalance=book.get_imbalance(),
        )
        fair_price = self.bayesian.fair_price_yes  # fair value of convergence

        # 6. Edge detection — use normalized spread
        edge = self.edge_detector.evaluate(
            poly_price=normalized_price,
            fair_price=fair_price,
            volatility=vol,
        )

        if not edge.is_signal:
            self.stats.signals_rejected += 1
            return

        self.stats.signals_generated += 1

        # 7. Kelly sizing
        # For perp arb: win_prob = probability spread converges
        # spread_pct > 0 → perp overpriced vs spot → SHORT perp
        # spread_pct < 0 → perp underpriced vs spot → LONG perp
        if spread_pct > 0:
            direction = "SHORT"
            win_prob = min(0.85, 0.5 + abs(spread_pct) * 50)
        else:
            direction = "LONG"
            win_prob = min(0.85, 0.5 + abs(spread_pct) * 50)

        # Odds based on expected convergence profit
        risk_reward = max(1.1, abs(spread_pct) * 1000)  # e.g., 0.1% → 1:1
        kelly_result = self.kelly.size(
            win_prob=win_prob,
            odds=risk_reward,
            bankroll=self.stats.bankroll,
        )

        if kelly_result.position_size <= 0:
            return

        # 8. Market impact check
        impact = self.lmsr.estimate(
            order_size=kelly_result.position_size,
            side="SELL" if direction == "SHORT" else "BUY",
            book=book,
        )

        position_size = kelly_result.position_size
        if not impact.is_safe:
            position_size = min(position_size, impact.recommended_size)
            if position_size < 1.0:
                stream.log("FILTER", "impact too high, skipping")
                return

        # 9. Stoikov optimal price
        sigma2 = self.volatility.variance or 0.001
        quote = self.stoikov.quote(
            mid_price=hl_mid,
            sigma2=sigma2,
            time_remaining=market.time_remaining_normalized,
        )

        # 10. Pre-trade margin check (live mode)
        if self.settings.trading_mode == "live":
            can_trade, reason = self.margin_monitor.can_open_position(
                position_size, self.settings.max_leverage
            )
            if not can_trade:
                stream.log("MARGIN", f"Trade blocked: {reason}")
                return

        # 11. Place order on Hyperliquid
        token_id = market.yes_token_id  # "BTC"
        if direction == "LONG":
            price = min(quote.bid, book.best_ask - 0.01)
            side = "BUY"
        else:
            price = max(quote.ask if hasattr(quote, 'ask') else hl_mid + 0.01, book.best_bid + 0.01)
            side = "SELL"

        price = round(price, 1)  # BTC price precision

        # Don't place if too many active orders
        if self.order_manager.active_count >= 5:
            await self.order_manager.cancel_all()

        order = await self.order_manager.place_order(
            token_id=token_id,
            side=side,
            price=price,
            size=round(position_size, 2),
            ttl=self.settings.order_ttl_seconds,
        )

        stream.log(
            "TRADE",
            f"{direction} {side} ${position_size:.0f} @ ${price:,.1f} "
            f"spread={spread_pct*100:.3f}% z={edge.z_score}",
            direction=direction,
            size=round(position_size, 0),
            price=round(price, 1),
            z_score=edge.z_score,
            spread_pct=round(spread_pct * 100, 4),
        )

    # ── Market Resolution ────────────────────────────────────

    async def _check_market_resolution(self, market: Market):
        """Handle window expiry for perp arbitrage.

        For perpetual futures, windows don't 'resolve' — they roll.
        We check if spread has converged and close positions.
        """
        try:
            hl_mid = await self.hyperliquid.get_midpoint(self.settings.hyperliquid_coin)
            spot_price = self.binance.last_price
            if not hl_mid or not spot_price:
                return

            spread_pct = (hl_mid - spot_price) / spot_price
            spread_bps = abs(spread_pct) * 10000  # basis points

            # If spread has converged (< 2 bps), realize profits
            if spread_bps < 2:
                self._realize_perp_pnl(hl_mid)
                stream.log("RESOLVE", f"Spread converged ({spread_bps:.1f}bps), window closed")
            else:
                stream.log("RESOLVE", f"Window expired, spread={spread_bps:.1f}bps — positions carry over")

        except Exception:
            logger.exception("Failed to check window expiry")

    # ── Hedge Execution ──────────────────────────────────────

    async def _execute_hedge(self, hedge_state):
        """Place hedge orders to reduce directional exposure on Hyperliquid."""
        coin = self.settings.hyperliquid_coin
        book = await self.hyperliquid.get_orderbook(coin)
        if not book.asks or not book.bids:
            return

        # For perps: reduce exposure by trading opposite side
        if hedge_state.hedge_side == "BUY_YES":  # too short → buy
            price = book.best_ask
            side = "BUY"
        else:  # too long → sell
            price = book.best_bid
            side = "SELL"

        size = min(hedge_state.hedge_needed, self.settings.max_position_size * 0.5)

        await self.order_manager.place_order(
            token_id=coin,
            side=side,
            price=round(price, 1),
            size=round(size, 2),
            ttl=30.0,
        )

    # ── Fill Callback ────────────────────────────────────────

    def _on_fill(self, order: Order):
        """Called when an order is filled.

        For perp arbitrage: margin is allocated from bankroll.
        P&L is realized when the position is closed (spread converges).
        """
        self.stats.total_trades += 1

        # Update Stoikov inventory
        self.stoikov.on_fill(order.side.value, order.size)

        # Update hedge tracker
        self.hedge.on_fill(order.side.value, order.size)

        # For perp trading, we track margin allocation (not full cost)
        # Using 5x effective leverage: margin = size / 5
        margin = (order.filled_size if order.filled_size > 0 else order.size) * 0.2
        self.stats.bankroll -= margin

        fill_price = order.filled_price if order.filled_price > 0 else order.price
        stream.log(
            "FILL",
            f"{order.side.value} ${order.size:.2f} @ ${fill_price:,.1f} margin=${margin:.2f} | bankroll=${self.stats.bankroll:.2f}",
            order_id=order.id,
            margin=round(margin, 2),
        )

        # Update peak
        if self.stats.bankroll > self.stats.peak_bankroll:
            self.stats.peak_bankroll = self.stats.bankroll

        # Update max drawdown
        dd = self.stats.current_drawdown
        if dd > self.stats.max_drawdown:
            self.stats.max_drawdown = dd

    # ── P&L Realization ─────────────────────────────────────

    def _realize_perp_pnl(self, current_price: float):
        """Realize P&L for perp positions when spread converges.

        For each filled order, compute unrealized P&L and add to bankroll.
        """
        for order in self.order_manager.get_recent_fills(100):
            fill_price = order.filled_price if order.filled_price > 0 else order.price
            fill_size = order.filled_size if order.filled_size > 0 else order.size

            if fill_price <= 0:
                continue

            # Compute P&L based on price movement
            # BUY: profit when price goes up; SELL: profit when price goes down
            price_change_pct = (current_price - fill_price) / fill_price
            if order.side == OrderSide.SELL:
                price_change_pct = -price_change_pct

            pnl = fill_size * price_change_pct

            if pnl > 0:
                self.stats.total_pnl += pnl
                self.stats.bankroll += pnl + fill_size * 0.2  # return margin + profit
                self.stats.wins += 1
                self.stats.consecutive_losses = 0
                stream.log("P&L", f"WIN +${pnl:.2f} | {order.side.value} @ ${fill_price:,.0f} → ${current_price:,.0f}")
            else:
                self.stats.total_pnl += pnl
                self.stats.bankroll += max(0, fill_size * 0.2 + pnl)  # return remaining margin
                self.stats.losses += 1
                self.stats.consecutive_losses += 1
                stream.log("P&L", f"LOSS ${pnl:.2f} | {order.side.value} @ ${fill_price:,.0f} → ${current_price:,.0f}")

        # Update peak / drawdown
        if self.stats.bankroll > self.stats.peak_bankroll:
            self.stats.peak_bankroll = self.stats.bankroll
        dd = self.stats.current_drawdown
        if dd > self.stats.max_drawdown:
            self.stats.max_drawdown = dd

        # Reset per-window state
        self.bayesian.reset()
        self.stoikov.on_expiry()
