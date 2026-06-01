"""Entrypoint: build all raw tables deterministically and write them to ../seeds/.

    python -m data_generator.generate
"""

from __future__ import annotations

import os

import numpy as np
from faker import Faker

from . import config as C
from . import dimensions, journeys, mess, writers

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEEDS_DIR = os.path.join(REPO_ROOT, "seeds")


def main() -> None:
    rng = np.random.default_rng(C.SEED)
    faker = Faker("en_US")
    faker.seed_instance(C.SEED)

    users = dimensions.build_users(rng, faker)
    accounts = dimensions.build_accounts(rng, faker)
    segment_map = dimensions.build_segment_map()

    tables = journeys.build_journeys(rng, faker, users, accounts)
    tables["users"] = users
    tables["accounts"] = accounts
    tables["segment_map"] = segment_map

    mess.apply_defects(rng, tables, accounts, users)

    counts = writers.write_all(tables, SEEDS_DIR)
    _print_summary(counts, tables)


def _print_summary(counts, tables) -> None:
    print(f"Wrote {len(counts)} seeds to {SEEDS_DIR}:")
    for name in sorted(counts):
        print(f"  {name:40s} {counts[name]:>7,} rows")

    contacts = tables["contacts"]
    opps = tables["opportunities"]
    canon = sum(1 for c in contacts if int(c["hs_lead_score"]) >= C.MQL_SCORE_CANONICAL)
    hs = sum(1 for c in contacts if int(c["hs_lead_score"]) >= C.MQL_SCORE_HUBSPOT)
    funnel_opps = [o for o in opps if o["source_hs_contact_id"]]
    renewals = [o for o in opps if o["opp_type"] in ("Renewal", "Expansion")]
    closed = [o for o in opps if o["is_closed"] == "true"]
    won = [o for o in closed if o["is_won"] == "true"]
    print("\nFunnel sanity check (raw, pre-cleaning):")
    print(f"  contacts                 {len(contacts):>7,}")
    print(f"  canonical MQLs (>=50)    {canon:>7,}")
    print(f"  HubSpot MQLs (>=40)      {hs:>7,}   (+{(hs/canon-1)*100:.1f}% vs canonical)")
    print(f"  funnel opportunities     {len(funnel_opps):>7,}")
    print(f"  renewal/expansion opps   {len(renewals):>7,}")
    print(f"  closed opps              {len(closed):>7,}")
    print(f"  won opps                 {len(won):>7,}   (win rate {len(won)/max(len(closed),1)*100:.1f}%)")


if __name__ == "__main__":
    main()
