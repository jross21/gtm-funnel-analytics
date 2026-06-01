-- Golden-value lock: every window/All metric must equal the value recorded in the
-- governed catalog. Because the data is deterministic (seed=42), these numbers are
-- stable — so this test fails the moment a metric definition silently drifts.

select
    v.metric_name,
    c.expected_window_value,
    v.value
from {{ ref('fct_metric_values') }} v
inner join {{ ref('dim_metric_catalog') }} c
    on v.metric_name = c.metric_name
where v.grain = 'window'
  and v.segment = 'All'
  and c.expected_window_value is not null
  and {{ assert_metric_equals('v.value', 'c.expected_window_value') }}
