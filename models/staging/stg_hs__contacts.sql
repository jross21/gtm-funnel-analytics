with src as (
    select * from {{ ref('raw_hs_contacts') }}
),

segment_map as (
    select * from {{ ref('raw_ref_segment_map') }}
),

-- Dedupe contacts merged within HubSpot: same email, different hs_contact_id.
deduped as (
    select
        *,
        row_number() over (
            partition by lower(email)
            order by created_at, hs_contact_id
        ) as rn
    from src
)

select
    deduped.hs_contact_id,
    lower(deduped.email) as email,
    deduped.account_name_freetext,
    deduped.lifecycle_stage_hs,
    deduped.hs_lead_score,
    -- Normalize the messy raw source labels to the canonical 7.
    case
        when lower(trim(deduped.lead_source_hs)) in ('inbound', 'ib') then 'Inbound'
        when lower(trim(deduped.lead_source_hs)) in ('outbound', 'cold outreach') then 'Outbound'
        when lower(trim(deduped.lead_source_hs)) in ('partner', 'channel') then 'Partner'
        when lower(trim(deduped.lead_source_hs)) in ('event', 'trade show') then 'Event'
        when lower(trim(deduped.lead_source_hs)) in ('referral', 'word of mouth') then 'Referral'
        when lower(trim(deduped.lead_source_hs)) in ('content', 'content download') then 'Content'
        when lower(trim(deduped.lead_source_hs)) in ('paid', 'paid ads', 'ppc') then 'Paid'
        else 'Inbound'
    end as lead_source,
    coalesce(segment_map.segment_canonical, 'SMB') as segment,
    deduped.country,
    deduped.created_at,
    coalesce(deduped.is_internal, false) as is_internal,
    deduped._synced_at as synced_at
from deduped
left join segment_map
    on nullif(trim(deduped.segment_raw_hs), '') = segment_map.segment_raw
where deduped.rn = 1
