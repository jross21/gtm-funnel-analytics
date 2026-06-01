{#-
  Returns a boolean predicate that is TRUE when two numeric expressions differ by more
  than `tolerance`. Used as the failure condition inside singular tests (a singular
  test fails when it returns rows), e.g. golden-value and reconciliation checks.
-#}
{% macro assert_metric_equals(actual, expected, tolerance=0.01) -%}
    abs(({{ actual }}) - ({{ expected }})) > {{ tolerance }}
{%- endmacro %}
