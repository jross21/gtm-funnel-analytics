-- Freshness gate (anchored, not wall-clock): no source may be past its staleness SLA.
-- Fails if any source's most recent load is older than the error threshold.

select
    source_name,
    last_synced_at,
    age_hours,
    sla_error_hours
from {{ ref('rpt_source_freshness') }}
where freshness_status = 'Stale'
