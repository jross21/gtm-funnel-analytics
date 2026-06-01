-- First rep touch per lead, normalized to UTC. Salesforce logs activity time in the
-- rep's local wall-clock, so we join the rep's timezone and convert via to_utc()
-- before this can be compared to the UTC MQL timestamp (speed-to-lead / SLA).

with activities as (
    select * from {{ ref('stg_sf__activities') }}
),

users as (
    select
        user_id,
        timezone
    from {{ ref('stg_sf__users') }}
),

normalized as (
    select
        activities.activity_id,
        activities.lead_id,
        activities.owner_id,
        {{ to_utc('activities.activity_at_local', 'users.timezone') }} as activity_at_utc
    from activities
    left join users on activities.owner_id = users.user_id
),

ranked as (
    select
        *,
        row_number() over (partition by lead_id order by activity_at_utc) as rn
    from normalized
)

select
    lead_id,
    owner_id,
    activity_at_utc as first_activity_at_utc
from ranked
where rn = 1
