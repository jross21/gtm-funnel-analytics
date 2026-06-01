-- Every canonical MQL must clear the canonical lead-score threshold (>= 50). This is
-- the guardrail against the HubSpot 40-threshold drift silently reappearing in a mart.

select
    m.mql_event_id,
    l.hs_lead_score
from {{ ref('fct_mqls') }} as m
inner join {{ ref('fct_leads') }} as l on m.lead_id = l.lead_id
where l.hs_lead_score < {{ var('mql_score_threshold') }}
