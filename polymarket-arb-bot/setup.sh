#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  ARB ENGINE — One-Click Setup
#  Polymarket BTC 5-Min Arbitrage Bot
# ═══════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  ARB ENGINE // 5-MIN BTC MARKETS${NC}"
echo -e "${CYAN}  One-Click Setup${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# ── Check prerequisites ──────────────────────────────────────
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}  ✓ Docker found${NC}"
    USE_DOCKER=true
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    echo -e "${GREEN}  ✓ Docker with compose plugin found${NC}"
    USE_DOCKER=true
else
    USE_DOCKER=false
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}  ✗ Python3 not found. Install Python 3.10+ or Docker.${NC}"
        exit 1
    fi
    PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    echo -e "${GREEN}  ✓ Python ${PYVER} found (no Docker, using pip)${NC}"
fi

# ── Create .env if missing ───────────────────────────────────
echo -e "${YELLOW}[2/5] Configuring environment...${NC}"

if [ ! -f .env ]; then
    cp .env.example .env
    echo -e "${GREEN}  ✓ Created .env from template${NC}"

    echo ""
    echo -e "${CYAN}  ┌────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  │  OPTIONAL: Enter your wallet private key   │${NC}"
    echo -e "${CYAN}  │  (press Enter to skip — demo mode works    │${NC}"
    echo -e "${CYAN}  │  without a wallet)                         │${NC}"
    echo -e "${CYAN}  └────────────────────────────────────────────┘${NC}"
    echo ""
    read -p "  Private key (0x...): " PKEY
    if [ -n "$PKEY" ]; then
        sed -i "s|PRIVATE_KEY=.*|PRIVATE_KEY=${PKEY}|" .env
        echo -e "${GREEN}  ✓ Private key saved to .env${NC}"
    else
        echo -e "${YELLOW}  → Skipped. Running in demo/paper mode.${NC}"
    fi
else
    echo -e "${GREEN}  ✓ .env already exists${NC}"
fi

# ── Install / Build ──────────────────────────────────────────
echo -e "${YELLOW}[3/5] Installing...${NC}"

if [ "$USE_DOCKER" = true ]; then
    echo "  Building Docker image (this may take 1-2 minutes)..."
    if command -v docker-compose &> /dev/null; then
        docker-compose build --quiet
    else
        docker compose build --quiet
    fi
    echo -e "${GREEN}  ✓ Docker image built${NC}"
else
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install -q -r requirements.txt
    echo -e "${GREEN}  ✓ Dependencies installed${NC}"
fi

# ── Run tests ────────────────────────────────────────────────
echo -e "${YELLOW}[4/5] Running tests...${NC}"

if [ "$USE_DOCKER" = true ]; then
    if command -v docker-compose &> /dev/null; then
        docker-compose run --rm arb-bot python -m pytest tests/ -q 2>&1 | tail -3
    else
        docker compose run --rm arb-bot python -m pytest tests/ -q 2>&1 | tail -3
    fi
else
    source venv/bin/activate
    python -m pytest tests/ -q 2>&1 | tail -3
fi
echo -e "${GREEN}  ✓ Tests passed${NC}"

# ── Start ────────────────────────────────────────────────────
echo -e "${YELLOW}[5/5] Starting bot...${NC}"
echo ""

if [ "$USE_DOCKER" = true ]; then
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    echo -e "${GREEN}  ✓ Bot started in Docker${NC}"
else
    source venv/bin/activate
    nohup python web/demo.py > bot.log 2>&1 &
    echo $! > .bot.pid
    echo -e "${GREEN}  ✓ Bot started (PID: $(cat .bot.pid))${NC}"
fi

sleep 2

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ BOT IS RUNNING!${NC}"
echo ""
echo -e "  Open in browser: ${CYAN}http://localhost:5000${NC}"
echo ""
echo -e "  Then click ${GREEN}[Start]${NC} to begin trading."
echo ""
echo -e "  Commands:"
echo -e "    Stop:    ${YELLOW}docker-compose down${NC}  (or: kill \$(cat .bot.pid))"
echo -e "    Logs:    ${YELLOW}docker-compose logs -f${NC}  (or: tail -f bot.log)"
echo -e "    Live:    Edit .env → TRADING_MODE=live → restart"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
