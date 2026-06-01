with src as (
    select * from {{ ref('raw_sf_opportunities') }}
),

-- Dedupe the injected duplicates (same business key, different opp_id): keep the
-- first opp_id per (account, opp_name, created_date). Real opps have unique names.
deduped as (
    select
        *,
        row_number() over (
            partition by account_id, opp_name, created_date
            order by opp_id
        ) as rn
    from src
)

select
    opp_id,
    account_id,
    nullif(owner_id, '') as owner_id,
    opp_name,
    opp_stage,
    opp_stage_num,
    opp_amount,
    currency,
    opp_type,
    nullif(lead_source, '') as lead_source,
    coalesce(is_partner_sourced, false) as is_partner_sourced,
    created_date,
    close_date,
    coalesce(is_won, false) as is_won,
    coalesce(is_closed, false) as is_closed,
    coalesce(is_test, false) as is_test,
    nullif(source_hs_contact_id, '') as source_hs_contact_id,
    nullif(source_sf_lead_id, '') as source_sf_lead_id,
    -- cleaning flags consumed downstream / by tests
    (opp_type <> 'New Business') as is_renewal_or_expansion,
    (nullif(owner_id, '') is null) as is_orphaned,
    (opp_amount is null) as has_null_amount,
    (coalesce(opp_amount, 0) = 0) as has_zero_or_null_amount,
    (currency <> 'USD') as is_non_usd,
    _synced_at as synced_at
from deduped
where rn = 1
