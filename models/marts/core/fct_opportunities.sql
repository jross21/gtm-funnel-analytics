-- Canonical opportunity fact. Powers Pipeline Created, Win Rate, and sales cycle.
--
-- Test records and rows with an unusable (null) amount are excluded here so the
-- downstream not_null(opp_amount) contract holds — those rows are surfaced on the
-- data-quality page instead. $0/non-USD opps are KEPT and flagged; the canonical
-- metric filters (is_net_new_pipeline) decide what each KPI counts.

with enriched as (
    select * from {{ ref('int_opportunities__enriched') }}
)

select
    opp_id,
    account_id,
    segment,
    owner_id,
    owner_role,
    opp_stage,
    opp_stage_num,
    opp_amount,
    currency,
    opp_type,
    lead_source,
    is_partner_sourced,
    is_renewal_or_expansion,
    coalesce(is_net_new_pipeline, false) as is_net_new_pipeline,
    has_zero_or_null_amount,
    is_non_usd,
    created_date,
    created_month,
    close_date,
    close_month,
    is_won,
    is_closed,
    case
        when is_won then {{ dbt.datediff('created_date', 'close_date', 'day') }}
    end as sales_cycle_days,
    source_hs_contact_id
from enriched
where
    not is_test
    and opp_amount is not null
