-- One row per net-new opportunity x marketing touch that preceded its creation.
-- Touches come from the source contact's HubSpot marketing events; ranked in time so
-- first/last/linear attribution can be derived in fct_attribution.

with opps as (
    select
        opp_id,
        source_hs_contact_id,
        segment,
        opp_amount,
        created_date
    from {{ ref('fct_opportunities') }}
    where is_net_new_pipeline
),

events as (
    select * from {{ ref('stg_hs__marketing_events') }}
),

touches as (
    select
        opps.opp_id,
        opps.segment,
        opps.opp_amount,
        events.event_id,
        events.campaign,
        events.event_at_utc
    from opps
    inner join events
        on
            opps.source_hs_contact_id = events.hs_contact_id
            and opps.created_date > events.event_at_utc
)

select
    opp_id,
    segment,
    opp_amount,
    event_id,
    campaign,
    event_at_utc,
    row_number() over (partition by opp_id order by event_at_utc, event_id) as touch_rank,
    count(*) over (partition by opp_id) as touch_count
from touches
