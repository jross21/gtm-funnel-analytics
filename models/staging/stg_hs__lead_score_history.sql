with src as (
    select * from {{ ref('raw_hs_lead_score_history') }}
)

select
    score_event_id,
    hs_contact_id,
    old_score,
    new_score,
    changed_at,
    _synced_at as synced_at
from src
