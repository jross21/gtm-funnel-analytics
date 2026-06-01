"""Deterministic synthetic GTM source-data generator for Arcline Systems.

Run with:  python -m data_generator.generate

Everything is seeded (numpy + Faker) so re-running produces byte-identical CSVs.
The output lands in ../seeds/ and is committed, so dbt/CI never need to run this.
"""
