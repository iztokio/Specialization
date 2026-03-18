/* ═══════════════════════════════════════════════════════════
   ARB ENGINE — Dashboard JavaScript
   ═══════════════════════════════════════════════════════════ */

// ── Socket.IO Connection ────────────────────────────────────
const socket = io();
let isRunning = false;
let pnlData = { labels: [], values: [] };
let pnlChart = null;
let streamEntries = [];
const MAX_STREAM = 100;
const MAX_CHART_POINTS = 300;

// ── Initialize ──────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
    initChart();
    loadConfig();
    startPolling();
});

// ── Chart.js Setup ──────────────────────────────────────────
function initChart() {
    const ctx = document.getElementById('pnlChart').getContext('2d');

    const gradient = ctx.createLinearGradient(0, 0, 0, 300);
    gradient.addColorStop(0, 'rgba(6, 182, 212, 0.3)');
    gradient.addColorStop(1, 'rgba(6, 182, 212, 0.0)');

    pnlChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: 'Bankroll',
                data: [],
                borderColor: '#06b6d4',
                backgroundColor: gradient,
                fill: true,
                tension: 0.3,
                pointRadius: 0,
                pointHoverRadius: 4,
                borderWidth: 2,
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: { duration: 300 },
            scales: {
                x: {
                    display: true,
                    grid: { color: 'rgba(30, 41, 59, 0.5)' },
                    ticks: { color: '#475569', font: { size: 9, family: 'monospace' }, maxTicksLimit: 8 }
                },
                y: {
                    display: true,
                    grid: { color: 'rgba(30, 41, 59, 0.5)' },
                    ticks: {
                        color: '#475569',
                        font: { size: 10, family: 'monospace' },
                        callback: v => '$' + v.toLocaleString()
                    }
                }
            },
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: '#1e293b',
                    titleColor: '#e2e8f0',
                    bodyColor: '#94a3b8',
                    borderColor: '#334155',
                    borderWidth: 1,
                    callbacks: {
                        label: ctx => '$' + ctx.parsed.y.toLocaleString(undefined, { minimumFractionDigits: 2 })
                    }
                }
            },
            interaction: { intersect: false, mode: 'index' }
        }
    });
}

// ── Polling (REST fallback + Socket.IO) ─────────────────────
function startPolling() {
    // Poll stats every 2 seconds
    setInterval(async () => {
        try {
            const resp = await fetch('/api/stats');
            const data = await resp.json();
            if (data.running) updateStats(data);
        } catch (e) { /* ignore */ }
    }, 2000);

    // Poll module status every 3 seconds
    setInterval(async () => {
        try {
            const resp = await fetch('/api/module_status');
            const data = await resp.json();
            if (data.running) updateModuleStatus(data);
        } catch (e) { /* ignore */ }
    }, 3000);

    // Poll stream every 2 seconds
    setInterval(async () => {
        try {
            const resp = await fetch('/api/stream');
            const entries = await resp.json();
            updateStreamFull(entries);
        } catch (e) { /* ignore */ }
    }, 2000);

    // Poll orders every 3 seconds
    setInterval(async () => {
        try {
            const resp = await fetch('/api/orders');
            const data = await resp.json();
            updateOrders(data);
        } catch (e) { /* ignore */ }
    }, 3000);

    // Poll P&L history every 5 seconds
    setInterval(async () => {
        try {
            const resp = await fetch('/api/pnl_history');
            const history = await resp.json();
            updateChartFull(history);
        } catch (e) { /* ignore */ }
    }, 5000);
}

// ── Socket.IO Events ────────────────────────────────────────
socket.on('connected', (data) => {
    console.log('Dashboard connected to server');
});

socket.on('stats_update', (data) => {
    updateStats(data);
});

socket.on('trade_update', (data) => {
    // Add point to chart
    addChartPoint(data.bankroll);
});

socket.on('stream_entry', (data) => {
    addStreamEntry(data);
});

socket.on('engine_status', (data) => {
    if (data.status === 'started') {
        setRunning(true, data.mode);
    } else if (data.status === 'stopped') {
        setRunning(false);
    }
});

socket.on('engine_error', (data) => {
    addStreamEntry({
        timestamp: Date.now() / 1000,
        tag: 'ERROR',
        message: data.error
    });
    setRunning(false);
});

// ── Update Functions ────────────────────────────────────────
function updateStats(data) {
    setText('mBalance', '$' + num(data.bankroll));
    setText('mPnl', (data.total_pnl >= 0 ? '+$' : '-$') + num(Math.abs(data.total_pnl)));
    setText('mRoi', num(data.roi_pct, 1) + '%');
    setText('mWinRate', num(data.win_rate, 1) + '%');
    setText('mTradesHr', Math.round(data.trades_per_hour));
    setText('mTotalTrades', data.total_trades.toLocaleString());
    setText('mDrawdown', num(data.max_drawdown, 2) + '%');
    setText('chartBankroll', '$' + num(data.bankroll));

    // Color P&L
    const pnlEl = document.getElementById('mPnl');
    pnlEl.className = 'metric-value ' + (data.total_pnl >= 0 ? 'pnl-positive' : 'pnl-negative');
}

function updateModuleStatus(data) {
    setStatus('sBinance', data.binance_connected);
    setStatus('sCoinbase', data.coinbase_connected);

    // Hyperliquid status
    const hlEl = document.getElementById('sHyperliquid');
    if (hlEl) {
        if (data.hyperliquid_live) {
            hlEl.textContent = 'LIVE';
            hlEl.className = 'status-value online';
        } else if (data.hyperliquid_connected) {
            hlEl.textContent = 'ONLINE (paper)';
            hlEl.className = 'status-value warning';
        } else {
            hlEl.textContent = 'OFFLINE';
            hlEl.className = 'status-value offline';
        }
    }

    setText('sBtcPrice', data.binance_price ? '$' + num(data.binance_price, 0) : '—');
    setText('sBayes', 'post=' + (data.bayesian_posterior || 0).toFixed(3));
    setText('sVol', data.volatility ? data.volatility.toFixed(6) : 'warming...');
    setText('sStoikov', 'q=' + (data.stoikov_inventory || 0).toFixed(1));
    setText('sHedge', 'net=$' + num(data.hedge_net_exposure || 0, 0));
    setText('sOrders', data.active_orders || 0);
    setText('sSignals', (data.signals_generated || 0) + ' generated');

    // Margin & Funding
    if (data.hl_account_value > 0) {
        setText('sHlAccount', '$' + num(data.hl_account_value));
    }
    if (data.margin_ratio !== undefined) {
        const marginEl = document.getElementById('sMargin');
        if (marginEl) {
            const ratio = data.margin_ratio || 0;
            marginEl.textContent = ratio.toFixed(1) + '% used | $' + num(data.margin_available || 0) + ' free';
            if (ratio > 90) {
                marginEl.className = 'status-value offline';
            } else if (ratio > 75) {
                marginEl.className = 'status-value warning';
            } else {
                marginEl.className = 'status-value online';
            }
        }
    }
    if (data.funding_rate_bps !== undefined) {
        const fundingBps = data.funding_rate_bps || 0;
        const annual = data.funding_annualized || 0;
        setText('sFunding', fundingBps.toFixed(2) + ' bps/hr (' + annual.toFixed(1) + '%/yr)');
    }
    if (data.mark_price > 0 || data.oracle_price > 0) {
        setText('sMarkOracle', '$' + num(data.mark_price || 0, 0) + ' / $' + num(data.oracle_price || 0, 0));
    }

    // Margin warning
    if (data.margin_warning) {
        const circuitEl = document.getElementById('sCircuit');
        circuitEl.textContent = data.margin_warning;
        circuitEl.className = 'status-value offline';
    } else {
        const circuitEl = document.getElementById('sCircuit');
        if (data.circuit_tripped) {
            circuitEl.textContent = 'TRIPPED: ' + data.circuit_reason;
            circuitEl.className = 'status-value offline';
        } else {
            circuitEl.textContent = 'OK';
            circuitEl.className = 'status-value online';
        }
    }

    // Update mode badge
    const badge = document.getElementById('modeBadge');
    const mode = (data.trading_mode || 'paper').toUpperCase();
    badge.textContent = mode;
    badge.className = 'mode-badge' + (data.trading_mode === 'live' ? ' live' : '');

    // Safe to trade indicator
    if (data.trading_mode === 'live' && data.safe_to_trade === false) {
        const circuitEl = document.getElementById('sCircuit');
        circuitEl.textContent = 'UNSAFE: ' + (data.margin_warning || 'margin insufficient');
        circuitEl.className = 'status-value offline';
    }
}

function updateOrders(data) {
    // Active orders
    const activeBody = document.getElementById('activeOrdersBody');
    if (!data.active || data.active.length === 0) {
        activeBody.innerHTML = '<tr><td colspan="5" class="dim">No active orders</td></tr>';
    } else {
        activeBody.innerHTML = data.active.map(o => `
            <tr>
                <td>${o.id}</td>
                <td class="side-${o.side.toLowerCase()}">${o.side}</td>
                <td>${o.price.toFixed(3)}</td>
                <td>$${num(o.size)}</td>
                <td>${o.age_seconds.toFixed(0)}s</td>
            </tr>
        `).join('');
    }

    // Fills
    const fillsBody = document.getElementById('fillsBody');
    if (!data.fills || data.fills.length === 0) {
        fillsBody.innerHTML = '<tr><td colspan="5" class="dim">No fills yet</td></tr>';
    } else {
        fillsBody.innerHTML = data.fills.slice(0, 15).map(o => `
            <tr>
                <td>${o.id}</td>
                <td class="side-${o.side.toLowerCase()}">${o.side}</td>
                <td>${o.price.toFixed(3)}</td>
                <td>$${num(o.size)}</td>
                <td style="color: var(--accent-green)">${o.status}</td>
            </tr>
        `).join('');
    }
}

function updateStreamFull(entries) {
    if (!entries || entries.length === 0) return;
    const container = document.getElementById('streamContainer');
    container.innerHTML = entries.slice(-MAX_STREAM).map(formatStreamEntry).join('');
    container.scrollTop = container.scrollHeight;
}

function addStreamEntry(entry) {
    const container = document.getElementById('streamContainer');
    const first = container.querySelector('.dim');
    if (first && first.textContent.includes('Waiting')) {
        container.innerHTML = '';
    }
    container.insertAdjacentHTML('beforeend', formatStreamEntry(entry));

    // Trim
    while (container.children.length > MAX_STREAM) {
        container.removeChild(container.firstChild);
    }
    container.scrollTop = container.scrollHeight;
}

function formatStreamEntry(entry) {
    const time = formatTime(entry.timestamp);
    const tag = entry.tag || 'INFO';
    return `<div class="stream-entry">` +
        `<span class="time">${time}</span>` +
        `<span class="tag tag-${tag}">[${tag.padEnd(7)}]</span>` +
        `<span>${escapeHtml(entry.message || '')}</span>` +
        `</div>`;
}

function addChartPoint(bankroll) {
    const label = new Date().toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' });
    const chart = pnlChart;
    chart.data.labels.push(label);
    chart.data.datasets[0].data.push(bankroll);

    if (chart.data.labels.length > MAX_CHART_POINTS) {
        chart.data.labels.shift();
        chart.data.datasets[0].data.shift();
    }
    chart.update('none');
}

function updateChartFull(history) {
    if (!history || history.length === 0) return;
    const chart = pnlChart;
    chart.data.labels = history.map(h =>
        new Date(h.time * 1000).toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' })
    );
    chart.data.datasets[0].data = history.map(h => h.bankroll);
    chart.update('none');
}

// ── Engine Controls ─────────────────────────────────────────
function startEngine() {
    socket.emit('start_engine');
    setRunning(true);
}

function stopEngine() {
    if (confirm('Are you sure you want to stop the engine?')) {
        socket.emit('stop_engine');
        setRunning(false);
    }
}

function cancelAllOrders() {
    socket.emit('cancel_all_orders');
}

function setRunning(running, mode) {
    isRunning = running;
    document.getElementById('btnStart').disabled = running;
    document.getElementById('btnStop').disabled = !running;

    const dot = document.getElementById('statusDot');
    const text = document.getElementById('statusText');
    if (running) {
        dot.className = 'status-dot online';
        text.textContent = 'Running';
    } else {
        dot.className = 'status-dot';
        text.textContent = 'Offline';
    }
}

// ── Settings Modal ──────────────────────────────────────────
async function loadConfig() {
    try {
        const resp = await fetch('/api/config');
        const cfg = await resp.json();
        document.getElementById('cfgMode').value = cfg.trading_mode;
        document.getElementById('cfgBankroll').value = cfg.initial_bankroll;
        document.getElementById('cfgMaxPosition').value = cfg.max_position_size;
        document.getElementById('cfgZThreshold').value = cfg.z_score_threshold;
        document.getElementById('cfgMinEv').value = cfg.min_net_ev;
        document.getElementById('cfgKelly').value = cfg.kelly_fraction;
        document.getElementById('cfgGamma').value = cfg.gamma_risk;
        document.getElementById('cfgMaxInventory').value = cfg.max_inventory;
        document.getElementById('cfgOrderTtl').value = cfg.order_ttl_seconds;
        document.getElementById('cfgCircuitEnabled').checked = cfg.circuit_breaker_enabled;
        document.getElementById('cfgMaxDrawdown').value = cfg.circuit_max_drawdown * 100;
        document.getElementById('cfgMaxLosses').value = cfg.circuit_max_consecutive_losses;
    } catch (e) {
        console.error('Failed to load config:', e);
    }
}

function openSettings() {
    document.getElementById('settingsModal').classList.add('active');
    // Show live warning when mode changes
    document.getElementById('cfgMode').addEventListener('change', (e) => {
        document.getElementById('liveWarning').style.display =
            e.target.value === 'live' ? 'block' : 'none';
    });
}

function closeSettings() {
    document.getElementById('settingsModal').classList.remove('active');
}

async function saveSettings() {
    const cfg = {
        trading_mode: document.getElementById('cfgMode').value,
        initial_bankroll: parseFloat(document.getElementById('cfgBankroll').value),
        max_position_size: parseFloat(document.getElementById('cfgMaxPosition').value),
        z_score_threshold: parseFloat(document.getElementById('cfgZThreshold').value),
        min_net_ev: parseFloat(document.getElementById('cfgMinEv').value),
        kelly_fraction: parseFloat(document.getElementById('cfgKelly').value),
        gamma_risk: parseFloat(document.getElementById('cfgGamma').value),
        max_inventory: parseFloat(document.getElementById('cfgMaxInventory').value),
        order_ttl_seconds: parseFloat(document.getElementById('cfgOrderTtl').value),
        circuit_breaker_enabled: document.getElementById('cfgCircuitEnabled').checked,
        circuit_max_drawdown: parseFloat(document.getElementById('cfgMaxDrawdown').value) / 100,
        circuit_max_consecutive_losses: parseInt(document.getElementById('cfgMaxLosses').value),
    };

    try {
        const resp = await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(cfg),
        });
        const result = await resp.json();
        if (result.status === 'ok') {
            closeSettings();
            addStreamEntry({
                timestamp: Date.now() / 1000,
                tag: 'CONFIG',
                message: 'Settings updated successfully'
            });
        }
    } catch (e) {
        alert('Failed to save settings: ' + e);
    }
}

function clearStream() {
    document.getElementById('streamContainer').innerHTML =
        '<div class="stream-entry dim">Stream cleared</div>';
}

// ── Wallet Connection ───────────────────────────────────────
let walletConnected = false;
let walletUsdcBalance = 0;

function openWallet() {
    document.getElementById('walletModal').classList.add('active');
    showWalletStep(walletConnected ? 3 : 1);
}

function closeWallet() {
    document.getElementById('walletModal').classList.remove('active');
}

function showWalletStep(step) {
    for (let i = 1; i <= 4; i++) {
        document.getElementById('walletStep' + i).style.display = i === step ? 'block' : 'none';
    }
}

function connectPrivateKey() {
    showWalletStep(2);
}

async function connectEnvFile() {
    try {
        const resp = await fetch('/api/wallet/connect', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ source: 'env' }),
        });
        const data = await resp.json();
        if (data.status === 'ok') {
            onWalletConnected(data);
        } else {
            alert('No wallet configured in .env file. Please use Private Key option.');
        }
    } catch (e) {
        alert('Error: ' + e);
    }
}

async function submitPrivateKey() {
    const key = document.getElementById('walletPrivateKey').value.trim();
    const funder = document.getElementById('walletFunder').value.trim();

    if (!key || !key.startsWith('0x') || key.length < 64) {
        alert('Invalid private key. Must start with 0x and be 66 characters.');
        return;
    }

    try {
        const resp = await fetch('/api/wallet/connect', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ private_key: key, funder: funder || null }),
        });
        const data = await resp.json();
        if (data.status === 'ok') {
            document.getElementById('walletPrivateKey').value = '';
            onWalletConnected(data);
        } else {
            alert('Connection failed: ' + (data.error || 'Unknown error'));
        }
    } catch (e) {
        alert('Error: ' + e);
    }
}

async function generateNewWallet() {
    try {
        const resp = await fetch('/api/wallet/generate', { method: 'POST' });
        const data = await resp.json();
        if (data.status === 'ok') {
            document.getElementById('wNewAddress').textContent = data.address;
            document.getElementById('wNewKey').textContent = data.private_key;
            showWalletStep(4);
        } else {
            alert('Failed to generate wallet: ' + (data.error || ''));
        }
    } catch (e) {
        alert('Error: ' + e);
    }
}

async function useGeneratedWallet() {
    const key = document.getElementById('wNewKey').textContent;
    try {
        const resp = await fetch('/api/wallet/connect', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ private_key: key }),
        });
        const data = await resp.json();
        if (data.status === 'ok') {
            onWalletConnected(data);
        }
    } catch (e) {
        alert('Error: ' + e);
    }
}

function onWalletConnected(data) {
    walletConnected = true;
    walletUsdcBalance = data.usdc_raw || 0;
    showWalletStep(3);

    setText('wAddress', data.address || '—');
    setText('wBalance', data.usdc_balance || 'N/A');
    setText('wMatic', data.matic_balance || 'N/A');

    // Update header button
    const btn = document.getElementById('btnWallet');
    btn.classList.add('connected');
    const addr = data.address || '';
    document.getElementById('walletLabel').textContent =
        addr ? addr.slice(0, 6) + '...' + addr.slice(-4) : 'Connected';
    document.getElementById('walletIcon').textContent = '\u2705';

    // Auto-set bankroll from wallet balance if needed
    if (walletUsdcBalance > 0) {
        const cfgBankroll = document.getElementById('cfgBankroll');
        const currentBankroll = parseFloat(cfgBankroll.value);
        if (walletUsdcBalance < currentBankroll) {
            cfgBankroll.value = Math.floor(walletUsdcBalance * 100) / 100;
            const cfgMaxPos = document.getElementById('cfgMaxPosition');
            cfgMaxPos.value = Math.floor(walletUsdcBalance * 0.5 * 100) / 100;
        }
    }

    // Show wallet balance in metrics bar
    if (walletUsdcBalance > 0) {
        const walletMetric = document.getElementById('mWalletMetric');
        if (walletMetric) walletMetric.style.display = '';
        setText('mWalletBalance', '$' + num(walletUsdcBalance));
    }

    addStreamEntry({
        timestamp: Date.now() / 1000,
        tag: 'WALLET',
        message: 'Connected: ' + (addr ? addr.slice(0, 10) + '...' : 'OK'),
    });

    // Fetch multi-chain balances
    refreshAllBalances();
}

async function refreshAllBalances() {
    setText('wHlValue', 'loading...');
    setText('wHlMargin', 'loading...');
    setText('wHlPositions', 'loading...');
    setText('wArbUsdc', 'loading...');
    setText('wArbEth', 'loading...');
    setText('wBalance', 'loading...');
    setText('wMatic', 'loading...');

    try {
        const resp = await fetch('/api/balances/all');
        const data = await resp.json();
        if (data.status !== 'ok') {
            setText('wHlValue', 'Error');
            return;
        }

        // Hyperliquid
        const hl = data.hyperliquid || {};
        if (!hl.error) {
            setText('wHlValue', '$' + num(hl.account_value || 0));
            setText('wHlMargin', '$' + num(hl.margin_available || 0) + ' free');
            setText('wHlPositions', (hl.positions || []).length + ' open');

            // Update header with HL trading balance
            const hlVal = hl.account_value || 0;
            const addr = document.getElementById('wAddress').textContent;
            if (addr && addr !== '—') {
                document.getElementById('walletLabel').textContent =
                    addr.slice(0, 6) + '...' + addr.slice(-4) + (hlVal > 0 ? ' ($' + hlVal.toFixed(0) + ')' : '');
            }
            if (hlVal > 0) {
                walletUsdcBalance = hlVal;
                const walletMetric = document.getElementById('mWalletMetric');
                if (walletMetric) walletMetric.style.display = '';
                setText('mWalletBalance', '$' + num(hlVal));
            }
        } else {
            setText('wHlValue', 'Error: ' + hl.error);
        }

        // Arbitrum
        const arb = data.arbitrum || {};
        if (!arb.error) {
            let arbStr = '$' + num(arb.usdc_balance || 0);
            if (arb.usdce_balance > 0) arbStr += ' (+$' + num(arb.usdce_balance) + ' USDC.e)';
            setText('wArbUsdc', arbStr);
            const ethBal = arb.eth_balance || 0;
            const ethEl = document.getElementById('wArbEth');
            ethEl.textContent = ethBal.toFixed(6) + ' ETH';
            ethEl.className = 'status-value ' + (ethBal < 0.0005 ? 'offline' : 'online');
        } else {
            setText('wArbUsdc', 'Error');
        }

        // Polygon (legacy)
        const poly = data.polygon || {};
        if (!poly.error) {
            setText('wBalance', '$' + num(poly.total_usdc || 0));
            setText('wMatic', (poly.pol_balance || 0).toFixed(4) + ' POL');
        }

        // Summary stream entry
        addStreamEntry({
            timestamp: Date.now() / 1000,
            tag: 'WALLET',
            message: 'HL: $' + num(hl.account_value || 0) +
                     ' | Arb: $' + num(arb.total_usdc || 0) +
                     ' | Poly: $' + num(poly.total_usdc || 0) +
                     ' | Total: $' + num(data.total_available_usd || 0),
        });

    } catch (e) {
        setText('wHlValue', 'Fetch failed');
        console.error('Balance fetch error:', e);
    }
}

// Keep old name as alias
async function refreshBalance() { return refreshAllBalances(); }

async function switchToLive() {
    if (!confirm(
        'Switch to LIVE trading mode?\n\n' +
        'This will use REAL MONEY from your connected wallet.\n' +
        'Make sure you understand the risks.\n\n' +
        (walletUsdcBalance > 0 ? 'Wallet balance: $' + walletUsdcBalance.toFixed(2) + ' USDC' : '')
    )) return;

    try {
        // Auto-set bankroll to wallet balance for live mode
        const cfg = { trading_mode: 'live' };
        if (walletUsdcBalance > 0) {
            cfg.initial_bankroll = walletUsdcBalance;
            cfg.max_position_size = Math.floor(walletUsdcBalance * 0.5 * 100) / 100;
        }
        await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(cfg),
        });
        const badge = document.getElementById('modeBadge');
        badge.textContent = 'LIVE';
        badge.className = 'mode-badge live';
        closeWallet();
        addStreamEntry({
            timestamp: Date.now() / 1000,
            tag: 'CONFIG',
            message: 'Switched to LIVE mode | Bankroll: $' + (walletUsdcBalance > 0 ? walletUsdcBalance.toFixed(2) : '?'),
        });
    } catch (e) {
        alert('Error: ' + e);
    }
}

function disconnectWallet() {
    walletConnected = false;
    walletUsdcBalance = 0;
    const btn = document.getElementById('btnWallet');
    btn.classList.remove('connected');
    document.getElementById('walletLabel').textContent = 'Connect Wallet';
    document.getElementById('walletIcon').textContent = '\u26D3';
    const walletMetric = document.getElementById('mWalletMetric');
    if (walletMetric) walletMetric.style.display = 'none';
    showWalletStep(1);
    fetch('/api/wallet/disconnect', { method: 'POST' });
}

// ── Helpers ─────────────────────────────────────────────────
function setText(id, text) {
    const el = document.getElementById(id);
    if (el) el.textContent = text;
}

function setStatus(id, isOnline) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = isOnline ? 'ONLINE' : 'OFFLINE';
    el.className = 'status-value ' + (isOnline ? 'online' : 'offline');
}

function num(n, decimals = 2) {
    if (n === null || n === undefined) return '0';
    return Number(n).toLocaleString(undefined, {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals
    });
}

function formatTime(ts) {
    const d = new Date(ts * 1000);
    return d.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// ── Bridge Functions ────────────────────────────────────────

async function bridgeCheck() {
    const amount = parseFloat(document.getElementById('bridgeAmount').value) || 100;
    const statusEl = document.getElementById('bridgeStatus');
    statusEl.textContent = 'Checking deposit readiness...';

    try {
        const resp = await fetch('/api/bridge/check', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ amount }),
        });
        const data = await resp.json();

        let html = data.ready
            ? '<span style="color:var(--accent-green)">READY to deposit $' + amount + '</span>'
            : '<span style="color:var(--accent-red)">NOT READY</span>';

        html += '<br>';
        (data.checks || []).forEach(c => {
            const icon = c[1] ? '\u2705' : '\u274C';
            html += icon + ' ' + escapeHtml(c[0]) + ': ' + escapeHtml(c[2]) + '<br>';
        });

        if (data.actions_needed && data.actions_needed.length > 0) {
            html += '<br><strong>Actions needed:</strong><br>';
            data.actions_needed.forEach(a => {
                html += '\u2022 ' + escapeHtml(a) + '<br>';
            });
        }

        statusEl.innerHTML = html;
    } catch (e) {
        statusEl.textContent = 'Check failed: ' + e;
    }
}

async function bridgeDeposit() {
    const amount = parseFloat(document.getElementById('bridgeAmount').value);
    if (!amount || amount <= 0) {
        alert('Enter a valid USDC amount');
        return;
    }
    if (!confirm('Deposit $' + amount.toFixed(2) + ' USDC from Arbitrum to Hyperliquid?\n\nThis will execute on-chain transactions.')) {
        return;
    }

    const statusEl = document.getElementById('bridgeStatus');
    statusEl.textContent = 'Depositing... (this may take 1-2 minutes)';

    try {
        const resp = await fetch('/api/bridge/deposit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ amount }),
        });
        const data = await resp.json();

        if (data.success) {
            statusEl.innerHTML = '<span style="color:var(--accent-green)">Deposit sent! tx=' +
                escapeHtml(data.tx_hash || '').slice(0, 20) + '...</span>' +
                '<br>Gas: ' + (data.gas_cost_eth || 0).toFixed(6) + ' ETH' +
                '<br><em>Funds appear on Hyperliquid in 1-5 minutes</em>';
            addStreamEntry({
                timestamp: Date.now() / 1000,
                tag: 'BRIDGE',
                message: 'Deposited $' + amount + ' to Hyperliquid',
            });
            // Refresh balances after short delay
            setTimeout(refreshAllBalances, 10000);
        } else {
            statusEl.innerHTML = '<span style="color:var(--accent-red)">Deposit failed: ' +
                escapeHtml(data.error || 'Unknown error') + '</span>';
        }
    } catch (e) {
        statusEl.textContent = 'Deposit error: ' + e;
    }
}

async function bridgeWithdraw() {
    const amount = parseFloat(document.getElementById('bridgeAmount').value);
    if (!amount || amount <= 0) {
        alert('Enter a valid USDC amount');
        return;
    }
    if (!confirm('Withdraw $' + amount.toFixed(2) + ' from Hyperliquid to Arbitrum?')) {
        return;
    }

    const statusEl = document.getElementById('bridgeStatus');
    statusEl.textContent = 'Withdrawing...';

    try {
        const resp = await fetch('/api/bridge/withdraw', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ amount }),
        });
        const data = await resp.json();

        if (data.success) {
            statusEl.innerHTML = '<span style="color:var(--accent-green)">Withdrawal initiated! Funds arrive on Arbitrum in ~10 minutes.</span>';
            setTimeout(refreshAllBalances, 15000);
        } else {
            statusEl.innerHTML = '<span style="color:var(--accent-red)">Withdrawal failed: ' +
                escapeHtml(data.error || 'Unknown') + '</span>';
        }
    } catch (e) {
        statusEl.textContent = 'Withdrawal error: ' + e;
    }
}

async function showBridgeGuide() {
    const chain = prompt('From which chain? (ethereum, polygon, bsc, base)', 'ethereum');
    if (!chain) return;

    try {
        const resp = await fetch('/api/bridge/guide?chain=' + encodeURIComponent(chain));
        const guide = await resp.json();

        let msg = 'Bridging from ' + (guide.chain || chain) + ' to Arbitrum:\n\n';
        (guide.methods || []).forEach(m => {
            msg += '\u2022 ' + m.name + '\n';
            msg += '  URL: ' + m.url + '\n';
            msg += '  Time: ' + m.time + '\n';
            msg += '  Cost: ' + m.cost + '\n';
            if (m.notes) msg += '  Notes: ' + m.notes + '\n';
            msg += '\n';
        });
        msg += guide.final_step || '';
        alert(msg);
    } catch (e) {
        alert('Failed to load guide: ' + e);
    }
}
