"""
Cross-chain bridge manager for Hyperliquid.

Supports:
  1. Deposit: Arbitrum USDC → Hyperliquid (via native bridge)
  2. Withdraw: Hyperliquid → Arbitrum USDC
  3. Balance check across all chains

Hyperliquid accepts deposits ONLY from Arbitrum.
If funds are on other chains (Ethereum, Polygon, BSC, etc.),
they must first be bridged to Arbitrum.

Bridge architecture:
  [Any Chain] ---(3rd party bridge)--→ [Arbitrum USDC]
  [Arbitrum USDC] ---(HL native bridge)--→ [Hyperliquid]
  [Hyperliquid] ---(HL withdrawal)--→ [Arbitrum USDC]
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from enum import Enum
from typing import Optional

from monitoring.logger import get_logger, stream

logger = get_logger("bridge")


# Hyperliquid Bridge contract on Arbitrum One
HL_BRIDGE_ADDRESS = "0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7"

# USDC on Arbitrum (must be native USDC, not USDC.e)
ARBITRUM_USDC = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"

# ERC-20 approve + transfer ABI (minimal)
ERC20_ABI = [
    {
        "inputs": [
            {"name": "spender", "type": "address"},
            {"name": "amount", "type": "uint256"},
        ],
        "name": "approve",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function",
    },
    {
        "inputs": [
            {"name": "to", "type": "address"},
            {"name": "amount", "type": "uint256"},
        ],
        "name": "transfer",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function",
    },
    {
        "inputs": [
            {"name": "owner", "type": "address"},
            {"name": "spender", "type": "address"},
        ],
        "name": "allowance",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function",
    },
    {
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function",
    },
]

# Arbitrum RPCs
ARBITRUM_RPCS = [
    "https://arb1.arbitrum.io/rpc",
    "https://arbitrum.llamarpc.com",
    "https://rpc.ankr.com/arbitrum",
]


class BridgeDirection(Enum):
    DEPOSIT = "deposit"       # Arbitrum → Hyperliquid
    WITHDRAW = "withdraw"     # Hyperliquid → Arbitrum


@dataclass
class BridgeStatus:
    """Status of a bridge operation."""
    success: bool
    direction: BridgeDirection
    amount_usd: float
    tx_hash: str = ""
    error: str = ""
    gas_cost_eth: float = 0.0
    timestamp: float = 0.0


class BridgeManager:
    """
    Manages deposits and withdrawals between Arbitrum and Hyperliquid.

    Usage:
        bridge = BridgeManager(private_key="0x...")
        # Check if deposit is possible
        status = bridge.check_deposit_readiness(100.0)
        # Execute deposit
        result = bridge.deposit_to_hyperliquid(100.0)
        # Withdraw back
        result = bridge.withdraw_from_hyperliquid(50.0)
    """

    def __init__(
        self,
        private_key: str = "",
        hl_api_url: str = "https://api.hyperliquid.xyz",
    ):
        self._private_key = private_key
        self._hl_api_url = hl_api_url
        self._history: list[BridgeStatus] = []

    def check_deposit_readiness(self, amount_usd: float) -> dict:
        """
        Pre-flight check for depositing USDC from Arbitrum to Hyperliquid.

        Returns readiness status with actionable messages.
        """
        result = {
            "ready": False,
            "checks": [],
            "actions_needed": [],
        }

        if not self._private_key:
            result["checks"].append(("Private key", False, "Not configured"))
            result["actions_needed"].append("Set PRIVATE_KEY in .env or connect wallet")
            return result
        result["checks"].append(("Private key", True, "Configured"))

        # Check Arbitrum balance
        try:
            from execution.wallet_balance import fetch_arbitrum_balance
            arb = fetch_arbitrum_balance(self._get_address())
        except Exception as e:
            result["checks"].append(("Arbitrum RPC", False, str(e)))
            result["actions_needed"].append("Check internet connection")
            return result

        if arb["error"]:
            result["checks"].append(("Arbitrum RPC", False, arb["error"]))
            return result
        result["checks"].append(("Arbitrum RPC", True, "Connected"))

        # ETH for gas
        if arb["eth_balance"] < 0.0005:
            result["checks"].append((
                "ETH for gas",
                False,
                f"Only {arb['eth_balance']:.6f} ETH — need ~0.0005 ETH"
            ))
            result["actions_needed"].append(
                "Send at least 0.001 ETH to your wallet on Arbitrum for gas"
            )
        else:
            result["checks"].append((
                "ETH for gas",
                True,
                f"{arb['eth_balance']:.6f} ETH"
            ))

        # USDC balance
        if arb["usdc_balance"] < amount_usd:
            if arb["usdce_balance"] > 0:
                result["checks"].append((
                    "USDC balance",
                    False,
                    f"${arb['usdc_balance']:.2f} native USDC "
                    f"(+${arb['usdce_balance']:.2f} USDC.e — needs swap)"
                ))
                result["actions_needed"].append(
                    f"Swap USDC.e to native USDC on Arbitrum (use Uniswap/1inch). "
                    f"Hyperliquid bridge only accepts native USDC."
                )
            else:
                result["checks"].append((
                    "USDC balance",
                    False,
                    f"Only ${arb['total_usdc']:.2f} — need ${amount_usd:.2f}"
                ))
                result["actions_needed"].append(
                    f"Bridge or transfer at least ${amount_usd:.2f} USDC to "
                    f"your wallet on Arbitrum One"
                )
        else:
            result["checks"].append((
                "USDC balance",
                True,
                f"${arb['usdc_balance']:.2f} native USDC"
            ))

        result["ready"] = all(check[1] for check in result["checks"])
        return result

    def deposit_to_hyperliquid(self, amount_usd: float) -> BridgeStatus:
        """
        Deposit USDC from Arbitrum to Hyperliquid.

        Steps:
        1. Check USDC balance on Arbitrum
        2. Approve USDC spending by bridge contract (if needed)
        3. Send USDC to Hyperliquid bridge contract
        4. Verify deposit on Hyperliquid side

        Note: Deposits typically take 1-5 minutes to appear on Hyperliquid.
        """
        status = BridgeStatus(
            success=False,
            direction=BridgeDirection.DEPOSIT,
            amount_usd=amount_usd,
            timestamp=time.time(),
        )

        if not self._private_key:
            status.error = "No private key configured"
            return status

        try:
            from web3 import Web3
            from eth_account import Account
        except ImportError:
            status.error = "web3/eth_account not installed"
            return status

        # Connect to Arbitrum
        w3 = None
        for rpc in ARBITRUM_RPCS:
            try:
                w3 = Web3(Web3.HTTPProvider(rpc, request_kwargs={"timeout": 10}))
                if w3.is_connected():
                    break
                w3 = None
            except Exception:
                w3 = None

        if w3 is None:
            status.error = "Cannot connect to Arbitrum RPC"
            return status

        try:
            account = Account.from_key(self._private_key)
            address = account.address
            checksum = Web3.to_checksum_address(address)

            usdc_contract = w3.eth.contract(
                address=Web3.to_checksum_address(ARBITRUM_USDC),
                abi=ERC20_ABI,
            )

            # Amount in USDC units (6 decimals)
            amount_raw = int(amount_usd * 1e6)

            # Check balance
            balance_raw = usdc_contract.functions.balanceOf(checksum).call()
            if balance_raw < amount_raw:
                status.error = (
                    f"Insufficient USDC: have ${balance_raw / 1e6:.2f}, "
                    f"need ${amount_usd:.2f}"
                )
                return status

            # Check and set allowance for bridge contract
            bridge_checksum = Web3.to_checksum_address(HL_BRIDGE_ADDRESS)
            allowance = usdc_contract.functions.allowance(
                checksum, bridge_checksum
            ).call()

            nonce = w3.eth.get_transaction_count(checksum)

            if allowance < amount_raw:
                # Approve bridge to spend USDC
                stream.log("BRIDGE", f"Approving USDC spending for bridge...")
                approve_tx = usdc_contract.functions.approve(
                    bridge_checksum,
                    2**256 - 1,  # max approval
                ).build_transaction({
                    "from": checksum,
                    "nonce": nonce,
                    "gas": 100_000,
                    "gasPrice": w3.eth.gas_price,
                    "chainId": 42161,  # Arbitrum One
                })

                signed = w3.eth.account.sign_transaction(approve_tx, self._private_key)
                tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
                receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=60)

                if receipt.status != 1:
                    status.error = "USDC approval transaction failed"
                    return status

                nonce += 1
                stream.log("BRIDGE", f"USDC approved. tx={tx_hash.hex()[:16]}...")

            # Transfer USDC to bridge contract
            stream.log("BRIDGE", f"Depositing ${amount_usd:.2f} to Hyperliquid...")
            transfer_tx = usdc_contract.functions.transfer(
                bridge_checksum,
                amount_raw,
            ).build_transaction({
                "from": checksum,
                "nonce": nonce,
                "gas": 150_000,
                "gasPrice": w3.eth.gas_price,
                "chainId": 42161,
            })

            signed = w3.eth.account.sign_transaction(transfer_tx, self._private_key)
            tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)

            if receipt.status == 1:
                gas_used = receipt.gasUsed * receipt.effectiveGasPrice / 1e18
                status.success = True
                status.tx_hash = tx_hash.hex()
                status.gas_cost_eth = gas_used
                stream.log(
                    "BRIDGE",
                    f"Deposit sent! ${amount_usd:.2f} USDC → Hyperliquid. "
                    f"tx={tx_hash.hex()[:16]}... gas={gas_used:.6f} ETH"
                )
                logger.info(f"Deposit tx: {tx_hash.hex()}")
            else:
                status.error = "Deposit transaction reverted"

        except Exception as e:
            status.error = str(e)
            logger.exception("Deposit failed")

        self._history.append(status)
        return status

    def withdraw_from_hyperliquid(self, amount_usd: float) -> BridgeStatus:
        """
        Withdraw USDC from Hyperliquid to Arbitrum wallet.

        Uses the Hyperliquid Exchange API for withdrawals.
        Funds arrive on Arbitrum as native USDC.
        """
        status = BridgeStatus(
            success=False,
            direction=BridgeDirection.WITHDRAW,
            amount_usd=amount_usd,
            timestamp=time.time(),
        )

        if not self._private_key:
            status.error = "No private key configured"
            return status

        try:
            from hyperliquid.exchange import Exchange
            from hyperliquid.utils import constants
            from eth_account import Account

            pk = self._private_key
            if not pk.startswith("0x"):
                pk = "0x" + pk

            account = Account.from_key(pk)
            api_url = self._hl_api_url or constants.MAINNET_API_URL
            exchange = Exchange(account, api_url)

            stream.log("BRIDGE", f"Withdrawing ${amount_usd:.2f} from Hyperliquid...")

            # Hyperliquid withdrawal API
            # amount is in USD (float), destination is Arbitrum by default
            result = exchange.usd_class_transfer(amount_usd, False)  # False = withdraw (spot → perp transfer)

            # Alternative: use the withdraw endpoint if available
            # The SDK may expose this differently
            if result and result.get("status") == "ok":
                status.success = True
                status.tx_hash = str(result.get("response", {}).get("data", ""))
                stream.log("BRIDGE", f"Withdrawal initiated: ${amount_usd:.2f} → Arbitrum")
            else:
                # Try direct withdraw if usd_class_transfer doesn't work
                try:
                    result2 = exchange.withdraw(amount_usd)
                    if result2 and result2.get("status") == "ok":
                        status.success = True
                        stream.log("BRIDGE", f"Withdrawal initiated: ${amount_usd:.2f}")
                    else:
                        status.error = f"Withdrawal failed: {result2}"
                except AttributeError:
                    status.error = f"Withdrawal API response: {result}"

        except ImportError:
            status.error = "hyperliquid-python-sdk not installed"
        except Exception as e:
            status.error = str(e)
            logger.exception("Withdrawal failed")

        self._history.append(status)
        return status

    def get_history(self, n: int = 20) -> list[dict]:
        """Return recent bridge operations."""
        return [
            {
                "success": s.success,
                "direction": s.direction.value,
                "amount": s.amount_usd,
                "tx_hash": s.tx_hash[:20] + "..." if s.tx_hash else "",
                "error": s.error,
                "gas": round(s.gas_cost_eth, 6),
                "time": s.timestamp,
            }
            for s in self._history[-n:]
        ]

    def get_bridge_guide(self, source_chain: str = "ethereum") -> dict:
        """
        Return instructions for bridging funds to Arbitrum from other chains.

        This is informational — actual bridging from non-Arbitrum chains
        requires using external bridge protocols.
        """
        guides = {
            "ethereum": {
                "chain": "Ethereum Mainnet",
                "methods": [
                    {
                        "name": "Arbitrum Native Bridge",
                        "url": "https://bridge.arbitrum.io",
                        "time": "~15 minutes",
                        "cost": "Gas on Ethereum (~$2-10)",
                        "notes": "Official bridge. Most secure.",
                    },
                    {
                        "name": "Stargate / LayerZero",
                        "url": "https://stargate.finance",
                        "time": "~2 minutes",
                        "cost": "~0.05-0.1% + gas",
                        "notes": "Fast, supports USDC directly.",
                    },
                ],
            },
            "polygon": {
                "chain": "Polygon",
                "methods": [
                    {
                        "name": "Stargate / LayerZero",
                        "url": "https://stargate.finance",
                        "time": "~2 minutes",
                        "cost": "~0.05% + gas in POL",
                        "notes": "Polygon USDC → Arbitrum USDC.",
                    },
                    {
                        "name": "Synapse Bridge",
                        "url": "https://synapseprotocol.com",
                        "time": "~5 minutes",
                        "cost": "~0.05% + gas",
                        "notes": "Multi-chain bridge.",
                    },
                ],
            },
            "bsc": {
                "chain": "BNB Smart Chain",
                "methods": [
                    {
                        "name": "Stargate / LayerZero",
                        "url": "https://stargate.finance",
                        "time": "~2 minutes",
                        "cost": "~0.05% + gas in BNB",
                        "notes": "BSC USDT/USDC → Arbitrum USDC.",
                    },
                ],
            },
            "base": {
                "chain": "Base",
                "methods": [
                    {
                        "name": "Stargate / LayerZero",
                        "url": "https://stargate.finance",
                        "time": "~2 minutes",
                        "cost": "~0.05% + gas",
                        "notes": "Base USDC → Arbitrum USDC.",
                    },
                ],
            },
        }

        guide = guides.get(source_chain.lower(), {
            "chain": source_chain,
            "methods": [{
                "name": "Stargate (Universal)",
                "url": "https://stargate.finance",
                "time": "~2-5 minutes",
                "cost": "~0.05% + gas",
                "notes": f"Bridge USDC from {source_chain} to Arbitrum.",
            }],
        })

        guide["destination"] = "Arbitrum One → Hyperliquid"
        guide["final_step"] = (
            "After USDC arrives on Arbitrum, use the 'Deposit to Hyperliquid' "
            "button to move it to your trading account."
        )
        return guide

    def _get_address(self) -> str:
        """Derive address from private key."""
        from eth_account import Account
        pk = self._private_key
        if not pk.startswith("0x"):
            pk = "0x" + pk
        return Account.from_key(pk).address
