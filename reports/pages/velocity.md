---
title: Stage Velocity
description: Time-in-stage by segment — and why median, not mean.
---

How long opportunities sit in each selling stage. Sales cycles are right-skewed, so the
**median** and **average** diverge — this is why the KPI Dictionary specifies median for
sales-cycle metrics.

```sql velocity
select segment, stage_num, stage_name, spell_count, median_days_in_stage, avg_days_in_stage, p90_days_in_stage
from arcline.stage_velocity
where segment <> 'All'
order by stage_num, segment
```

<BarChart data={velocity} x=stage_name y=median_days_in_stage series=segment type=grouped yAxisTitle="median days in stage" sort=false/>

<DataTable data={velocity} groupBy=segment>
  <Column id=stage_name title=stage/>
  <Column id=spell_count title=opps fmt=num0/>
  <Column id=median_days_in_stage title=median fmt=num1/>
  <Column id=avg_days_in_stage title=mean fmt=num1/>
  <Column id=p90_days_in_stage title=p90 fmt=num1/>
</DataTable>

SMB deals move fastest; Enterprise deals sit longest in Discovery. Where mean ≫ median,
a long tail of stalled deals is dragging the average.
