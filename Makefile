# Developer convenience wrapper. All dbt commands pass --profiles-dir profiles so
# the checked-in DuckDB profile is used with no ~/.dbt setup.
DBT := dbt --profiles-dir profiles --target dev

.PHONY: setup seed-data build test docs site dev clean help

help:
	@echo "setup      - create venv, install python deps, dbt deps"
	@echo "seed-data  - regenerate the synthetic raw CSV seeds (deterministic)"
	@echo "build      - dbt build (seed + run + test) -> arcline.duckdb"
	@echo "test       - dbt test only"
	@echo "docs       - generate dbt docs (DAG + catalog)"
	@echo "site       - build the Evidence static site"
	@echo "dev        - run the Evidence dev server"
	@echo "clean      - remove dbt artifacts and the DuckDB file"

setup:
	python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt && $(DBT) deps

seed-data:
	python3 -m data_generator.generate

build:
	$(DBT) deps
	$(DBT) build

test:
	$(DBT) test

docs:
	$(DBT) docs generate

site:
	cd reports && npm ci && npm run build

dev:
	cd reports && npm run dev

clean:
	$(DBT) clean
	rm -f arcline.duckdb arcline.duckdb.wal
