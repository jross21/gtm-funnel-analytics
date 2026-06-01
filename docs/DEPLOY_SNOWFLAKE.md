# Deploying to Snowflake

The project is DuckDB-first for zero-setup reproducibility, but the SQL is written to be
Snowflake-portable. This is the path to run the same models on Snowflake.

## 1. Land the raw data

In DuckDB the 11 `raw_*` CSVs are loaded as seeds. On Snowflake you'd land them as raw
tables via your EL tool (Fivetran/Airbyte) or, for a quick demo, `dbt seed` against the
Snowflake target (seeds work on any adapter):

```bash
dbt seed --profiles-dir profiles --target snowflake
```

In this demo the raw tables are dbt **seeds** (referenced with `ref()`), so the project
clones and runs with no warehouse. In production, declare them as dbt **sources** with
`loaded_at_field: _synced_at` and a 12h warn / 24h error freshness policy, and
`dbt source freshness --target snowflake` checks real load timestamps (no anchor trick
needed). Point the staging models at the sources instead of the seeds.

## 2. Configure credentials (never committed)

`profiles/profiles.yml` ships a `snowflake` target that reads everything from env vars:

```bash
export SNOWFLAKE_ACCOUNT=...        SNOWFLAKE_USER=...
export SNOWFLAKE_PASSWORD=...       # or SNOWFLAKE_AUTHENTICATOR=externalbrowser
export SNOWFLAKE_ROLE=TRANSFORMER   SNOWFLAKE_DATABASE=ARCLINE
export SNOWFLAKE_WAREHOUSE=TRANSFORMING  SNOWFLAKE_SCHEMA=ANALYTICS
```

## 3. Build

```bash
dbt build --profiles-dir profiles --target snowflake
```

## SQL portability notes (what changes, and why it doesn't here)

| Concern | DuckDB | Snowflake | How this repo stays portable |
|---|---|---|---|
| Timezone conversion | `timezone(tz, ts)` | `convert_timezone(tz,'UTC',ts)` | isolated in `macros/to_utc.sql` (branches on `target.type`) |
| Date diff / trunc / add | `date_diff` etc. | `datediff` etc. | uses `dbt.datediff` / `dbt.date_trunc` / `dbt.dateadd` |
| Percentiles | `percentile_cont() within group` | same | one portable idiom used everywhere |
| Identifier casing | case-insensitive | upper-cases unquoted | everything is lower_snake_case |
| Schemas | flat `main` | layered schemas | set per-folder `+schema` in `dbt_project.yml` for Snowflake |

## 4. Powering Evidence from Snowflake

Swap `reports/sources/arcline/connection.yaml` to the Evidence Snowflake connector
(`@evidence-dev/snowflake`, add it to `reports/package.json`) and point it at the
`ANALYTICS` schema. The pages and queries are unchanged.
