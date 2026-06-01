-- A cumulative cohort count can only grow as months pass — it must never decrease with
-- months_since. A drop would mean the cohort logic double-counts or loses leads.

with ordered as (
    select
        cohort_month,
        segment,
        months_since,
        reached_opportunity,
        lag(reached_opportunity) over (
            partition by cohort_month, segment order by months_since
        ) as prev_reached
    from {{ ref('fct_cohort_progression') }}
)

select *
from ordered
where
    prev_reached is not null
    and reached_opportunity < prev_reached
