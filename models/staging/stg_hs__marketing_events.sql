with src as (
    select * from {{ ref('raw_hs_marketing_events') }}
)

select
    event_id,
    hs_contact_id,
    event_type,
    event_at_utc,
    campaign,
    _synced_at as synced_at
from src
