-- Campaign x model rollup for the attribution dashboard. segment 'All' is the blend.

with attribution as (
    select * from {{ ref('fct_attribution') }}
)

select
    attribution_model,
    coalesce(segment, 'All') as segment,
    campaign,
    round(sum(attributed_amount), 2) as attributed_pipeline,
    count(distinct opp_id) as opps
from attribution
group by grouping sets (
    (attribution_model, segment, campaign),
    (attribution_model, campaign)
)
