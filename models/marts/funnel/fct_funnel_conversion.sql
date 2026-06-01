-- MART A — funnel conversion by segment and stage.
-- Grain: segment x stage (segment 'All' = blended). Each row carries the count of
-- leads that reached the stage, the prior-stage count, and the step conversion rate.

with counts as (
    select
        coalesce(segment, 'All') as segment,
        count(*) filter (where is_mql) as c_mql,
        count(*) filter (where reached_sal) as c_sal,
        count(*) filter (where reached_sql) as c_sql,
        count(*) filter (where reached_opp) as c_opp,
        count(*) filter (where is_won) as c_won
    from {{ ref('fct_leads') }}
    group by grouping sets ((segment), ())
),

unpivoted as (
    select segment, 'MQL'         as stage, 1 as stage_order, c_mql as leads_reaching, cast(null as bigint) as prior_stage_count from counts
    union all
    select segment, 'SAL'         as stage, 2 as stage_order, c_sal as leads_reaching, c_mql as prior_stage_count from counts
    union all
    select segment, 'SQL'         as stage, 3 as stage_order, c_sql as leads_reaching, c_sal as prior_stage_count from counts
    union all
    select segment, 'Opportunity' as stage, 4 as stage_order, c_opp as leads_reaching, c_sql as prior_stage_count from counts
    union all
    select segment, 'Closed Won'  as stage, 5 as stage_order, c_won as leads_reaching, c_opp as prior_stage_count from counts
)

select
    segment,
    stage,
    stage_order,
    leads_reaching,
    prior_stage_count,
    case
        when prior_stage_count > 0
            then round(leads_reaching::double / prior_stage_count, 4)
    end as conversion_rate
from unpivoted
