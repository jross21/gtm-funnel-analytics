---
title: MQL Cohorts
description: How each month's MQL cohort progresses to Opportunity over time.
---

Of the leads that became canonical MQLs in a given month, what share had reached
**Opportunity** within N months. Recent cohorts are intentionally immature — they
haven't had the months to progress yet (blank cells), which is exactly how a cohort
triangle should read.

```sql cohorts
select
  strftime(cohort_month, '%Y-%m') as cohort,
  months_since,
  cohort_size,
  pct_reached_opportunity
from arcline.cohort_progression
where segment = 'All'
order by cohort, months_since
```

<Heatmap data={cohorts} x=months_since y=cohort value=pct_reached_opportunity valueFmt=pct1 title="% of MQL cohort reaching Opportunity"/>

```sql cohort_sizes
select strftime(cohort_month, '%Y-%m') as cohort, max(cohort_size) as mql_cohort_size
from arcline.cohort_progression
where segment = 'All'
group by 1 order by 1
```

<BarChart data={cohort_sizes} x=cohort y=mql_cohort_size yAxisTitle="MQLs in cohort"/>
