---
title: Marketing Attribution
description: Which campaigns get credit for net-new pipeline — and how the answer changes by model.
---

Net-new pipeline ($6.9M) attributed to the marketing campaigns that touched each
opportunity's contact before it was created. The credit a campaign gets depends entirely
on the **attribution model** — top-of-funnel campaigns look strong under first-touch,
closing campaigns under last-touch. Credit conserves exactly: every model re-distributes
the same total pipeline (a dbt test enforces it).

```sql segments
select 'All' as segment, 0 as ord
union all select 'SMB', 1
union all select 'Mid-Market', 2
union all select 'Enterprise', 3
order by ord
```

<Dropdown data={segments} name=segment value=segment defaultValue="All"/>

## How the three models compare ({inputs.segment.value})

```sql compare
select campaign, attribution_model, attributed_pipeline
from arcline.attribution
where segment = '${inputs.segment.value}'
order by campaign
```

<BarChart data={compare} x=campaign y=attributed_pipeline series=attribution_model type=grouped swapXY=true yAxisTitle="attributed pipeline (USD)" sort=false/>

Campaigns that gain credit going from first → last touch are closing the deal; those that
lose credit are opening it. A campaign that holds steady across models is influential
throughout.

## Detail

```sql model_pick
select 'first_touch' as model union all select 'last_touch' union all select 'linear'
```

<Dropdown data={model_pick} name=model value=model defaultValue="linear"/>

```sql by_campaign
select campaign, attributed_pipeline, opps
from arcline.attribution
where attribution_model = '${inputs.model.value}' and segment = '${inputs.segment.value}'
order by attributed_pipeline desc
```

<DataTable data={by_campaign} totalRow=true>
  <Column id=campaign/>
  <Column id=attributed_pipeline title="attributed pipeline" fmt=usd0/>
  <Column id=opps title="opps touched" fmt=num0/>
</DataTable>

*Models: **first-touch** (100% to the earliest touch), **last-touch** (100% to the latest
touch before the opp), **linear** (split evenly across all touches).*
