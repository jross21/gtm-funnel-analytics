"""Small deterministic helpers: formatting + seeded random draws.

All randomness flows through a single numpy Generator so the output is reproducible
given a fixed call order. Values are stringified at generation time (fixed precision,
ISO timestamps) so the written CSVs are byte-identical across runs and machines.
"""

from __future__ import annotations

import math
from datetime import date, datetime, timedelta


def fmt_date(d: date | None) -> str:
    return "" if d is None else d.strftime("%Y-%m-%d")


def fmt_ts(dt: datetime | None) -> str:
    return "" if dt is None else dt.strftime("%Y-%m-%d %H:%M:%S")


def fmt_amount(x: float | None) -> str:
    return "" if x is None else f"{x:.2f}"


def fmt_bool(b: bool) -> str:
    return "true" if b else "false"


def lognormal_days(rng, median: float, sigma: float) -> float:
    """Right-skewed positive duration whose median is `median` days."""
    return float(median) * math.exp(sigma * rng.standard_normal())


def lognormal_amount(rng, median: float, sigma: float) -> float:
    return float(median) * math.exp(sigma * rng.standard_normal())


def weighted_choice(rng, mapping: dict[str, float]) -> str:
    keys = list(mapping.keys())
    weights = [mapping[k] for k in keys]
    total = sum(weights)
    probs = [w / total for w in weights]
    idx = rng.choice(len(keys), p=probs)
    return keys[int(idx)]


def random_datetime_between(rng, start: date, end: date) -> datetime:
    """Uniform datetime within [start, end), to the second."""
    start_dt = datetime(start.year, start.month, start.day)
    end_dt = datetime(end.year, end.month, end.day)
    span_seconds = int((end_dt - start_dt).total_seconds())
    offset = int(rng.integers(0, max(span_seconds, 1)))
    return start_dt + timedelta(seconds=offset)


def add_days(dt: datetime, days: float) -> datetime:
    return dt + timedelta(seconds=int(days * 86400))


def pad_id(prefix: str, n: int, width: int = 5) -> str:
    return f"{prefix}-{n:0{width}d}"
