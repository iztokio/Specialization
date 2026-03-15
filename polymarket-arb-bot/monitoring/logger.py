"""Structured logging with training stream output."""

from __future__ import annotations

import logging
import sys
import time
from collections import deque
from dataclasses import dataclass
from typing import ClassVar


@dataclass
class TradeLog:
    """Single entry in the training stream."""

    timestamp: float
    tag: str  # SPREAD, KELLY, BAYES, EV, FILL, FILTER, SCAN, STOIKOV, HEDGE, LMSR
    message: str
    values: dict | None = None


class TrainingStream:
    """In-memory ring buffer of structured trade logs (like the bot's console)."""

    _instance: ClassVar[TrainingStream | None] = None
    _entries: deque[TradeLog]

    def __init__(self, maxlen: int = 500):
        self._entries = deque(maxlen=maxlen)

    @classmethod
    def get(cls) -> TrainingStream:
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def log(self, tag: str, message: str, **values):
        entry = TradeLog(
            timestamp=time.time(),
            tag=tag.upper(),
            message=message,
            values=values if values else None,
        )
        self._entries.append(entry)
        # Also emit to standard logger
        logger = logging.getLogger(f"stream.{tag}")
        val_str = " ".join(f"{k}={v}" for k, v in values.items()) if values else ""
        logger.info(f"[{tag.upper()}] {message} {val_str}".strip())

    @property
    def recent(self) -> list[TradeLog]:
        return list(self._entries)

    def last(self, n: int = 20) -> list[TradeLog]:
        return list(self._entries)[-n:]


def get_logger(name: str) -> logging.Logger:
    """Get a named logger with standard formatting."""
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(
            logging.Formatter(
                "%(asctime)s.%(msecs)03d [%(name)-12s] %(levelname)-5s %(message)s",
                datefmt="%H:%M:%S",
            )
        )
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger


# Convenience
stream = TrainingStream.get()
