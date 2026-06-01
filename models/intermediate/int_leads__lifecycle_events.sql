-- One row per lead per canonical lifecycle stage entry.
--
-- The MQL entry is derived from the SCORE history at the canonical threshold (>=50),
-- NOT from HubSpot's recorded MQL date (which fires at the drifted >=40). New/SAL/SQL/
-- Opportunity come from the lifecycle history. This is where the canonical MQL
-- definition is enforced.

with lifecycle as (
    select * from {{ ref('stg_hs__lifecycle_history') }}
),

scores as (
    select * from {{ ref('stg_hs__lead_score_history') }}
),

canonical_mql as (
    select
        hs_contact_id,
        min(changed_at) as entered_at
    from scores
    where new_score >= {{ var('mql_score_threshold') }}
    group by 1
),

events as (
    select hs_contact_id, lifecycle_stage, entered_at
    from lifecycle
    where lifecycle_stage in ('New', 'SAL', 'SQL', 'Opportunity')

    union all

    select hs_contact_id, 'MQL' as lifecycle_stage, entered_at
    from canonical_mql
)

select
    hs_contact_id,
    lifecycle_stage,
    entered_at,
    case lifecycle_stage
        when 'New' then 1
        when 'MQL' then 2
        when 'SAL' then 3
        when 'SQL' then 4
        when 'Opportunity' then 5
    end as stage_order
from events
