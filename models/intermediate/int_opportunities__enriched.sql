-- Opportunity grain enriched with account segment + owner, plus the canonical
-- "net-new pipeline" eligibility flag that encodes KPI Dictionary #5 (Pipeline Created):
-- New Business, not partner-sourced, positive USD amount, Stage >= 1.

with opp as (
    select * from {{ ref('stg_sf__opportunities') }}
),

accounts as (
    select * from {{ ref('stg_sf__accounts') }}
),

users as (
    select * from {{ ref('stg_sf__users') }}
)

select
    opp.opp_id,
    opp.account_id,
    accounts.segment,
    opp.owner_id,
    users.role as owner_role,
    coalesce(users.is_active, false) as owner_is_active,
    opp.opp_name,
    opp.opp_stage,
    opp.opp_stage_num,
    opp.opp_amount,
    opp.currency,
    opp.opp_type,
    opp.lead_source,
    opp.is_partner_sourced,
    opp.is_renewal_or_expansion,
    opp.is_orphaned,
    opp.has_zero_or_null_amount,
    opp.is_non_usd,
    opp.is_test,
    opp.created_date,
    opp.close_date,
    cast({{ dbt.date_trunc('month', 'opp.created_date') }} as date) as created_month,
    cast({{ dbt.date_trunc('month', 'opp.close_date') }} as date) as close_month,
    opp.is_won,
    opp.is_closed,
    opp.source_hs_contact_id,
    (
        opp.opp_type = 'New Business'
        and not opp.is_partner_sourced
        and coalesce(opp.opp_amount, 0) > 0
        and opp.currency = 'USD'
        and not opp.is_test
        and opp.opp_stage_num >= 1
    ) as is_net_new_pipeline
from opp
left join accounts on opp.account_id = accounts.account_id
left join users on opp.owner_id = users.user_id
