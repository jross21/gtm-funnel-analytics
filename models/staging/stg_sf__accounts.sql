with src as (
    select * from {{ ref('raw_sf_accounts') }}
),

segment_map as (
    select * from {{ ref('raw_ref_segment_map') }}
)

select
    src.account_id,
    src.account_name,
    -- Resolve the messy raw label via the crosswalk; fall back on employee_count
    -- when the label is blank so every account lands in a canonical segment.
    coalesce(
        segment_map.segment_canonical,
        case
            when src.employee_count < 200 then 'SMB'
            when src.employee_count < 2000 then 'Mid-Market'
            else 'Enterprise'
        end
    ) as segment,
    nullif(trim(src.segment_raw), '') as segment_raw,
    src.industry,
    src.country,
    src.employee_count,
    src.created_date,
    coalesce(src.is_test, false) as is_test,
    src._synced_at as synced_at
from src
left join segment_map
    on nullif(trim(src.segment_raw), '') = segment_map.segment_raw
