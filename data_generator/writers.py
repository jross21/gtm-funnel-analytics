"""Write the in-memory tables to deterministic CSV seeds.

Column order and row sort are fixed, and every value is already a string, so the
output is byte-identical across runs and machines.
"""

from __future__ import annotations

import csv
import os

# table key (or source list) -> (seed filename, columns in order, sort keys)
SEEDS = {
    "accounts": ("raw_sf_accounts", [
        "account_id", "account_name", "segment_raw", "industry", "country",
        "employee_count", "created_date", "is_test", "_synced_at"], ["account_id"]),
    "users": ("raw_sf_users", [
        "user_id", "full_name", "email", "role", "segment_raw", "timezone",
        "is_active", "_synced_at"], ["user_id"]),
    "opportunities": ("raw_sf_opportunities", [
        "opp_id", "account_id", "owner_id", "opp_name", "opp_stage", "opp_stage_num",
        "opp_amount", "currency", "opp_type", "lead_source", "is_partner_sourced",
        "created_date", "close_date", "is_won", "is_closed", "is_test",
        "source_hs_contact_id", "source_sf_lead_id", "_synced_at"], ["opp_id"]),
    "opportunity_stage_history": ("raw_sf_opportunity_stage_history", [
        "history_id", "opp_id", "from_stage_num", "to_stage_num", "changed_at",
        "changed_by", "_synced_at"], ["history_id"]),
    "activities": ("raw_sf_activities", [
        "activity_id", "lead_id", "owner_id", "activity_type", "activity_at",
        "_synced_at"], ["activity_id"]),
    "contacts": ("raw_hs_contacts", [
        "hs_contact_id", "email", "account_name_freetext", "lifecycle_stage_hs",
        "hs_lead_score", "lead_source_hs", "segment_raw_hs", "country", "created_at",
        "is_internal", "_synced_at"], ["hs_contact_id"]),
    "marketing_events": ("raw_hs_marketing_events", [
        "event_id", "hs_contact_id", "event_type", "event_at_utc", "campaign",
        "_synced_at"], ["event_id"]),
    "lead_score_history": ("raw_hs_lead_score_history", [
        "score_event_id", "hs_contact_id", "old_score", "new_score", "changed_at",
        "_synced_at"], ["score_event_id"]),
    "lifecycle_history": ("raw_hs_lifecycle_history", [
        "hs_contact_id", "lifecycle_stage", "entered_at"],
        ["hs_contact_id", "lifecycle_stage"]),
    "segment_map": ("raw_ref_segment_map", [
        "segment_raw", "segment_canonical"], ["segment_raw"]),
    "id_crosswalk": ("raw_ref_id_crosswalk", [
        "hs_contact_id", "sf_lead_id", "match_confidence"], ["hs_contact_id"]),
}


def write_all(tables: dict, out_dir: str) -> dict:
    os.makedirs(out_dir, exist_ok=True)
    counts = {}
    for key, (filename, columns, sort_keys) in SEEDS.items():
        rows = tables[key]
        rows = sorted(rows, key=lambda r: tuple(str(r[k]) for k in sort_keys))
        path = os.path.join(out_dir, f"{filename}.csv")
        with open(path, "w", newline="") as f:
            writer = csv.writer(f, lineterminator="\n")
            writer.writerow(columns)
            for r in rows:
                writer.writerow([r.get(c, "") for c in columns])
        counts[filename] = len(rows)
    return counts
