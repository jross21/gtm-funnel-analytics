-- Time-in-stage spells derived from the stage history. Each spell runs from a stage
-- entry to the next transition; the final open spell ends at close_date (if closed)
-- or the build anchor ("today"). Opps with missing history simply contribute no
-- spells (handled, not crashed). Only active selling stages (1-4) are measured.

with history as (
    select * from {{ ref('stg_sf__opportunity_stage_history') }}
),

opp as (
    select opp_id, close_date, is_closed from {{ ref('stg_sf__opportunities') }}
),

ordered as (
    select
        opp_id,
        to_stage_num as stage_num,
        changed_at as stage_entered_at,
        lead(changed_at) over (
            partition by opp_id order by changed_at
        ) as next_changed_at
    from history
),

spells as (
    select
        ordered.opp_id,
        ordered.stage_num,
        ordered.stage_entered_at,
        coalesce(
            ordered.next_changed_at,
            cast(opp.close_date as timestamp),
            cast('{{ var("build_anchor_date") }}' as timestamp)
        ) as stage_exited_at
    from ordered
    inner join opp on ordered.opp_id = opp.opp_id
)

select
    opp_id,
    stage_num,
    case stage_num
        when 1 then 'Discovery'
        when 2 then 'Demo'
        when 3 then 'Proposal'
        when 4 then 'Negotiation'
    end as stage_name,
    stage_entered_at,
    stage_exited_at,
    greatest(0, {{ dbt.datediff('stage_entered_at', 'stage_exited_at', 'day') }}) as days_in_stage
from spells
where stage_num between 1 and 4
