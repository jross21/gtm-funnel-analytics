---
title: Which number is right?
description: Four teams, four "pipeline" numbers — and the one source of truth.
---

Arcline had four dashboards showing "pipeline created" last period. None agreed. The
**KPI Dictionary (#5)** defines Pipeline Created precisely:

> Sum of `opp_amount` for opportunities with `created_date` in the period and
> `opp_stage` ≥ Stage 1. Exclude renewals, partner-sourced (reported separately), and
> opps with $0 amount. Net-new only.

This page computes the same metric the way each team's dashboard actually computes it,
then resolves to that one canonical definition — and explains every gap.

```sql pipeline_recon
select variant_label, source_team, variant_value, canonical_value, pct_delta, divergence_reason, fix_owner
from arcline.reconciliation
where metric_name = 'pipeline_created'
order by variant_value desc
```

```sql canonical_value
select canonical_value from arcline.reconciliation
where metric_name = 'pipeline_created' limit 1
```

<BarChart data={pipeline_recon} x=variant_label y=variant_value swapXY=true sort=false yAxisTitle="reported pipeline (USD)" labels=true>
  <ReferenceLine data={canonical_value} x=canonical_value label="canonical" color=positive/>
</BarChart>

<DataTable data={pipeline_recon}>
  <Column id=variant_label title="Reported by"/>
  <Column id=variant_value title="Their number" fmt=usd0/>
  <Column id=pct_delta title="vs canonical" fmt=pct1 contentType=delta/>
  <Column id=divergence_reason title="Why it differs" wrap=true/>
  <Column id=fix_owner title="Fix owner"/>
</DataTable>

## MQL Volume — the threshold drift

The same problem, one level up the funnel: HubSpot marks an MQL at lead score ≥ 40,
while the canonical definition (#1) uses ≥ 50. That single undocumented difference makes
HubSpot report **~15% more MQLs**.

```sql mql_recon
select variant_label, variant_value, canonical_value, pct_delta, divergence_reason
from arcline.reconciliation
where metric_name = 'mql_volume'
order by variant_value desc
```

<DataTable data={mql_recon}>
  <Column id=variant_label title="Reported by"/>
  <Column id=variant_value title="MQLs" fmt=num0/>
  <Column id=pct_delta title="vs canonical" fmt=pct1 contentType=delta/>
  <Column id=divergence_reason title="Why it differs" wrap=true/>
</DataTable>

Every gap above has a **reason** and an **owner** — and a dbt test
(`assert_recon_canonical_is_reconciled`) fails the build if any gap is left unexplained.
