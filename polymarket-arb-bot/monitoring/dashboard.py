"""
Real-time terminal dashboard using Rich.

Displays:
- Bot metrics (balance, ROI, win rate, trades/hr, Sharpe)
- Status of all modules (feeds, signals, execution)
- Training stream (last N log entries)
- P&L summary
"""

from __future__ import annotations

import asyncio
import time

from rich.console import Console
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
from rich.text import Text

from monitoring.logger import TrainingStream


class Dashboard:
    """Terminal-based live dashboard for the arbitrage engine."""

    def __init__(self, engine):
        self.engine = engine
        self.console = Console()
        self._running = False

    async def start(self, refresh_rate: float = 1.0):
        """Run the dashboard, updating every refresh_rate seconds."""
        self._running = True
        with Live(
            self._render(),
            console=self.console,
            refresh_per_second=int(1 / refresh_rate),
            screen=True,
        ) as live:
            while self._running:
                live.update(self._render())
                await asyncio.sleep(refresh_rate)

    def stop(self):
        self._running = False

    def _render(self) -> Layout:
        layout = Layout()
        layout.split_column(
            Layout(name="header", size=3),
            Layout(name="body"),
            Layout(name="footer", size=3),
        )

        layout["body"].split_row(
            Layout(name="left", ratio=1),
            Layout(name="center", ratio=1),
            Layout(name="right", ratio=1),
        )

        layout["header"].update(self._header())
        layout["left"].update(self._metrics_panel())
        layout["center"].update(self._status_panel())
        layout["right"].update(self._stream_panel())
        layout["footer"].update(self._footer())

        return layout

    def _header(self) -> Panel:
        stats = self.engine.stats
        mode = self.engine.settings.trading_mode.upper()
        header_text = Text()
        header_text.append("ARB ENGINE // 5-MIN BTC MARKETS", style="bold cyan")
        header_text.append(f"   [{mode}]", style="bold yellow" if mode == "PAPER" else "bold red")
        header_text.append(f"   Cycle #{stats.cycles}", style="dim")
        return Panel(header_text, style="cyan")

    def _metrics_panel(self) -> Panel:
        stats = self.engine.stats
        table = Table(show_header=False, box=None, padding=(0, 1))
        table.add_column("Metric", style="dim")
        table.add_column("Value", style="bold")

        table.add_row("Balance", f"${stats.bankroll:,.2f}")
        table.add_row("Start", f"${stats.initial_bankroll:,.2f}")
        table.add_row("ROI", f"{stats.roi_pct:,.1f}%")
        table.add_row("Win Rate", f"{stats.win_rate * 100:.1f}%")
        table.add_row("Trades/hr", f"{stats.trades_per_hour:.0f}")
        table.add_row("Total", f"{stats.total_trades:,}")
        table.add_row("P&L", f"${stats.total_pnl:,.2f}")
        table.add_row("Max DD", f"{stats.max_drawdown * 100:.1f}%")
        table.add_row("Signals", f"{stats.signals_generated}")
        table.add_row("Rejected", f"{stats.signals_rejected}")

        return Panel(table, title="BOT METRICS", border_style="green")

    def _status_panel(self) -> Panel:
        table = Table(show_header=False, box=None, padding=(0, 1))
        table.add_column("Module", style="dim")
        table.add_column("Status")

        # Feed status
        bn_status = "[green]ONLINE[/]" if self.engine.binance.connected else "[red]OFFLINE[/]"
        cb_status = "[green]ONLINE[/]" if self.engine.coinbase.connected else "[yellow]OFFLINE[/]"
        table.add_row("Binance", bn_status)
        table.add_row("Coinbase", cb_status)

        # Module status
        table.add_row("Bayes", f"[green]post={self.engine.bayesian.posterior:.3f}[/]")

        vol = self.engine.volatility.current
        vol_str = f"[green]{vol:.6f}[/]" if vol else "[yellow]warming[/]"
        table.add_row("Volatility", vol_str)

        table.add_row("Stoikov", f"[green]q={self.engine.stoikov.inventory:.1f}[/]")
        table.add_row("Orders", f"[cyan]{self.engine.order_manager.active_count} active[/]")

        # Circuit breaker
        if self.engine.circuit.is_tripped:
            table.add_row("Circuit", f"[red]TRIPPED: {self.engine.circuit.reason}[/]")
        else:
            table.add_row("Circuit", "[green]OK[/]")

        # Hedge
        net_exp = self.engine.hedge.net_exposure
        table.add_row("Hedge", f"net=${net_exp:,.0f}")

        return Panel(table, title="STATUS", border_style="blue")

    def _stream_panel(self) -> Panel:
        entries = TrainingStream.get().last(15)
        lines = []
        for entry in entries:
            ts = time.strftime("%H:%M:%S", time.localtime(entry.timestamp))
            tag = entry.tag[:7].ljust(7)
            msg = entry.message[:40]
            lines.append(f"[dim]{ts}[/] [{self._tag_color(entry.tag)}]{tag}[/] {msg}")

        text = "\n".join(lines) if lines else "[dim]Waiting for data...[/]"
        return Panel(text, title="TRAINING STREAM", border_style="yellow")

    def _footer(self) -> Panel:
        stats = self.engine.stats
        mode = self.engine.settings.trading_mode.upper()
        elapsed = time.time() - stats.start_time
        hrs = elapsed / 3600

        footer = (
            f"LIMIT ORDERS | 5-MIN BTC | {mode} | "
            f"{stats.trades_per_hour:.0f} TRADES/HR | "
            f"{stats.win_rate * 100:.1f}% WIN | "
            f"${stats.initial_bankroll:,.0f} -> ${stats.bankroll:,.0f} | "
            f"{hrs:.1f}h elapsed"
        )
        return Panel(footer, style="dim")

    @staticmethod
    def _tag_color(tag: str) -> str:
        colors = {
            "BAYES": "magenta",
            "EDGE": "green",
            "FILTER": "red",
            "KELLY": "cyan",
            "STOIKOV": "blue",
            "FILL": "bold green",
            "ORDER": "yellow",
            "TRADE": "bold cyan",
            "SCAN": "dim",
            "LMSR": "blue",
            "HEDGE": "yellow",
            "MC": "magenta",
            "CIRCUIT": "bold red",
        }
        return colors.get(tag, "white")
