# GTM Funnel Analytics

[![CI](https://github.com/jross21/gtm-funnel-analytics/actions/workflows/ci.yml/badge.svg)](https://github.com/jross21/gtm-funnel-analytics/actions/workflows/ci.yml)

**The analytics-engineering layer that turns a KPI Dictionary into tested, governed,
reproducible metrics — and resolves the "four dashboards, four numbers" problem in code.**

A dbt project over synthetic Salesforce + HubSpot funnel data for *Arcline Systems* (a
fictional $15M-ARR B2B SaaS), with a code-first Evidence.dev dashboard. It runs on DuckDB
with **zero setup** (`git clone && dbt build`) and is **Snowflake-portable**.

🔗 **Live dashboard:** https://jross21.github.io/gtm-funnel-analytics/ &nbsp;·&nbsp; [Which number is right?](https://jross21.github.io/gtm-funnel-analytics/which-number-is-right)

[![GTM Funnel Analytics — the reconciliation showpiece](docs/assets/dashboard-hero.png)](https://jross21.github.io/gtm-funnel-analytics/which-number-is-right)

## What it does

Arcline had four dashboards showing "pipeline created." None agreed — Sales, Marketing,
Finance, and the data team each computed it a slightly different (wrong) way. The
[KPI Dictionary](https://github.com/jross21/RevOps_Portfolio/tree/main/artifacts/08-kpi-dictionary)
says *what* the metrics should be; this project proves *how* you build, test, and govern
them at scale — and reproduces the divergence, then resolves it to one canonical number:

| Reported by | "Pipeline Created" | vs canonical | Why it differs |
|---|---:|---:|---|
| Sales (Salesforce report) | $13.4M | **+95%** | no exclusions: renewals + partner + $0 + duplicates |
| Finance (spreadsheet) | $8.3M | +20% | buckets by `close_date`, includes renewals |
| **Canonical (this repo)** | **$6.88M** | — | net-new, Stage ≥ 1, exclusions applied (KPI #5) |
| Data team (Looker) | $6.3M | −8% | INNER-joins a broken id crosswalk |
| Marketing (HubSpot) | $4.5M | −35% | marketing-sourced only, MQL threshold 40 not 50 |

Every gap has a **reason** and an **owner**, and a dbt test fails the build if any gap is
left unexplained.

## Quickstart (no cloud account)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
dbt deps
dbt build --profiles-dir profiles        # seed + run + test -> arcline.duckdb

# code-first dashboard (live-reload at http://localhost:3000)
cd reports && npm install && npm run dev
```

Regenerate the synthetic source data (deterministic, `seed=42`): `make seed-data`.

## How it works

```
seeds/ (raw CSVs) → staging → intermediate → marts (core · funnel · metrics · reconciliation · attribution)
                                                   → Evidence.dev → GitHub Pages
```

- **Synthetic data with teeth.** A deterministic generator emits 11 raw tables with
  realistic, *deliberate* data-quality defects (duplicates, null owners, inconsistent
  segment labels, UTC-vs-local timestamps, a HubSpot MQL-threshold drift, an ~8% broken
  id crosswalk). The mess is the point — it gives the staging models real work and the
  tests something to catch. See [`data_generator/README.md`](data_generator/README.md).
- **Governed metrics.** Each KPI is defined once in [`metrics_catalog.yml`](metrics_catalog.yml),
  implemented once in `fct_metric_values`, and **locked** by a test asserting the computed
  value equals the catalog's golden value (deterministic data → stable numbers).
- **The reconciliation showpiece.** `rpt_metric_reconciliation` computes the headline
  metric every team's way, quantifies each gap, and names the fix owner — see the
  [live page](https://jross21.github.io/gtm-funnel-analytics/which-number-is-right).

Architecture + lineage: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Features

- **DuckDB-first, Snowflake-portable** — clone-and-run in seconds, green in CI; dialect
  bits isolated in macros ([deploy path](docs/DEPLOY_SNOWFLAKE.md)).
- **Three funnel marts** — conversion (stage × segment), stage velocity (median/avg/p90),
  monthly cohort progression (ragged triangle, immature cohorts left blank).
- **Multi-touch attribution** — first / last / linear-touch credit of net-new pipeline to
  campaigns, with a credit-conservation test and its own
  [dashboard page](https://jross21.github.io/gtm-funnel-analytics/attribution).
- **Versioned metric catalog** with golden-value locking; MetricFlow-shaped for a v2 port.
- **Meaningful test suite** — generic + `dbt_utils` + bespoke singular tests + **dbt unit
  tests** on the gnarly transforms (dedupe, net-new flag, UTC normalization, attribution).
- **Linted & locked** — sqlfluff + pre-commit; exactly-pinned deps; and a golden-value
  test that fails the build if any canonical metric drifts from its catalog value.
- **Code-first BI** — Evidence.dev compiles SQL + markdown to a static site on GitHub Pages.
- **CI/CD** — every push runs sqlfluff → strict `dbt build --warn-error` (seed → run →
  test) → builds & deploys the site.

## Project structure

```
data_generator/   deterministic synthetic-data generator (seed=42)
seeds/            11 committed raw_* CSVs
models/           staging → intermediate → marts (core·funnel·metrics·reconciliation·attribution·monitoring)
                  + _unit_tests.yml (dbt unit tests) and exposures.yml (dashboard lineage)
metrics_catalog.yml   governed metric contract (golden values)
macros/ tests/    portability macros + bespoke singular tests
reports/          Evidence.dev site (pages + duckdb source)
docs/             architecture, Snowflake deploy, data dictionary, dashboard screenshot
.sqlfluff · .pre-commit-config.yaml · requirements-dev.txt   SQL linting + dev tooling
.github/workflows/ci.yml   sqlfluff → dbt build (strict) → Evidence → Pages
```

## Roadmap

- Migrate the metric catalog to the **dbt Semantic Layer / MetricFlow** (the YAML is
  already MetricFlow-shaped, so it's a port).
- Incremental models + snapshots for late-arriving stage history (CDC).
- Elementary for data observability; a live Fivetran/Snowflake sync path.

## Built with

dbt-core + dbt-duckdb · DuckDB · dbt_utils · Evidence.dev · GitHub Actions / Pages ·
Python + Faker (generator).

---

*Project #3 in a RevOps / GTM-Engineering portfolio. Conventions shared with sibling repos
and grounded in the Arcline Systems KPI Dictionary (#08).*
