-- Date spine covering the data window plus room for cohort maturation.

with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2025-01-01' as date)",
        end_date="cast('2027-01-01' as date)"
    ) }}
)

select
    cast(date_day as date) as date_day,
    extract(year from date_day) as year,
    extract(month from date_day) as month,
    cast({{ dbt.date_trunc('month', 'date_day') }} as date) as month_start,
    extract(quarter from date_day) as quarter,
    cast(extract(year from date_day) as varchar) || '-Q' || cast(extract(quarter from date_day) as varchar) as fiscal_quarter
from spine
