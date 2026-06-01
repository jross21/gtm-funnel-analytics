-- MART B — stage velocity (time-in-stage) by segment and selling stage.
-- Median, average, and p90 days, so the median-vs-mean gap (right-skewed cycles) is
-- visible. percentile_cont(...) within group is portable to Snowflake.

with stages as (
    select * from {{ ref('fct_opportunity_stage') }}
)

select
    coalesce(segment, 'All') as segment,
    stage_num,
    stage_name,
    count(*) as spell_count,
    round(percentile_cont(0.5) within group (order by days_in_stage), 1) as median_days_in_stage,
    round(avg(days_in_stage), 1) as avg_days_in_stage,
    round(percentile_cont(0.9) within group (order by days_in_stage), 1) as p90_days_in_stage
from stages
group by grouping sets ((segment, stage_num, stage_name), (stage_num, stage_name))
