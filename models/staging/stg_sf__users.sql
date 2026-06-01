with src as (
    select * from {{ ref('raw_sf_users') }}
),

segment_map as (
    select * from {{ ref('raw_ref_segment_map') }}
)

select
    src.user_id,
    src.full_name,
    src.email,
    src.role,
    coalesce(segment_map.segment_canonical, 'SMB') as segment,
    src.timezone,
    coalesce(src.is_active, false) as is_active,
    src._synced_at as synced_at
from src
left join segment_map
    on nullif(trim(src.segment_raw), '') = segment_map.segment_raw
