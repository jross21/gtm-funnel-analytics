---
title: Metric Catalog
description: The governed KPI definitions — one definition, one number.
---

Every metric is defined once in the governed catalog (`metrics_catalog.yml`), implemented
once in `fct_metric_values`, and **locked** by a dbt test that asserts the computed value
equals the catalog's golden value. Change a definition and the value + this catalog move
in the same commit — that diff is the audit trail.

```sql catalog
select
  label,
  kpi_dictionary_ref as kpi_dict,
  definition,
  grain,
  owner,
  freshness_sla,
  expected_window_value
from arcline.metric_catalog
order by kpi_dict
```

<DataTable data={catalog} rows=20>
  <Column id=label title=Metric/>
  <Column id=kpi_dict title="KPI #"/>
  <Column id=definition wrap=true/>
  <Column id=grain/>
  <Column id=owner/>
  <Column id=freshness_sla title="Freshness SLA"/>
  <Column id=expected_window_value title="Window value (All)"/>
</DataTable>

The `expected_window_value` is the canonical result over 2025-09 → 2026-03 on the
deterministic dataset (`seed=42`). `tests/assert_metric_values_match_catalog.sql` fails
the build if the implementation ever disagrees with this contract.
