-- The four naive "Pipeline Created" numbers, each computed the way a different team's
-- dashboard actually computes it — so each is wrong in a specific, documented way.
-- The canonical number lives in fct_metric_values; rpt_metric_reconciliation compares.

{% set ws = "cast('" ~ var('analysis_period_start') ~ "' as date)" %}
{% set we = "cast('" ~ var('analysis_period_end') ~ "' as date)" %}

with raw_opps as (
    -- read the RAW seed (pre-dedupe) so the duplicate records inflate this number
    select * from {{ ref('raw_sf_opportunities') }}
),
stg_opps as (
    select * from {{ ref('stg_sf__opportunities') }}
),
enriched as (
    select * from {{ ref('int_opportunities__enriched') }}
),
contacts as (
    select * from {{ ref('stg_hs__contacts') }}
),
crosswalk as (
    select * from {{ ref('stg_hs__id_crosswalk') }}
)

select
    'sales' as variant_key,
    'Sales (Salesforce report)' as variant_label,
    'Sales Ops' as source_team,
    'Counts every created opp with no exclusions — includes renewals, partner-sourced, $0/trial, and duplicate records.' as divergence_reason,
    'Sales Ops' as fix_owner,
    round((
        select sum(opp_amount) from raw_opps
        where created_date between {{ ws }} and {{ we }} and not coalesce(is_test, false)
    ), 2) as variant_value

union all
select
    'marketing',
    'Marketing (HubSpot dashboard)',
    'Marketing Ops',
    'Counts only marketing-sourced opps and tags MQLs at score >= 40 (not the canonical 50) — a scope + threshold mismatch.',
    'Marketing Ops',
    round((
        select sum(o.opp_amount)
        from stg_opps o
        inner join contacts c on o.source_hs_contact_id = c.hs_contact_id
        where o.created_date between {{ ws }} and {{ we }}
          and o.lead_source in ('Inbound', 'Event', 'Content', 'Paid')
          and c.hs_lead_score >= {{ var('mql_threshold_naive_hubspot') }}
          and not o.is_test
    ), 2)

union all
select
    'finance',
    'Finance (spreadsheet)',
    'Finance',
    'Buckets by close_date instead of created_date and includes renewals — measures what closed, not what was created.',
    'Finance',
    round((
        select sum(opp_amount) from stg_opps
        where close_date between {{ ws }} and {{ we }} and not is_test
    ), 2)

union all
select
    'data_team',
    'Data team (Looker / broken join)',
    'Data Eng',
    'Uses the right filters but INNER-joins the hs<->sf crosswalk, silently dropping the ~8% of opps whose lead id is unmapped.',
    'Data Eng',
    round((
        select sum(o.opp_amount)
        from enriched o
        inner join crosswalk x on o.source_hs_contact_id = x.hs_contact_id
        where o.is_net_new_pipeline
          and o.created_date between {{ ws }} and {{ we }}
          and x.sf_lead_id is not null
    ), 2)
