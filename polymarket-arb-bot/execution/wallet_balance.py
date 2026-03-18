"""
Multi-chain wallet balance fetcher.

Supports:
  - Hyperliquid L1 (trading margin via API)
  - Arbitrum (USDC for deposits to Hyperliquid)
  - Polygon (legacy, for Polymarket compat)

Hyperliquid deposits come through Arbitrum, NOT Polygon.
"""

from __future__ import annotations

import logging
from typing import Optional

import httpx

logger = logging.getLogger("wallet_balance")

# ── Token Addresses ─────────────────────────────────────────

# Arbitrum One
ARBITRUM_USDC = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"  # native USDC
ARBITRUM_USDCE = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"  # bridged USDC.e

# Polygon (legacy)
POLYGON_USDC = "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"
POLYGON_USDCE = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"

# ERC-20 balanceOf ABI
ERC20_BALANCE_ABI = [
    {
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function",
    }
]

# ── RPC Endpoints ───────────────────────────────────────────

ARBITRUM_RPCS = [
    "https://arb1.arbitrum.io/rpc",
    "https://arbitrum.llamarpc.com",
    "https://rpc.ankr.com/arbitrum",
    "https://1rpc.io/arb",
]

POLYGON_RPCS = [
    "https://polygon-rpc.com",
    "https://rpc-mainnet.matic.quiknode.pro",
    "https://polygon.llamarpc.com",
    "https://rpc.ankr.com/polygon",
]

# Hyperliquid API
HYPERLIQUID_API = "https://api.hyperliquid.xyz"


# ═══════════════════════════════════════════════════════════
#  Hyperliquid Balance (via REST API — no gas, no RPC)
# ═══════════════════════════════════════════════════════════

def fetch_hyperliquid_balance(address: str, api_url: str = HYPERLIQUID_API) -> dict:
    """
    Fetch account state from Hyperliquid API.

    Returns:
        account_value: total account value in USD
        margin_used: margin currently used by positions
        margin_available: free margin available for trading
        withdrawable: amount available for withdrawal
        positions: list of open positions with details
        leverage: current leverage info
        error: error message or None
    """
    result = {
        "account_value": 0.0,
        "margin_used": 0.0,
        "margin_available": 0.0,
        "withdrawable": 0.0,
        "unrealized_pnl": 0.0,
        "positions": [],
        "error": None,
    }

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(
                f"{api_url}/info",
                json={"type": "clearinghouseState", "user": address},
            )
            resp.raise_for_status()
            data = resp.json()

        margin_summary = data.get("marginSummary", {})
        result["account_value"] = float(margin_summary.get("accountValue", 0))
        result["margin_used"] = float(margin_summary.get("totalMarginUsed", 0))
        result["withdrawable"] = float(data.get("withdrawable", 0))

        # Available margin = account value - used margin
        result["margin_available"] = result["account_value"] - result["margin_used"]

        # Parse positions
        for pos in data.get("assetPositions", []):
            p = pos.get("position", {})
            if float(p.get("szi", 0)) != 0:
                entry_px = float(p.get("entryPx", 0))
                size = float(p.get("szi", 0))
                unrealized = float(p.get("unrealizedPnl", 0))
                result["unrealized_pnl"] += unrealized
                result["positions"].append({
                    "coin": p.get("coin", "?"),
                    "size": size,
                    "entry_price": entry_px,
                    "unrealized_pnl": unrealized,
                    "leverage": p.get("leverage", {}),
                    "liquidation_px": float(p.get("liquidationPx", 0) or 0),
                    "margin_used": float(p.get("marginUsed", 0)),
                    "position_value": float(p.get("positionValue", 0)),
                })

        logger.info(
            f"Hyperliquid {address[:10]}...: "
            f"value=${result['account_value']:.2f}, "
            f"margin_used=${result['margin_used']:.2f}, "
            f"available=${result['margin_available']:.2f}, "
            f"positions={len(result['positions'])}"
        )

    except Exception as e:
        result["error"] = str(e)
        logger.warning(f"Hyperliquid balance error: {e}")

    return result


def fetch_funding_rate(coin: str = "BTC", api_url: str = HYPERLIQUID_API) -> dict:
    """
    Fetch current and predicted funding rate for a coin.

    Returns:
        current_rate: current hourly funding rate (e.g., 0.0001 = 0.01%/hr)
        predicted_rate: predicted next funding rate
        annualized_pct: annualized rate in percent
        premium: mark vs oracle premium
        open_interest: total open interest
        error: error message or None
    """
    result = {
        "current_rate": 0.0,
        "predicted_rate": 0.0,
        "annualized_pct": 0.0,
        "premium": 0.0,
        "open_interest": 0.0,
        "mark_price": 0.0,
        "oracle_price": 0.0,
        "error": None,
    }

    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.post(
                f"{api_url}/info",
                json={"type": "metaAndAssetCtxs"},
            )
            resp.raise_for_status()
            data = resp.json()

        if isinstance(data, list) and len(data) >= 2:
            meta = data[0]
            ctxs = data[1]
            universe = meta.get("universe", [])
            for i, asset in enumerate(universe):
                if asset.get("name") == coin and i < len(ctxs):
                    ctx = ctxs[i]
                    rate = float(ctx.get("funding", 0))
                    result["current_rate"] = rate
                    result["annualized_pct"] = rate * 24 * 365 * 100
                    result["premium"] = float(ctx.get("premium", 0))
                    result["open_interest"] = float(ctx.get("openInterest", 0))
                    result["mark_price"] = float(ctx.get("markPx", 0))
                    result["oracle_price"] = float(ctx.get("oraclePx", 0))

                    # Predicted = premium (next period rate tracks premium)
                    result["predicted_rate"] = float(ctx.get("premium", 0))
                    break

    except Exception as e:
        result["error"] = str(e)

    return result


# ═══════════════════════════════════════════════════════════
#  Arbitrum Balance (for Hyperliquid deposits)
# ═══════════════════════════════════════════════════════════

def fetch_arbitrum_balance(address: str) -> dict:
    """
    Fetch USDC and ETH balances on Arbitrum One.

    ETH is needed for gas on Arbitrum (to approve + deposit to Hyperliquid bridge).
    """
    result = {
        "usdc_balance": 0.0,
        "usdce_balance": 0.0,
        "total_usdc": 0.0,
        "eth_balance": 0.0,
        "error": None,
    }

    try:
        from web3 import Web3
    except ImportError:
        result["error"] = "web3 not installed"
        return result

    w3 = None
    for rpc_url in ARBITRUM_RPCS:
        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url, request_kwargs={"timeout": 5}))
            if w3.is_connected():
                break
            w3 = None
        except Exception:
            w3 = None
            continue

    if w3 is None:
        result["error"] = "Could not connect to Arbitrum RPC"
        return result

    try:
        checksum = Web3.to_checksum_address(address)

        # ETH balance (gas token on Arbitrum)
        eth_wei = w3.eth.get_balance(checksum)
        result["eth_balance"] = round(eth_wei / 1e18, 6)

        # USDC (native)
        usdc_contract = w3.eth.contract(
            address=Web3.to_checksum_address(ARBITRUM_USDC),
            abi=ERC20_BALANCE_ABI,
        )
        usdc_raw = usdc_contract.functions.balanceOf(checksum).call()
        result["usdc_balance"] = round(usdc_raw / 1e6, 6)

        # USDC.e (bridged)
        usdce_contract = w3.eth.contract(
            address=Web3.to_checksum_address(ARBITRUM_USDCE),
            abi=ERC20_BALANCE_ABI,
        )
        usdce_raw = usdce_contract.functions.balanceOf(checksum).call()
        result["usdce_balance"] = round(usdce_raw / 1e6, 6)

        result["total_usdc"] = round(result["usdc_balance"] + result["usdce_balance"], 6)

        logger.info(
            f"Arbitrum {address[:10]}...: "
            f"USDC=${result['usdc_balance']:.2f}, "
            f"USDC.e=${result['usdce_balance']:.2f}, "
            f"ETH={result['eth_balance']:.6f}"
        )
    except Exception as e:
        result["error"] = str(e)
        logger.warning(f"Arbitrum balance error: {e}")

    return result


# ═══════════════════════════════════════════════════════════
#  Polygon Balance (legacy, for backward compatibility)
# ═══════════════════════════════════════════════════════════

def fetch_balances(address: str) -> dict:
    """
    Fetch USDC and POL balances on Polygon.

    Legacy function kept for backward compatibility.
    For live trading on Hyperliquid, use fetch_hyperliquid_balance() instead.
    """
    result = {
        "usdc_balance": 0.0,
        "usdce_balance": 0.0,
        "total_usdc": 0.0,
        "pol_balance": 0.0,
        "error": None,
    }

    try:
        from web3 import Web3
    except ImportError:
        result["error"] = "web3 not installed"
        return result

    w3 = None
    for rpc_url in POLYGON_RPCS:
        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url, request_kwargs={"timeout": 5}))
            if w3.is_connected():
                break
            w3 = None
        except Exception:
            w3 = None
            continue

    if w3 is None:
        result["error"] = "Could not connect to Polygon RPC"
        return result

    try:
        checksum_addr = Web3.to_checksum_address(address)

        pol_wei = w3.eth.get_balance(checksum_addr)
        result["pol_balance"] = round(pol_wei / 1e18, 6)

        usdc_contract = w3.eth.contract(
            address=Web3.to_checksum_address(POLYGON_USDC),
            abi=ERC20_BALANCE_ABI,
        )
        usdc_raw = usdc_contract.functions.balanceOf(checksum_addr).call()
        result["usdc_balance"] = round(usdc_raw / 1e6, 6)

        usdce_contract = w3.eth.contract(
            address=Web3.to_checksum_address(POLYGON_USDCE),
            abi=ERC20_BALANCE_ABI,
        )
        usdce_raw = usdce_contract.functions.balanceOf(checksum_addr).call()
        result["usdce_balance"] = round(usdce_raw / 1e6, 6)

        result["total_usdc"] = round(result["usdc_balance"] + result["usdce_balance"], 6)

        logger.info(
            f"Polygon {address[:10]}...: "
            f"USDC=${result['usdc_balance']:.2f}, "
            f"USDC.e=${result['usdce_balance']:.2f}, "
            f"POL={result['pol_balance']:.4f}"
        )
    except Exception as e:
        result["error"] = str(e)
        logger.warning(f"Polygon balance error: {e}")

    return result


# ═══════════════════════════════════════════════════════════
#  Unified Multi-Chain Balance
# ═══════════════════════════════════════════════════════════

def fetch_all_balances(address: str, hl_api_url: str = HYPERLIQUID_API) -> dict:
    """
    Fetch balances across all relevant chains.

    Returns a unified view: Hyperliquid (trading), Arbitrum (deposits),
    Polygon (legacy).
    """
    hl = fetch_hyperliquid_balance(address, hl_api_url)
    arb = fetch_arbitrum_balance(address)
    poly = fetch_balances(address)

    return {
        "hyperliquid": hl,
        "arbitrum": arb,
        "polygon": poly,
        "total_available_usd": (
            hl["account_value"]
            + arb["total_usdc"]
            + poly["total_usdc"]
        ),
        "trading_ready": hl["account_value"] > 0,
        "can_deposit": arb["total_usdc"] > 0,
        "needs_gas_arb": arb["eth_balance"] < 0.0005,
        "needs_gas_poly": poly["pol_balance"] < 0.01,
    }
