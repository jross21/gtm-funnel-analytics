-- Source freshness, measured against the build anchor ("today") rather than wall-clock.
--
-- Real pipelines compare loaded_at to now(); but committed static seeds would then be
-- permanently "stale" and fail CI. So we anchor "now" to build_anchor_date (noon) and
-- check recency against that. The pattern (max loaded_at vs an SLA) is identical to
-- production — only the clock is fixed. In a real deployment the raw tables are sources
-- (not seeds) and `dbt source freshness` checks loaded_at against now() — see
-- docs/DEPLOY_SNOWFLAKE.md.

{% set as_of = "(cast('" ~ var('build_anchor_date') ~ "' as timestamp) + interval '12 hours')" %}
{% set warn_hours = 12 %}
{% set error_hours = 24 %}

with sources as (
    select 'raw_sf_opportunities' as source_name, max(_synced_at) as last_synced_at from {{ ref('raw_sf_opportunities') }}
    union all select 'raw_sf_opportunity_stage_history', max(_synced_at) from {{ ref('raw_sf_opportunity_stage_history') }}
    union all select 'raw_sf_accounts', max(_synced_at) from {{ ref('raw_sf_accounts') }}
    union all select 'raw_sf_users', max(_synced_at) from {{ ref('raw_sf_users') }}
    union all select 'raw_sf_activities', max(_synced_at) from {{ ref('raw_sf_activities') }}
    union all select 'raw_hs_contacts', max(_synced_at) from {{ ref('raw_hs_contacts') }}
    union all select 'raw_hs_marketing_events', max(_synced_at) from {{ ref('raw_hs_marketing_events') }}
    union all select 'raw_hs_lead_score_history', max(_synced_at) from {{ ref('raw_hs_lead_score_history') }}
)

select
    source_name,
    last_synced_at,
    {{ as_of }} as as_of,
    {{ dbt.datediff('last_synced_at', as_of, 'hour') }} as age_hours,
    {{ warn_hours }} as sla_warn_hours,
    {{ error_hours }} as sla_error_hours,
    case
        when {{ dbt.datediff('last_synced_at', as_of, 'hour') }} > {{ error_hours }} then 'Stale'
        when {{ dbt.datediff('last_synced_at', as_of, 'hour') }} > {{ warn_hours }} then 'Warn'
        else 'Fresh'
    end as freshness_status
from sources
