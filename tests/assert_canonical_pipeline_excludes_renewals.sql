-- Anything flagged as net-new pipeline must actually satisfy every KPI #5 exclusion:
-- New Business, not partner-sourced, positive USD amount, Stage >= 1. Encodes the
-- definition as an executable guard so the flag logic can't quietly drift.

select opp_id
from {{ ref('fct_opportunities') }}
where
    is_net_new_pipeline
    and (
        is_renewal_or_expansion
        or is_partner_sourced
        or coalesce(opp_amount, 0) <= 0
        or currency <> 'USD'
        or opp_stage_num < 1
    )
