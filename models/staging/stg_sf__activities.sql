with src as (
    select * from {{ source('arcline_raw', 'raw_sf_activities') }}
)

select
    activity_id,
    lead_id,
    owner_id,
    activity_type,
    -- Naive rep-local wall-clock. UTC normalization needs the rep's timezone, so it
    -- happens in int_activities__first_touch (which joins users), not here.
    activity_at as activity_at_local,
    _synced_at as synced_at
from src
