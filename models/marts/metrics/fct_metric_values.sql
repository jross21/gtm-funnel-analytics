-- Long-format canonical metric values: (metric_name, grain, period_start, segment, value).
-- This is the SINGLE place each KPI is computed, so Evidence big-numbers/trends and the
-- golden-value tests all read the same number. The metric definitions here implement
-- metrics_catalog.yml (the governed contract, at repo root) and KPI Dictionary #08.
--
-- grain = 'window'  -> one value over the whole analysis window (2025-09..2026-03)
-- grain = 'month'   -> monthly trend (window months only)
-- segment 'All' is the blended rollup.

{% set window_start = "cast('" ~ var('analysis_period_start') ~ "' as date)" %}
{% set window_end = "cast('" ~ var('analysis_period_end') ~ "' as date)" %}

with mqls as (
    select * from {{ ref('fct_mqls') }}
),
opps as (
    select * from {{ ref('fct_opportunities') }}
),
leads as (
    select * from {{ ref('fct_leads') }}
),
funnel as (
    select * from {{ ref('fct_funnel_conversion') }}
),

unioned as (

    -- MQL Volume (KPI #1)
    select 'mql_volume' as metric_name, 'month' as grain, cohort_month as period_start,
           coalesce(segment, 'All') as segment, count(*)::double as value
    from mqls
    group by grouping sets ((cohort_month, segment), (cohort_month))

    union all
    select 'mql_volume', 'window', {{ window_start }}, coalesce(segment, 'All'), count(*)::double
    from mqls
    group by grouping sets ((segment), ())

    -- Pipeline Created (KPI #5): net-new only, by created month
    union all
    select 'pipeline_created', 'month', created_month, coalesce(segment, 'All'),
           round(sum(opp_amount), 2)
    from opps
    where is_net_new_pipeline and created_month between {{ window_start }} and {{ window_end }}
    group by grouping sets ((created_month, segment), (created_month))

    union all
    select 'pipeline_created', 'window', {{ window_start }}, coalesce(segment, 'All'),
           round(sum(opp_amount), 2)
    from opps
    where is_net_new_pipeline and created_month between {{ window_start }} and {{ window_end }}
    group by grouping sets ((segment), ())

    -- Win Rate (KPI #7): closed, amount >= $1k, open >= 7 days
    union all
    select 'win_rate', 'window', {{ window_start }}, coalesce(segment, 'All'),
           round((count(*) filter (where is_won))::double / nullif(count(*), 0), 4)
    from opps
    where is_closed and opp_amount >= 1000
      and {{ dbt.datediff('created_date', 'close_date', 'day') }} >= 7
    group by grouping sets ((segment), ())

    -- Average Sales Cycle (KPI #8): median days, Closed Won
    union all
    select 'avg_sales_cycle_days', 'window', {{ window_start }}, coalesce(segment, 'All'),
           round(percentile_cont(0.5) within group (order by sales_cycle_days), 1)
    from opps
    where is_won and sales_cycle_days is not null
    group by grouping sets ((segment), ())

    -- SLA Compliance (KPI #9)
    union all
    select 'sla_compliance', 'window', {{ window_start }}, coalesce(segment, 'All'),
           round(avg(case when met_sla then 1.0 else 0.0 end), 4)
    from leads
    where met_sla is not null
    group by grouping sets ((segment), ())

    -- Speed-to-Lead median minutes (KPI #3)
    union all
    select 'speed_to_lead_median_min', 'window', {{ window_start }}, coalesce(segment, 'All'),
           round(percentile_cont(0.5) within group (order by response_minutes), 1)
    from leads
    where response_minutes is not null
    group by grouping sets ((segment), ())

    -- Step conversion rates (KPI #2 / #4) — read straight from the funnel mart
    union all
    select 'mql_to_sal_rate', 'window', {{ window_start }}, segment, conversion_rate
    from funnel where stage = 'SAL'
    union all
    select 'sal_to_sql_rate', 'window', {{ window_start }}, segment, conversion_rate
    from funnel where stage = 'SQL'
    union all
    select 'sql_to_opp_rate', 'window', {{ window_start }}, segment, conversion_rate
    from funnel where stage = 'Opportunity'
)

select
    metric_name,
    grain,
    period_start,
    segment,
    value
from unioned
