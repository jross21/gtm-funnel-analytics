---
title: Funnel Conversion
description: Stage-to-stage conversion by segment.
---

```sql segments
select 'All' as segment, 0 as ord
union all select 'SMB', 1
union all select 'Mid-Market', 2
union all select 'Enterprise', 3
order by ord
```

<Dropdown data={segments} name=segment value=segment defaultValue="All"/>

```sql conversion
select stage, stage_order, leads_reaching, prior_stage_count, conversion_rate
from arcline.funnel_conversion
where segment = '${inputs.segment.value}'
order by stage_order
```

## {inputs.segment.value} funnel

<BarChart data={conversion} x=stage y=leads_reaching swapXY=true sort=false yAxisTitle="leads reaching stage"/>

<DataTable data={conversion}>
  <Column id=stage/>
  <Column id=leads_reaching fmt=num0/>
  <Column id=prior_stage_count title="prior stage" fmt=num0/>
  <Column id=conversion_rate title="step conversion" fmt=pct1 contentType=colorscale/>
</DataTable>

Conversion rate is the share of the **prior** stage that reached this stage. MQL has no
prior stage, so its rate is blank.
