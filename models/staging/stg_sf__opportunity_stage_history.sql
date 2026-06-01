with src as (
    select * from {{ source('arcline_raw', 'raw_sf_opportunity_stage_history') }}
)

select
    history_id,
    opp_id,
    from_stage_num,
    to_stage_num,
    changed_at,
    changed_by,
    -- A stage change timestamped after the sync batch that loaded it is a
    -- clock/integration anomaly worth flagging (defect #6).
    (changed_at > _synced_at) as is_late_arriving,
    _synced_at as synced_at
from src
