-- MART C — monthly MQL cohort progression.
-- Grain: cohort_month x segment x months_since. For leads that became canonical MQLs
-- in a given month, the cumulative share that had reached each downstream stage within
-- N months of MQL. Recent cohorts are intentionally immature (the point of cohorting).

with leads as (
    select
        l.lead_id,
        l.segment,
        cast({{ dbt.date_trunc('month', 'l.mql_at') }} as date) as cohort_month,
        l.mql_at,
        l.sal_at,
        l.sql_at,
        l.opp_at,
        o.close_date as won_at
    from {{ ref('fct_leads') }} l
    left join {{ ref('fct_opportunities') }} o
        on l.opp_id = o.opp_id and o.is_won
    where l.is_mql
),

offsets as (
    select
        cohort_month,
        segment,
        lead_id,
        {{ dbt.datediff('mql_at', 'sal_at', 'month') }} as m_sal,
        {{ dbt.datediff('mql_at', 'sql_at', 'month') }} as m_sql,
        {{ dbt.datediff('mql_at', 'opp_at', 'month') }} as m_opp,
        {{ dbt.datediff('mql_at', 'won_at', 'month') }} as m_won
    from leads
),

months_since as (
    select * from (values (0), (1), (2), (3), (4), (5), (6)) as t(months_since)
),

cohort as (
    select
        offsets.cohort_month,
        coalesce(offsets.segment, 'All') as segment,
        months_since.months_since,
        count(*) as cohort_size,
        count(*) filter (where m_sal <= months_since.months_since) as reached_sal,
        count(*) filter (where m_sql <= months_since.months_since) as reached_sql,
        count(*) filter (where m_opp <= months_since.months_since) as reached_opportunity,
        count(*) filter (where m_won <= months_since.months_since) as reached_won
    from offsets
    cross join months_since
    group by grouping sets (
        (offsets.cohort_month, offsets.segment, months_since.months_since),
        (offsets.cohort_month, months_since.months_since)
    )
)

select
    cohort_month,
    segment,
    months_since,
    cohort_size,
    reached_sal,
    reached_sql,
    reached_opportunity,
    reached_won,
    round(reached_opportunity::double / nullif(cohort_size, 0), 4) as pct_reached_opportunity,
    round(reached_won::double / nullif(cohort_size, 0), 4) as pct_reached_won
from cohort
-- Don't show cells whose observation window extends past "today" — an immature
-- cohort hasn't had the chance to progress, so leave those future months blank.
where {{ dbt.dateadd('month', 'months_since', 'cohort_month') }} <= cast('{{ var("build_anchor_date") }}' as date)
