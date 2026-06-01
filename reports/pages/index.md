---
title: Arcline GTM Funnel Analytics
description: Tested, governed, reproducible revenue metrics — and the end of "which number is right?"
---

The analytics-engineering layer for **Arcline Systems** ($15M ARR B2B SaaS): a dbt model
over Salesforce + HubSpot funnel data that turns the [KPI Dictionary](/metric-catalog)
into tested, governed metrics — and resolves the
[four-dashboards-four-numbers problem](/which-number-is-right) in code.

```sql kpis
select
  max(case when metric_name = 'pipeline_created' then value end) as pipeline_created,
  max(case when metric_name = 'mql_volume' then value end) as mql_volume,
  max(case when metric_name = 'win_rate' then value end) as win_rate,
  max(case when metric_name = 'sla_compliance' then value end) as sla_compliance
from arcline.metric_values
where grain = 'window' and segment = 'All'
```

<BigValue data={kpis} value=pipeline_created fmt=usd0 title="Pipeline Created (canonical)"/>
<BigValue data={kpis} value=mql_volume fmt=num0 title="MQL Volume"/>
<BigValue data={kpis} value=win_rate fmt=pct1 title="Win Rate"/>
<BigValue data={kpis} value=sla_compliance fmt=pct1 title="SLA Compliance"/>

## The funnel

Leads reaching each stage, blended across segments (2025-09 → 2026-03).

```sql funnel
select stage, stage_order, leads_reaching, conversion_rate
from arcline.funnel_conversion
where segment = 'All'
order by stage_order
```

<BarChart data={funnel} x=stage y=leads_reaching swapXY=true sort=false yAxisTitle="leads reaching stage">
  <ReferenceArea xMin=MQL xMax="Closed Won"/>
</BarChart>

Step conversion from the previous stage:

<DataTable data={funnel}>
  <Column id=stage/>
  <Column id=leads_reaching fmt=num0/>
  <Column id=conversion_rate fmt=pct1 contentType=colorscale/>
</DataTable>

→ See [Conversion](/conversion) · [Velocity](/velocity) · [Cohorts](/cohorts) · [Attribution](/attribution) · [Which number is right?](/which-number-is-right)
