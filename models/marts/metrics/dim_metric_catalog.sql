-- Queryable projection of metrics_catalog.yml (the governed contract, at repo root).
-- Powers
-- the Evidence metric-catalog page, and carries each metric's golden window value
-- (segment 'All', seed=42) which the assert_metric_values_match_catalog test locks.
--
-- If a metric definition changes, this expected value and the YAML are updated in the
-- same commit — that diff IS the audit trail for a metric-definition change.

select * from (
    values
    -- metric_name, label, kpi_dictionary_ref, definition, grain, owner, source_systems, freshness_sla, expected_window_value
    (
        'mql_volume', 'MQL Volume', '08 #1',
        'Count of first-time canonical MQLs (lead score >= 50); excludes test/internal/merged-duplicate leads.',
        'lead / daily', 'Marketing Ops', 'HubSpot', 'Daily by 6:30am ET', 2546.0
    ),

    (
        'mql_to_sal_rate', 'MQL -> SAL Conversion', '08 #2',
        'Share of MQLs that reach SAL (same-cohort).',
        'lead cohort / monthly', 'RevOps', 'HubSpot + Salesforce', 'Daily', 0.5518
    ),

    (
        'speed_to_lead_median_min', 'Speed-to-Lead (median min)', '08 #3',
        'Median minutes from canonical MQL to first rep activity (UTC-normalized).',
        'lead / daily', 'RevOps', 'Salesforce', 'Daily', 6.0
    ),

    (
        'sal_to_sql_rate', 'SAL -> SQL Conversion', '08 #4',
        'Share of SALs that reach SQL (same-cohort).',
        'lead cohort / monthly', 'RevOps', 'Salesforce', 'Daily', 0.4641
    ),

    (
        'pipeline_created', 'Pipeline Created', '08 #5',
        'Sum of opp_amount for net-new opps created in period at Stage >= 1; excludes renewals, partner-sourced, $0/non-USD.',
        'opportunity / weekly', 'Sales Ops', 'Salesforce', 'Daily by 5:30am ET', 6884381.39
    ),

    (
        'sql_to_opp_rate', 'SQL -> Opportunity Conversion', '08 #5',
        'Share of SQLs that convert to an Opportunity.',
        'lead cohort / monthly', 'RevOps', 'Salesforce', 'Daily', 0.7331
    ),

    (
        'win_rate', 'Win Rate', '08 #7',
        'Closed Won / (Closed Won + Closed Lost); excludes opps open < 7 days and amount < $1k.',
        'opportunity / quarterly', 'Sales Ops', 'Salesforce', 'Daily', 0.3303
    ),

    (
        'avg_sales_cycle_days', 'Average Sales Cycle (days)', '08 #8',
        'Median days from opportunity creation to Closed Won.',
        'opportunity / quarterly', 'Sales Ops', 'Salesforce', 'Weekly', 38.0
    ),

    (
        'sla_compliance', 'SLA Compliance', '08 #9',
        'Share of MQLs whose first rep activity met the segment response SLA (SMB 5m / MM 15m / Ent 1h).',
        'lead / weekly', 'RevOps', 'Salesforce', 'Daily', 0.6329
    )
) as t (
    metric_name, label, kpi_dictionary_ref, definition, grain, owner,
    source_systems, freshness_sla, expected_window_value
)
