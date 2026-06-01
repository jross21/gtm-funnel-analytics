# Synthetic source data — Arcline Systems

Deterministic generator (`seed=42`) that emits the 11 raw CSV seeds in `../seeds/`.
A single per-contact journey simulation is the source of truth; every table is
derived from it, so the data is internally consistent.

```bash
python -m data_generator.generate   # regenerate the seeds (byte-identical each run)
```

The committed CSVs are the source of truth for dbt/CI — you only run this to change
the data. Re-running on the same pinned environment reproduces identical bytes.

## Raw tables

| Seed (`raw_*`) | Grain | Notes |
|---|---|---|
| `raw_sf_accounts` | 1 account | canonical segment + messy `segment_raw`, `employee_count` for fallback |
| `raw_sf_users` | 1 rep | role (SDR/AE/AM), segment coverage, IANA `timezone`, `is_active` |
| `raw_sf_opportunities` | 1 opp | sales stage `0..6`, amount/currency, type (New/Renewal/Expansion), `source_hs_contact_id` lineage |
| `raw_sf_opportunity_stage_history` | 1 stage transition | drives time-in-stage; some late/missing (defect #6) |
| `raw_sf_activities` | 1 logged activity | first rep touch in **rep-local** time (defect #5) |
| `raw_hs_contacts` | 1 contact | `hs_lead_score`, HubSpot `lifecycle_stage_hs`, messy source/segment labels |
| `raw_hs_marketing_events` | 1 event | form fills / webinars / etc. |
| `raw_hs_lead_score_history` | 1 score change | crossing 40 = HubSpot MQL, crossing 50 = canonical MQL |
| `raw_hs_lifecycle_history` | 1 contact × stage entry | HubSpot-recorded lifecycle dates (New/MQL/SAL/SQL/Opportunity) |
| `raw_ref_segment_map` | 1 label | crosswalk: messy `segment_raw` → canonical segment |
| `raw_ref_id_crosswalk` | 1 mapping | `hs_contact_id` ↔ `sf_lead_id`; ~8% broken (defect #10) |

## The funnel (by design)

Score-driven and segment-skewed (SMB-heavy volume, Enterprise-heavy ACV). Knobs live
in `config.py`. Canonical MQL = lead score ≥ **50**; HubSpot marks MQL at ≥ **40**, so
HubSpot counts **~15% more** MQLs — the headline metric-trust defect.

## Deliberate data-quality defect ledger

These defects are intentional. They give the staging layer real cleaning work and the
dbt tests something to guard. Each maps to the model that resolves it and the test that
catches it.

| # | Defect | Where injected | Resolved by | Guarded by |
|---|--------|----------------|-------------|------------|
| 1 | Duplicate opportunities (same business key, new `opp_id`) | `mess.py` | `stg_sf__opportunities` dedupe (keep first by business key) | `dbt_utils.unique_combination_of_columns` on staged business key |
| 2 | Duplicate HubSpot contacts (same email) | `mess.py` | `stg_hs__contacts` dedupe by email | `unique` on `stg_hs__contacts.hs_contact_id` + combo test on email |
| 3 | Null / inactive opportunity owners | `mess.py` | `int_opportunities__enriched` flags orphaned/inactive | `not_null` on mart owner where applicable; documented |
| 4 | Inconsistent / null segment labels | generator + `mess.py` | `stg_sf__accounts` resolves via `raw_ref_segment_map`, falls back on `employee_count` | `accepted_values` (3 segments) on marts |
| 5 | Timezone mismatch (HS events UTC, SF activities rep-local) | generator | `int_activities__first_touch` normalizes via `to_utc()` + rep timezone | speed-to-lead/SLA reconciliation test |
| 6 | Late-arriving / missing stage history | `mess.py` | `int_opportunities__stage_spells` imputes/handles gaps | `severity: warn` recency anomaly + spell coverage test |
| 7 | Null / $0 / non-USD amounts | `mess.py` | `stg_sf__opportunities` flags; canonical Pipeline excludes them | `assert_canonical_pipeline_excludes_renewals` + range tests |
| 8 | Test opps / internal contacts | `mess.py` | staging filters `is_test` / `is_internal` | `assert_no_test_records_in_marts` |
| 9 | MQL threshold drift (HubSpot 40 vs canonical 50) | generator | `int_leads__lifecycle_events` uses canonical 50 | `assert_mql_threshold_is_canonical` + reconciliation page |
| 10 | Broken hs↔sf id crosswalk (~8%) | `mess.py` | `int_leads__unified` LEFT joins + reports unmatched | reconciliation: the "Data team / Looker" undercount variant |

## Module map

- `config.py` — every knob (volumes, conversion/win rates, durations, ACV, defect rates).
- `dimensions.py` — reps, accounts, segment crosswalk.
- `journeys.py` — the coupled lead → opportunity simulation.
- `mess.py` — defect injection (the table above).
- `writers.py` — deterministic CSV writing (fixed column order + row sort).
- `generate.py` — entrypoint + funnel sanity-check summary.
