-- Every divergent number must be EXPLAINED: a non-null delta, a reason, and an owner.
-- A mystery gap (any null) fails this test — "we don't know why it differs" is not allowed.

select *
from {{ ref('rpt_metric_reconciliation') }}
where variant_key <> 'canonical'
  and (
        abs_delta is null
     or canonical_value is null
     or divergence_reason is null
     or fix_owner is null
  )
