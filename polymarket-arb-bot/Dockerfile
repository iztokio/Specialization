FROM python:3.11-slim

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libffi-dev && \
    rm -rf /var/lib/apt/lists/*

# Python deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code
COPY . .

# Expose web dashboard
EXPOSE 5000

# Default: demo mode (simulated data, safe to run)
ENV TRADING_MODE=paper
ENV INITIAL_BANKROLL=2050

CMD ["python", "web/demo.py"]
