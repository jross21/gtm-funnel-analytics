---
title: Data Quality
description: Source freshness and the deliberate-defect ledger.
---

## Source freshness

Measured against the build anchor ("today" = 2026-04-01), not wall-clock — so committed
static seeds don't go perpetually stale in CI. The pattern (max load time vs an SLA) is
identical to production.

```sql freshness
select source_name, last_synced_at, age_hours, sla_warn_hours, sla_error_hours, freshness_status
from arcline.source_freshness
order by age_hours desc
```

<DataTable data={freshness}>
  <Column id=source_name title=source/>
  <Column id=last_synced_at title="last sync"/>
  <Column id=age_hours title="age (h)" fmt=num0/>
  <Column id=freshness_status title=status contentType=colorscale/>
</DataTable>

## Deliberate-defect ledger

The synthetic source data has realistic defects baked in on purpose — they give the
staging models real cleaning work and give the dbt tests something to catch. Each defect
maps to the model that resolves it and the test that guards it.

| Defect | Resolved by | Guarded by |
|---|---|---|
| Duplicate opportunities | `stg_sf__opportunities` dedupe | `unique_combination_of_columns` |
| Duplicate HubSpot contacts | `stg_hs__contacts` dedupe by email | combo test on email |
| Null / inactive owners | `int_opportunities__enriched` flags | documented |
| Inconsistent / null segment labels | `stg_sf__accounts` crosswalk + fallback | `accepted_values` (3 segments) |
| Timezone mismatch (UTC vs rep-local) | `int_activities__first_touch` + `to_utc()` | speed-to-lead / SLA |
| Late / missing stage history | `int_opportunities__stage_spells` | recency anomaly + coverage |
| Null / $0 / non-USD amounts | `fct_opportunities` excludes / flags | `assert_canonical_pipeline_excludes_renewals` |
| Test / internal records | staging filters | `assert_no_test_records_in_marts` |
| MQL threshold drift (40 vs 50) | `int_leads__lifecycle_events` uses 50 | `assert_mql_threshold_is_canonical` |
| Broken hs↔sf crosswalk (~8%) | `int_leads__unified` LEFT join + flag | the "Data team" reconciliation variant |

Every push runs `dbt build` (seed → run → **test**); a single failed test fails CI and
blocks the dashboard from refreshing — the same contract Arcline's KPI Dictionary spells out.
