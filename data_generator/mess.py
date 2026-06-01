"""Deliberate data-quality defects, injected in one documented place.

Every defect here is intentional: it gives the staging models real cleaning work
and gives the dbt tests something to catch. See data_generator/README.md for the
ledger mapping each defect -> the model that cleans it -> the test that guards it.
"""

from __future__ import annotations

from datetime import timedelta

from . import config as C
from .util import add_days, fmt_ts


def _sample_idx(rng, n, rate):
    k = int(round(n * rate))
    if k <= 0 or n == 0:
        return []
    return sorted(int(i) for i in rng.choice(n, size=min(k, n), replace=False))


def apply_defects(rng, tables, accounts, users):
    opps = tables["opportunities"]
    contacts = tables["contacts"]
    crosswalk = tables["id_crosswalk"]
    history = tables["opportunity_stage_history"]
    inactive_ids = [u["user_id"] for u in users if not u["_is_active_bool"]]

    # #1 Duplicate opportunities — same business key, new opp_id.
    funnel_idx = [i for i, o in enumerate(opps) if o["source_hs_contact_id"]]
    for i in _sample_idx(rng, len(funnel_idx), C.DEFECT_DUP_OPP_RATE):
        orig = opps[funnel_idx[i]]
        dup = dict(orig)
        dup["opp_id"] = orig["opp_id"] + "D"
        opps.append(dup)

    # #2 Duplicate HubSpot contacts — same email, new hs_contact_id.
    for i in _sample_idx(rng, len(contacts), C.DEFECT_DUP_CONTACT_RATE):
        orig = contacts[i]
        dup = dict(orig)
        dup["hs_contact_id"] = orig["hs_contact_id"] + "D"
        contacts.append(dup)

    # #3 Orphaned / inactive owners.
    for i in _sample_idx(rng, len(opps), C.DEFECT_NULL_OWNER_RATE):
        opps[i]["owner_id"] = ""
    if inactive_ids:
        for i in _sample_idx(rng, len(opps), C.DEFECT_INACTIVE_OWNER_RATE):
            if opps[i]["owner_id"]:
                opps[i]["owner_id"] = inactive_ids[int(rng.integers(0, len(inactive_ids)))]

    # #4 Blank raw segment labels on accounts (staging falls back to employee_count).
    for i in _sample_idx(rng, len(accounts), C.DEFECT_NULL_SEGMENT_RATE):
        accounts[i]["segment_raw"] = ""

    # #7 Amount / currency problems.
    for i in _sample_idx(rng, len(opps), C.DEFECT_NULL_AMOUNT_RATE):
        opps[i]["opp_amount"] = ""
    for i in _sample_idx(rng, len(opps), C.DEFECT_ZERO_AMOUNT_RATE):
        opps[i]["opp_amount"] = "0.00"
    for i in _sample_idx(rng, len(opps), C.DEFECT_NON_USD_RATE):
        opps[i]["currency"] = C.NON_USD_CURRENCIES[int(rng.integers(0, len(C.NON_USD_CURRENCIES)))]

    # #8 Test opps and internal contacts.
    for i in _sample_idx(rng, len(opps), C.DEFECT_TEST_RECORD_RATE):
        opps[i]["is_test"] = "true"
        opps[i]["opp_name"] = "DELETEME - " + opps[i]["opp_name"]
    for i in _sample_idx(rng, len(contacts), C.DEFECT_INTERNAL_CONTACT_RATE):
        contacts[i]["is_internal"] = "true"
        contacts[i]["email"] = contacts[i]["email"].split("@")[0] + "@arcline.com"

    # #10 Broken hs<->sf id crosswalk (the "Looker is always lower" undercount).
    for i in _sample_idx(rng, len(crosswalk), C.DEFECT_CROSSWALK_BREAK_RATE):
        crosswalk[i]["sf_lead_id"] = ""
        crosswalk[i]["match_confidence"] = "low"

    # #6 Late-arriving + missing stage history.
    for i in _sample_idx(rng, len(history), C.DEFECT_LATE_HISTORY_RATE):
        # _synced_at predates the event -> a clock/integration anomaly a test can flag.
        history[i]["_synced_at"] = fmt_ts(history[i]["_changed_dt"] - timedelta(days=1))
    closed_opp_ids = [o["opp_id"] for o in opps if o["is_closed"] == "true"]
    drop_ids = set()
    for i in _sample_idx(rng, len(closed_opp_ids), C.DEFECT_MISSING_HISTORY_RATE):
        drop_ids.add(closed_opp_ids[i])
    if drop_ids:
        tables["opportunity_stage_history"] = [h for h in history if h["opp_id"] not in drop_ids]

    return tables
