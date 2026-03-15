"""
Fetch real USDC and POL (MATIC) balances from Polygon mainnet.

Uses public Polygon RPC endpoints. USDC on Polygon is at:
  0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359 (native USDC)
  0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 (bridged USDC.e)
"""

from __future__ import annotations

import logging
from typing import Optional

logger = logging.getLogger("wallet_balance")

# USDC contract on Polygon (native Circle USDC)
USDC_ADDRESS = "0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359"
# Bridged USDC.e on Polygon
USDCE_ADDRESS = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"

# ERC-20 balanceOf(address) ABI
ERC20_BALANCE_ABI = [
    {
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function",
    }
]

# Public Polygon RPC endpoints (fallback chain)
POLYGON_RPCS = [
    "https://polygon-rpc.com",
    "https://rpc-mainnet.matic.quiknode.pro",
    "https://polygon.llamarpc.com",
    "https://rpc.ankr.com/polygon",
]


def fetch_balances(address: str) -> dict:
    """
    Fetch USDC and POL/MATIC balances for an address on Polygon.

    Returns dict with:
        usdc_balance: float (in dollars, 6 decimals)
        usdce_balance: float (bridged USDC.e, 6 decimals)
        total_usdc: float (sum of both)
        pol_balance: float (native POL/MATIC, 18 decimals)
        error: str | None
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

    # Try each RPC endpoint
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

        # Fetch POL/MATIC balance (native token)
        pol_wei = w3.eth.get_balance(checksum_addr)
        result["pol_balance"] = round(pol_wei / 1e18, 6)

        # Fetch USDC (native) balance
        usdc_contract = w3.eth.contract(
            address=Web3.to_checksum_address(USDC_ADDRESS),
            abi=ERC20_BALANCE_ABI,
        )
        usdc_raw = usdc_contract.functions.balanceOf(checksum_addr).call()
        result["usdc_balance"] = round(usdc_raw / 1e6, 6)

        # Fetch USDC.e (bridged) balance
        usdce_contract = w3.eth.contract(
            address=Web3.to_checksum_address(USDCE_ADDRESS),
            abi=ERC20_BALANCE_ABI,
        )
        usdce_raw = usdce_contract.functions.balanceOf(checksum_addr).call()
        result["usdce_balance"] = round(usdce_raw / 1e6, 6)

        result["total_usdc"] = round(result["usdc_balance"] + result["usdce_balance"], 6)

        logger.info(
            f"Balances for {address[:10]}...: "
            f"USDC=${result['usdc_balance']:.2f}, "
            f"USDC.e=${result['usdce_balance']:.2f}, "
            f"POL={result['pol_balance']:.4f}"
        )
    except Exception as e:
        result["error"] = str(e)
        logger.warning(f"Balance fetch error: {e}")

    return result
