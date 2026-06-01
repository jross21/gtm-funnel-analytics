-- Canonical MQL fact (KPI Dictionary #1): one row per first-time canonical MQL
-- (lead score >= 50), excluding test/internal/merged-duplicate leads. Cohorted by
-- MQL month for cohort analysis.

with leads as (
    select * from {{ ref('fct_leads') }}
)

select
    lead_id as mql_event_id,
    lead_id,
    segment,
    lead_source,
    mql_at,
    cast({{ dbt.date_trunc('month', 'mql_at') }} as date) as cohort_month
from leads
where is_mql
