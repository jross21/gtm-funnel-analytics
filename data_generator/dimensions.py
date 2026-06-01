"""Independent dimensions: reps (users), accounts, and the segment-label crosswalk."""

from __future__ import annotations

from datetime import datetime

from . import config as C
from .util import fmt_bool, fmt_date, fmt_ts, pad_id, random_datetime_between

# Fixed rep allocation across role x segment (sums to N_USERS = 40).
_REP_PLAN = (
    [("SDR", "SMB")] * 12 + [("SDR", "Mid-Market")] * 7 + [("SDR", "Enterprise")] * 3
    + [("AE", "SMB")] * 7 + [("AE", "Mid-Market")] * 5 + [("AE", "Enterprise")] * 2
    + [("AM", "Mid-Market")] * 2 + [("AM", "Enterprise")] * 2
)

_SYNC_USERS = datetime(2026, 4, 1, 5, 30, 0)
_SYNC_ACCOUNTS = datetime(2026, 4, 1, 5, 30, 0)


def build_users(rng, faker) -> list[dict]:
    """40 reps with role, segment coverage, timezone. A few are inactive (orphan-owner defect)."""
    inactive_idx = set(int(i) for i in rng.choice(C.N_USERS, size=3, replace=False))
    users = []
    for i, (role, segment) in enumerate(_REP_PLAN, start=1):
        name = faker.name()
        users.append({
            "user_id": pad_id("USR", i, 4),
            "full_name": name,
            "email": _employee_email(name),
            "role": role,
            "segment_raw": rng.choice(C.SEGMENT_LABEL_VARIANTS[segment]),
            "_segment_canonical": segment,           # internal helper, not written
            "timezone": rng.choice(C.REP_TIMEZONES),
            "is_active": fmt_bool((i - 1) not in inactive_idx),
            "_is_active_bool": (i - 1) not in inactive_idx,
            "_synced_at": fmt_ts(_SYNC_USERS),
        })
    return users


def build_accounts(rng, faker) -> list[dict]:
    """Companies with a canonical segment, a messy raw label, and an employee count
    that staging can fall back on when the raw label is blank."""
    accounts = []
    for i in range(1, C.N_ACCOUNTS + 1):
        segment = _weighted_segment(rng)
        accounts.append({
            "account_id": pad_id("ACC", i),
            "account_name": faker.company(),
            "segment_raw": rng.choice(C.SEGMENT_LABEL_VARIANTS[segment]),
            "_segment_canonical": segment,
            "industry": rng.choice(C.INDUSTRIES),
            "country": rng.choice(C.COUNTRIES),
            "employee_count": _employee_count(rng, segment),
            "created_date": fmt_date(random_datetime_between(
                rng, _account_start(), C.WINDOW_END).date()),
            "is_test": fmt_bool(False),
            "_synced_at": fmt_ts(_SYNC_ACCOUNTS),
        })
    return accounts


def build_segment_map() -> list[dict]:
    """Crosswalk resolving every messy raw label to its canonical segment."""
    rows = []
    for canonical, variants in C.SEGMENT_LABEL_VARIANTS.items():
        for raw in variants:
            rows.append({"segment_raw": raw, "segment_canonical": canonical})
    return rows


# --- helpers ---------------------------------------------------------------

def _weighted_segment(rng) -> str:
    keys = list(C.SEGMENT_WEIGHTS.keys())
    probs = [C.SEGMENT_WEIGHTS[k] for k in keys]
    return keys[int(rng.choice(len(keys), p=probs))]


def _employee_count(rng, segment: str) -> int:
    if segment == "SMB":
        return int(rng.integers(10, 200))
    if segment == "Mid-Market":
        return int(rng.integers(200, 2000))
    return int(rng.integers(2000, 50000))


def _employee_email(name: str) -> str:
    handle = name.lower().replace(".", "").replace("'", "").replace(" ", ".")
    return f"{handle}@arcline.com"


def _account_start():
    # Accounts can pre-date the funnel window (existing customers, renewal base).
    from datetime import date
    return date(2024, 1, 1)
