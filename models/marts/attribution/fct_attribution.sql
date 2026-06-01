-- Multi-touch attribution of net-new pipeline to marketing campaigns.
-- Grain: opportunity x attribution_model x campaign. Three models:
--   first_touch  -> 100% credit to the earliest touch's campaign
--   last_touch   -> 100% credit to the latest pre-opp touch's campaign
--   linear       -> equal credit (opp_amount / touch_count) across all touches
-- Credit conserves: sum(attributed_amount) per opp x model = the opp's pipeline
-- (asserted by tests/assert_attribution_credit_conserved.sql).

with touches as (
    select * from {{ ref('int_attribution__opp_touches') }}
),

models as (
    select * from (values ('first_touch'), ('last_touch'), ('linear')) as t (attribution_model)
),

credited as (
    select
        touches.opp_id,
        touches.segment,
        touches.campaign,
        models.attribution_model,
        case models.attribution_model
            when 'first_touch' then case when touches.touch_rank = 1 then touches.opp_amount else 0 end
            when 'last_touch' then case when touches.touch_rank = touches.touch_count then touches.opp_amount else 0 end
            when 'linear' then touches.opp_amount / touches.touch_count
        end as attributed_amount
    from touches
    cross join models
)

select
    opp_id,
    segment,
    attribution_model,
    campaign,
    round(sum(attributed_amount), 2) as attributed_amount
from credited
group by opp_id, segment, attribution_model, campaign
