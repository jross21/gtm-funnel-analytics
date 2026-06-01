-- One row per opportunity x stage spell, enriched with segment. Feeds stage velocity.

with spells as (
    select * from {{ ref('int_opportunities__stage_spells') }}
),

opps as (
    select opp_id, segment, opp_type from {{ ref('fct_opportunities') }}
)

select
    spells.opp_id,
    opps.segment,
    opps.opp_type,
    spells.stage_num,
    spells.stage_name,
    spells.stage_entered_at,
    spells.stage_exited_at,
    spells.days_in_stage
from spells
inner join opps on spells.opp_id = opps.opp_id
