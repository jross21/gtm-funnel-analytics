with src as (
    select * from {{ ref('raw_ref_id_crosswalk') }}
)

select
    hs_contact_id,
    nullif(sf_lead_id, '') as sf_lead_id,
    match_confidence,
    -- ~8% of rows have no usable sf_lead_id; an INNER join here silently drops them
    -- (the "Looker is always lower" undercount the reconciliation page exposes).
    (nullif(sf_lead_id, '') is null) as is_unmatched
from src
