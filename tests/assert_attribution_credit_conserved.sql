-- Attribution must not create or destroy pipeline: for every opportunity and model,
-- the credit spread across campaigns must equal the opp's net-new pipeline amount
-- (small tolerance for linear-split rounding).

with by_opp_model as (
    select
        opp_id,
        attribution_model,
        sum(attributed_amount) as total_attributed
    from {{ ref('fct_attribution') }}
    group by opp_id, attribution_model
)

select
    by_opp_model.opp_id,
    by_opp_model.attribution_model,
    by_opp_model.total_attributed,
    opps.opp_amount
from by_opp_model
inner join {{ ref('fct_opportunities') }} as opps
    on by_opp_model.opp_id = opps.opp_id
where abs(by_opp_model.total_attributed - opps.opp_amount) > 0.05
