-- No test opportunity or internal/employee lead may leak into the canonical marts.

select 'fct_opportunities' as model, f.opp_id as id
from {{ ref('fct_opportunities') }} f
inner join {{ ref('int_opportunities__enriched') }} e on f.opp_id = e.opp_id
where e.is_test

union all

select 'fct_leads' as model, f.lead_id as id
from {{ ref('fct_leads') }} f
inner join {{ ref('int_leads__unified') }} u on f.lead_id = u.lead_id
where u.is_internal
