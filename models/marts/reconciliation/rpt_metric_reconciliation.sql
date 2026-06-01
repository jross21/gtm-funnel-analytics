-- THE SHOWPIECE. "Which number is right?" in one table: for a headline metric, every
-- team's number next to the canonical number, with the gap quantified and — crucially —
-- a reason for the gap and the owner of the fix. Every delta is explained.

with pipeline_variants as (
    select * from {{ ref('int_pipeline__naive_variants') }}
),

metrics as (
    select metric_name, value
    from {{ ref('fct_metric_values') }}
    where grain = 'window' and segment = 'All'
),

canon_pipeline as (
    select value from metrics where metric_name = 'pipeline_created'
),

canon_mql as (
    select value from metrics where metric_name = 'mql_volume'
),

hubspot_mql as (
    select count(*)::double as value
    from {{ ref('stg_hs__contacts') }}
    where hs_lead_score >= {{ var('mql_threshold_naive_hubspot') }}
      and not is_internal
)

-- Pipeline Created: 4 naive variants vs canonical
select
    'pipeline_created' as metric_name,
    'Pipeline Created' as metric_label,
    v.variant_key,
    v.variant_label,
    v.source_team,
    v.variant_value,
    c.value as canonical_value,
    round(v.variant_value - c.value, 2) as abs_delta,
    round((v.variant_value - c.value) / nullif(c.value, 0), 4) as pct_delta,
    v.divergence_reason,
    v.fix_owner
from pipeline_variants v
cross join canon_pipeline c

union all
-- Pipeline Created: the canonical answer itself
select
    'pipeline_created', 'Pipeline Created', 'canonical', 'Canonical (this repo)', 'RevOps',
    c.value, c.value, 0, 0,
    'Net-new only: Stage >= 1, created in period; excludes renewals, partner-sourced, $0/non-USD, test, and duplicates. KPI Dictionary #5.',
    'RevOps'
from canon_pipeline c

union all
-- MQL Volume: HubSpot (>=40) vs canonical (>=50)
select
    'mql_volume', 'MQL Volume', 'hubspot_40', 'Marketing (HubSpot)', 'Marketing Ops',
    h.value, m.value,
    round(h.value - m.value, 2), round((h.value - m.value) / nullif(m.value, 0), 4),
    'HubSpot marks MQL at lead score >= 40; the canonical threshold is >= 50, so HubSpot reports ~15% more MQLs.',
    'Marketing Ops'
from hubspot_mql h
cross join canon_mql m

union all
select
    'mql_volume', 'MQL Volume', 'canonical', 'Canonical (this repo)', 'RevOps',
    m.value, m.value, 0, 0,
    'First-time MQLs at the canonical lead-score threshold (>= 50); excludes test/internal/merged duplicates. KPI Dictionary #1.',
    'RevOps'
from canon_mql m
