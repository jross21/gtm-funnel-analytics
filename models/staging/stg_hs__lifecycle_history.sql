with src as (
    select * from {{ ref('raw_hs_lifecycle_history') }}
)

select
    hs_contact_id,
    lifecycle_stage,
    entered_at
from src
