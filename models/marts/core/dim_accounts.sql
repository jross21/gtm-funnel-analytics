with accounts as (
    select * from {{ ref('stg_sf__accounts') }}
)

select
    account_id,
    account_name,
    segment,
    industry,
    country,
    employee_count,
    created_date,
    is_test
from accounts
