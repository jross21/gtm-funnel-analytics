{#-
  Convert a naive (no-offset) local timestamp to a naive UTC timestamp, given an
  IANA timezone. Dialect-specific bits live here so the models stay portable.

  Used by int_activities__first_touch: Salesforce logs activity time in the rep's
  local wall-clock, while HubSpot events are UTC — normalize before comparing.
-#}
{% macro to_utc(ts_col, tz_col) -%}
    {%- if target.type == 'snowflake' -%}
        convert_timezone({{ tz_col }}, 'UTC', {{ ts_col }})
    {%- else -%}
        timezone('UTC', timezone({{ tz_col }}, {{ ts_col }}))
    {%- endif -%}
{%- endmacro %}
