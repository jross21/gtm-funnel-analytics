-- Canonical lead fact: one row per lead, with the furthest stage reached, the
-- canonical MQL timestamp, speed-to-lead, and SLA compliance. Internal/employee
-- contacts are excluded. Speed-to-lead joins first touch via the (possibly broken)
-- crosswalk, so unmatched leads have a null met_sla rather than a false negative.

with leads as (
    select * from {{ ref('int_leads__unified') }}
),

events as (
    select * from {{ ref('int_leads__lifecycle_events') }}
),

reached as (
    select
        hs_contact_id,
        max(case when lifecycle_stage = 'MQL' then 1 else 0 end) = 1 as is_mql,
        min(case when lifecycle_stage = 'MQL' then entered_at end) as mql_at,
        max(case when lifecycle_stage = 'SAL' then 1 else 0 end) = 1 as reached_sal,
        min(case when lifecycle_stage = 'SAL' then entered_at end) as sal_at,
        max(case when lifecycle_stage = 'SQL' then 1 else 0 end) = 1 as reached_sql,
        min(case when lifecycle_stage = 'SQL' then entered_at end) as sql_at,
        max(case when lifecycle_stage = 'Opportunity' then 1 else 0 end) = 1 as reached_opp,
        min(case when lifecycle_stage = 'Opportunity' then entered_at end) as opp_at
    from events
    group by 1
),

opps as (
    select source_hs_contact_id, opp_id, is_won, is_closed
    from {{ ref('fct_opportunities') }}
    where source_hs_contact_id is not null
),

first_touch as (
    select * from {{ ref('int_activities__first_touch') }}
)

select
    leads.lead_id,
    leads.hs_contact_id,
    leads.sf_lead_id,
    leads.is_crosswalk_matched,
    leads.segment,
    leads.lead_source,
    leads.hs_lead_score,
    leads.created_at,
    coalesce(reached.is_mql, false) as is_mql,
    reached.mql_at,
    coalesce(reached.reached_sal, false) as reached_sal,
    reached.sal_at,
    coalesce(reached.reached_sql, false) as reached_sql,
    reached.sql_at,
    coalesce(reached.reached_opp, false) as reached_opp,
    reached.opp_at,
    opps.opp_id,
    coalesce(opps.is_won, false) as is_won,
    coalesce(opps.is_closed, false) as is_closed,
    first_touch.first_activity_at_utc,
    {{ dbt.datediff('reached.mql_at', 'first_touch.first_activity_at_utc', 'minute') }} as response_minutes,
    case
        when first_touch.first_activity_at_utc is null then null
        when {{ dbt.datediff('reached.mql_at', 'first_touch.first_activity_at_utc', 'minute') }}
             <= case leads.segment when 'SMB' then 5 when 'Mid-Market' then 15 when 'Enterprise' then 60 end
            then true
        else false
    end as met_sla,
    case
        when coalesce(opps.is_won, false) then 'Closed Won'
        when coalesce(opps.is_closed, false) then 'Closed Lost'
        when reached.opp_at is not null then 'Opportunity'
        when reached.sql_at is not null then 'SQL'
        when reached.sal_at is not null then 'SAL'
        when coalesce(reached.is_mql, false) then 'MQL'
        else 'New'
    end as lifecycle_stage
from leads
left join reached on leads.hs_contact_id = reached.hs_contact_id
left join opps on leads.hs_contact_id = opps.source_hs_contact_id
left join first_touch on leads.sf_lead_id = first_touch.lead_id
where not leads.is_internal
