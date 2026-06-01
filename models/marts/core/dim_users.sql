with users as (
    select * from {{ ref('stg_sf__users') }}
)

select
    user_id,
    full_name,
    email,
    role,
    segment,
    timezone,
    is_active
from users
