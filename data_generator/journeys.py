"""The coupled lead -> opportunity journey.

A single per-contact simulation is the one source of truth; every raw table is
derived from it so the data is internally consistent:

  contact -> lead_score_history -> (canonical MQL @>=50, HubSpot MQL @>=40)
          -> lifecycle_history (SAL/SQL/Opportunity, score- and time-gated)
          -> opportunity (+ opportunity_stage_history)  [if it reaches Opportunity]
          -> first rep activity (speed-to-lead, stored in rep-LOCAL time)
          -> id crosswalk (hs_contact_id <-> sf_lead_id)

Renewal/expansion opps are generated separately (no funnel lineage) so the naive
"Sales" pipeline number can wrongly include them.
"""

from __future__ import annotations

from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from . import config as C
from .util import (
    add_days, fmt_amount, fmt_bool, fmt_date, fmt_ts, lognormal_amount,
    lognormal_days, pad_id, random_datetime_between, weighted_choice,
)

# Lead-source mix (canonical), skewed toward inbound/outbound.
_SOURCE_WEIGHTS = {
    "Inbound": 0.30, "Outbound": 0.26, "Content": 0.13, "Event": 0.10,
    "Paid": 0.09, "Partner": 0.07, "Referral": 0.05,
}
_SYNC = {
    "contacts": datetime(2026, 4, 1, 6, 30, 0),
    "score": datetime(2026, 4, 1, 6, 30, 0),
    "lifecycle": datetime(2026, 4, 1, 6, 30, 0),
    "events": datetime(2026, 4, 1, 6, 45, 0),
    "opps": datetime(2026, 4, 1, 5, 30, 0),
    "stage_hist": datetime(2026, 4, 1, 5, 30, 0),
    "activities": datetime(2026, 4, 1, 7, 0, 0),
}


def build_journeys(rng, faker, users, accounts):
    """Return a dict of row-lists for every funnel-derived raw table."""
    owners = _index_owners(users)
    accounts_by_segment = _index_accounts(accounts)
    anchor_dt = datetime(C.ANCHOR_DATE.year, C.ANCHOR_DATE.month, C.ANCHOR_DATE.day)

    out = {
        "contacts": [], "lead_score_history": [], "lifecycle_history": [],
        "marketing_events": [], "opportunities": [], "opportunity_stage_history": [],
        "activities": [], "id_crosswalk": [],
    }
    score_seq = [0]
    event_seq = [0]
    hist_seq = [0]
    act_seq = [0]
    opp_seq = [0]

    for i in range(1, C.N_CONTACTS + 1):
        hs_id = pad_id("HS", i, 6)
        sf_lead_id = pad_id("LEAD", i, 6)
        segment = _weighted_segment(rng)
        account = accounts_by_segment[segment][int(rng.integers(0, len(accounts_by_segment[segment])))]
        source = weighted_choice(rng, _SOURCE_WEIGHTS)
        source_raw = rng.choice(C.LEAD_SOURCE_VARIANTS[source])

        # MQL status is score-driven.
        is_canon_mql = rng.random() < C.MQL_RATE[segment]
        is_hs_only = (not is_canon_mql) and (rng.random() < C.HUBSPOT_ONLY_MQL_RATE)

        if is_canon_mql:
            canon_mql_dt = random_datetime_between(rng, C.WINDOW_START, C.WINDOW_END)
            hs_mql_dt = add_days(canon_mql_dt, -float(rng.uniform(0, 3)))
            created_dt = add_days(hs_mql_dt, -lognormal_days(rng, C.DUR_NEW_MQL[segment], C.DURATION_SIGMA))
            peak_score = int(rng.integers(50, 91))
        elif is_hs_only:
            hs_mql_dt = random_datetime_between(rng, C.WINDOW_START, C.WINDOW_END)
            canon_mql_dt = None
            created_dt = add_days(hs_mql_dt, -lognormal_days(rng, C.DUR_NEW_MQL[segment], C.DURATION_SIGMA))
            peak_score = int(rng.integers(40, 50))
        else:
            hs_mql_dt = canon_mql_dt = None
            created_dt = random_datetime_between(rng, C.WINDOW_START, C.WINDOW_END)
            peak_score = int(rng.integers(5, 40))

        out["contacts"].append({
            "hs_contact_id": hs_id,
            "email": _contact_email(faker, i),
            "account_name_freetext": account["account_name"],
            "lifecycle_stage_hs": _hs_lifecycle_label(is_canon_mql, is_hs_only),
            "hs_lead_score": peak_score,
            "lead_source_hs": source_raw,
            "segment_raw_hs": rng.choice(C.SEGMENT_LABEL_VARIANTS[segment]),
            "country": account["country"],
            "created_at": fmt_ts(created_dt),
            "is_internal": fmt_bool(False),
            "_synced_at": fmt_ts(_SYNC["contacts"]),
            # internal helpers (not written)
            "_segment": segment, "_account_id": account["account_id"],
            "_sf_lead_id": sf_lead_id, "_source": source,
        })

        _emit_score_history(out, score_seq, hs_id, created_dt, hs_mql_dt, canon_mql_dt, peak_score, is_canon_mql, is_hs_only, rng)
        _emit_marketing_events(out, event_seq, hs_id, created_dt, hs_mql_dt or created_dt, rng)
        out["id_crosswalk"].append({
            "hs_contact_id": hs_id, "sf_lead_id": sf_lead_id, "match_confidence": "high",
        })

        # Lifecycle: New for everyone; MQL for HS-MQLs (at the HS date).
        out["lifecycle_history"].append(_lc_row(hs_id, "New", created_dt))
        if hs_mql_dt is not None:
            out["lifecycle_history"].append(_lc_row(hs_id, "MQL", hs_mql_dt))

        if not is_canon_mql:
            continue  # only canonical MQLs are worked by sales

        # Speed-to-lead activity for every canonical MQL (SLA denominator).
        _emit_first_activity(out, act_seq, sf_lead_id, segment, canon_mql_dt, owners, rng)

        # Sales progression, score- and time-gated. A stage whose date falls after the
        # anchor "today" simply hasn't happened yet (the lead is still in flight), so we
        # stop the journey there — this keeps recent cohorts realistically immature.
        if rng.random() >= C.CONV_MQL_SAL[segment]:
            continue
        sal_dt = add_days(canon_mql_dt, lognormal_days(rng, C.DUR_MQL_SAL[segment], C.DURATION_SIGMA))
        if sal_dt > anchor_dt:
            continue
        out["lifecycle_history"].append(_lc_row(hs_id, "SAL", sal_dt))
        if rng.random() >= C.CONV_SAL_SQL[segment]:
            continue
        sql_dt = add_days(sal_dt, lognormal_days(rng, C.DUR_SAL_SQL[segment], C.DURATION_SIGMA))
        if sql_dt > anchor_dt:
            continue
        out["lifecycle_history"].append(_lc_row(hs_id, "SQL", sql_dt))
        if rng.random() >= C.CONV_SQL_OPP[segment]:
            continue
        opp_dt = add_days(sql_dt, lognormal_days(rng, C.DUR_SQL_OPP[segment], C.DURATION_SIGMA))
        if opp_dt > anchor_dt:
            continue
        out["lifecycle_history"].append(_lc_row(hs_id, "Opportunity", opp_dt))

        _emit_opportunity(out, opp_seq, hist_seq, account, segment, source, opp_dt,
                          owners, rng, hs_id, sf_lead_id, is_renewal=False)

    _emit_renewals(out, opp_seq, hist_seq, accounts, owners, rng)
    return out


# --- opportunity emission --------------------------------------------------

def _emit_opportunity(out, opp_seq, hist_seq, account, segment, source, opp_dt,
                      owners, rng, hs_id, sf_lead_id, is_renewal, opp_type=None):
    opp_seq[0] += 1
    opp_id = pad_id("OPP", opp_seq[0])
    type_label = opp_type or ("Renewal" if is_renewal else C.OPP_TYPES_NEW)
    owner = _pick_owner(owners, "AM" if is_renewal else "AE", segment, rng)
    amount = round(lognormal_amount(rng, C.ACV_MEDIAN[segment], C.ACV_SIGMA), 2)

    cycle_days = lognormal_days(rng, C.DUR_OPP_CLOSE[segment], C.DURATION_SIGMA)
    close_dt = add_days(opp_dt, cycle_days)
    anchor_dt = datetime(C.ANCHOR_DATE.year, C.ANCHOR_DATE.month, C.ANCHOR_DATE.day)
    is_closed = close_dt <= anchor_dt
    if is_closed:
        is_won = rng.random() < C.WIN_RATE[segment]
        final_stage = 5 if is_won else 6
    else:
        is_won = False
        close_dt = None
        # current open stage by how far through a typical cycle we are
        elapsed_frac = (anchor_dt - opp_dt).total_seconds() / (cycle_days * 86400)
        final_stage = min(4, max(1, int(elapsed_frac * 4) + 1))

    out["opportunities"].append({
        "opp_id": opp_id,
        "account_id": account["account_id"],
        "owner_id": owner["user_id"],
        # CRM-style opp number keeps real opps' business key unique; an injected
        # duplicate (exact copy) shares it, so staging can dedupe cleanly.
        "opp_name": f"{account['account_name']} - {type_label} #{opp_seq[0]:05d}",
        "opp_stage": C.OPP_SALES_STAGES[final_stage],
        "opp_stage_num": final_stage,
        "opp_amount": fmt_amount(amount),
        "currency": "USD",
        "opp_type": type_label,
        "lead_source": ("" if is_renewal else source),
        "is_partner_sourced": fmt_bool((not is_renewal) and source == "Partner"),
        "created_date": fmt_date(opp_dt.date()),
        "close_date": fmt_date(close_dt.date()) if close_dt else "",
        "is_won": fmt_bool(is_won),
        "is_closed": fmt_bool(is_closed),
        "is_test": fmt_bool(False),
        "source_hs_contact_id": ("" if is_renewal else hs_id),
        "source_sf_lead_id": ("" if is_renewal else sf_lead_id),
        "_synced_at": fmt_ts(_SYNC["opps"]),
        "_amount": amount, "_segment": segment,
    })
    _emit_stage_history(out, hist_seq, opp_id, owner["user_id"], opp_dt, close_dt, anchor_dt, final_stage, rng)


def _emit_stage_history(out, hist_seq, opp_id, owner_id, opp_dt, close_dt, anchor_dt, final_stage, rng):
    """Transitions 1 -> ... -> final_stage spread across the opp's life."""
    end_dt = close_dt if close_dt else anchor_dt
    # stages entered, in order: 1..min(final,4) then maybe 5/6 (closed)
    open_path = list(range(1, min(final_stage, 4) + 1))
    fracs = sorted(float(f) for f in rng.uniform(0.0, 1.0, size=len(open_path)))
    span = (end_dt - opp_dt).total_seconds()
    prev_stage = 0
    for k, stage in enumerate(open_path):
        changed = opp_dt if k == 0 else add_days(opp_dt, (span * fracs[k]) / 86400.0)
        _append_history(out, hist_seq, opp_id, prev_stage, stage, changed, owner_id)
        prev_stage = stage
    if final_stage in (5, 6) and close_dt is not None:
        _append_history(out, hist_seq, opp_id, prev_stage, final_stage, close_dt, owner_id)


def _append_history(out, hist_seq, opp_id, from_stage, to_stage, changed_dt, owner_id):
    hist_seq[0] += 1
    out["opportunity_stage_history"].append({
        "history_id": pad_id("HIS", hist_seq[0], 6),
        "opp_id": opp_id,
        "from_stage_num": from_stage,
        "to_stage_num": to_stage,
        "changed_at": fmt_ts(changed_dt),
        "changed_by": owner_id,
        "_synced_at": fmt_ts(_SYNC["stage_hist"]),
        "_changed_dt": changed_dt,
    })


def _emit_renewals(out, opp_seq, hist_seq, accounts, owners, rng):
    """Renewal/expansion opps with no funnel lineage (inflate the naive Sales number)."""
    anchor_dt = datetime(C.ANCHOR_DATE.year, C.ANCHOR_DATE.month, C.ANCHOR_DATE.day)
    nonsmb = [a for a in accounts if a["_segment_canonical"] in ("Mid-Market", "Enterprise")]
    for _ in range(C.N_RENEWAL_OPPS):
        account = nonsmb[int(rng.integers(0, len(nonsmb)))]
        segment = account["_segment_canonical"]
        opp_dt = random_datetime_between(rng, C.WINDOW_START, C.WINDOW_END)
        opp_type = "Renewal" if rng.random() < 0.7 else "Expansion"
        _emit_opportunity(out, opp_seq, hist_seq, account, segment, source=None,
                          opp_dt=opp_dt, owners=owners, rng=rng, hs_id="", sf_lead_id="",
                          is_renewal=True, opp_type=opp_type)


# --- score / lifecycle / events / activities -------------------------------

def _emit_score_history(out, seq, hs_id, created_dt, hs_mql_dt, canon_mql_dt, peak, is_canon, is_hs_only, rng):
    def row(old, new, dt):
        seq[0] += 1
        out["lead_score_history"].append({
            "score_event_id": pad_id("SCR", seq[0], 7),
            "hs_contact_id": hs_id,
            "old_score": old,
            "new_score": new,
            "changed_at": fmt_ts(dt),
            "_synced_at": fmt_ts(_SYNC["score"]),
        })
    base = int(rng.integers(5, 25))
    row(0, base, created_dt)
    if is_canon:
        mid = int(rng.integers(40, 49))                  # crosses 40 (HubSpot MQL)
        row(base, mid, hs_mql_dt)
        row(mid, peak, canon_mql_dt)                     # crosses 50 (canonical MQL)
    elif is_hs_only:
        row(base, peak, hs_mql_dt)                       # peaks in [40,49]
    else:
        if peak > base:
            row(base, peak, add_days(created_dt, float(rng.uniform(1, 20))))


def _emit_marketing_events(out, seq, hs_id, created_dt, until_dt, rng):
    n = int(rng.integers(1, 5))
    for _ in range(n):
        seq[0] += 1
        span = max((until_dt - created_dt).total_seconds(), 1)
        dt = add_days(created_dt, (span * float(rng.uniform(0, 1))) / 86400.0)
        out["marketing_events"].append({
            "event_id": pad_id("EVT", seq[0], 7),
            "hs_contact_id": hs_id,
            "event_type": rng.choice(C.MARKETING_EVENT_TYPES),
            "event_at_utc": fmt_ts(dt),
            "campaign": rng.choice(C.MARKETING_CAMPAIGNS),
            "_synced_at": fmt_ts(_SYNC["events"]),
        })


def _emit_first_activity(out, seq, sf_lead_id, segment, mql_dt, owners, rng):
    """First rep response, stored in the rep's LOCAL wall-clock time (the tz defect)."""
    sdr = _pick_owner(owners, "SDR", segment, rng)
    minutes = lognormal_days(rng, C.RESPONSE_MEDIAN_MIN[segment], C.RESPONSE_SIGMA) / 1440.0
    utc_instant = add_days(mql_dt, minutes).replace(tzinfo=timezone.utc)
    local = utc_instant.astimezone(ZoneInfo(sdr["timezone"])).replace(tzinfo=None)
    seq[0] += 1
    out["activities"].append({
        "activity_id": pad_id("ACT", seq[0], 7),
        "lead_id": sf_lead_id,
        "owner_id": sdr["user_id"],
        "activity_type": rng.choice(["Call", "Email", "Meeting"]),
        "activity_at": fmt_ts(local),     # naive local time, no offset recorded
        "_synced_at": fmt_ts(_SYNC["activities"]),
    })


# --- indexing / helpers ----------------------------------------------------

def _lc_row(hs_id, stage, dt):
    return {"hs_contact_id": hs_id, "lifecycle_stage": stage, "entered_at": fmt_ts(dt)}


def _index_owners(users):
    idx = {}
    for u in users:
        idx.setdefault((u["role"], u["_segment_canonical"]), []).append(u)
    return idx


def _pick_owner(owners, role, segment, rng):
    pool = [u for u in owners.get((role, segment), []) if u["_is_active_bool"]]
    if not pool:
        pool = owners.get((role, segment)) or [u for lst in owners.values() for u in lst]
    return pool[int(rng.integers(0, len(pool)))]


def _index_accounts(accounts):
    idx = {s: [] for s in C.SEGMENTS}
    for a in accounts:
        idx[a["_segment_canonical"]].append(a)
    return idx


def _weighted_segment(rng):
    keys = list(C.SEGMENT_WEIGHTS.keys())
    probs = [C.SEGMENT_WEIGHTS[k] for k in keys]
    return keys[int(rng.choice(len(keys), p=probs))]


def _contact_email(faker, i):
    return f"{faker.user_name()}{i}@example.com"


def _hs_lifecycle_label(is_canon, is_hs_only):
    if is_canon or is_hs_only:
        return "marketingqualifiedlead"
    return "lead"
