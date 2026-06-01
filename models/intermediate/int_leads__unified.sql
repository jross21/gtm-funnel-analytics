-- One row per lead, keyed on the stable HubSpot id. The Salesforce lead id comes
-- from the crosswalk via a LEFT join, so the ~8% of unmatched leads are KEPT and
-- flagged (is_crosswalk_matched) rather than silently dropped.

with contacts as (
    select * from {{ ref('stg_hs__contacts') }}
),

crosswalk as (
    select * from {{ ref('stg_hs__id_crosswalk') }}
)

select
    c.hs_contact_id as lead_id,
    c.hs_contact_id,
    crosswalk.sf_lead_id,
    (crosswalk.sf_lead_id is not null) as is_crosswalk_matched,
    c.email,
    c.account_name_freetext,
    c.segment,
    c.lead_source,
    c.hs_lead_score,
    c.lifecycle_stage_hs,
    c.country,
    c.created_at,
    c.is_internal
from contacts c
left join crosswalk
    on c.hs_contact_id = crosswalk.hs_contact_id
