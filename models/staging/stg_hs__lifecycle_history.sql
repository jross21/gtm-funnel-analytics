with src as (
    select * from {{ source('arcline_raw', 'raw_hs_lifecycle_history') }}
)

select
    hs_contact_id,
    lifecycle_stage,
    entered_at
from src
