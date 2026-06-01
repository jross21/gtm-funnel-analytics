"""All generation knobs in one place.

The funnel is score-driven and segment-skewed so the marts produce believable
numbers, and a small set of deliberate data-quality defects (see mess.py) is layered
on top so the staging models and dbt tests have real work to do.
"""

from datetime import date

SEED = 42

# Calendar. Data is static, so we treat a fixed date as "today". The window leaves
# the earliest cohorts fully mature by the anchor.
WINDOW_START = date(2025, 9, 1)
WINDOW_END = date(2026, 3, 31)
ANCHOR_DATE = date(2026, 4, 1)  # "today" — keep in sync with dbt_project.yml build_anchor_date

# Volumes
N_USERS = 40
N_ACCOUNTS = 1200
N_CONTACTS = 6000
N_RENEWAL_OPPS = 140          # renewals/expansions NOT born from the lead funnel

# ---------------------------------------------------------------------------
# Canonical reference values (mirror artifacts/08-kpi-dictionary)
# ---------------------------------------------------------------------------
SEGMENTS = ["SMB", "Mid-Market", "Enterprise"]
ROLES = ["SDR", "AE", "AM"]
LEAD_SOURCES = ["Inbound", "Outbound", "Partner", "Event", "Referral", "Content", "Paid"]
MARKETING_SOURCES = ["Inbound", "Event", "Content", "Paid"]   # "marketing-sourced" per Marketing's view

# Lead lifecycle stages (fct_leads accepted_values) and opportunity sales stages.
LIFECYCLE_STAGES = ["New", "MQL", "SAL", "SQL", "Opportunity", "Closed Won", "Closed Lost"]
FUNNEL_STAGES = ["MQL", "SAL", "SQL", "Opportunity"]  # the conversion funnel proper
OPP_SALES_STAGES = {
    0: "Prospecting",   # pre-pipeline; EXCLUDED from Pipeline Created (stage < 1)
    1: "Discovery",
    2: "Demo",
    3: "Proposal",
    4: "Negotiation",
    5: "Closed Won",
    6: "Closed Lost",
}

# Canonical MQL lead-score threshold; HubSpot drifted to a lower one (the headline defect).
MQL_SCORE_CANONICAL = 50
MQL_SCORE_HUBSPOT = 40

# Per-segment SLA for speed-to-lead, in minutes (artifacts/08 KPI #9).
SLA_MINUTES = {"SMB": 5, "Mid-Market": 15, "Enterprise": 60}

REP_TIMEZONES = [
    "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
]

# ---------------------------------------------------------------------------
# Funnel shape
# ---------------------------------------------------------------------------
# Share of contact volume by segment (SMB heavy, Enterprise light but high-ACV).
SEGMENT_WEIGHTS = {"SMB": 0.60, "Mid-Market": 0.28, "Enterprise": 0.12}

# P(reach canonical MQL | contact) by segment (score >= 50).
MQL_RATE = {"SMB": 0.45, "Mid-Market": 0.40, "Enterprise": 0.35}
# Of contacts that DON'T reach canonical MQL, the share that still peak in [40,50)
# — i.e. HubSpot MQLs but not canonical. Tuned so HubSpot counts ~15% more MQLs.
HUBSPOT_ONLY_MQL_RATE = 0.11

# Step conversion among canonical MQLs, by segment.
CONV_MQL_SAL = {"SMB": 0.58, "Mid-Market": 0.55, "Enterprise": 0.50}
CONV_SAL_SQL = {"SMB": 0.52, "Mid-Market": 0.50, "Enterprise": 0.46}
CONV_SQL_OPP = {"SMB": 0.72, "Mid-Market": 0.70, "Enterprise": 0.65}
# Win rate among CLOSED opps, by segment.
WIN_RATE = {"SMB": 0.28, "Mid-Market": 0.33, "Enterprise": 0.38}

# Median stage durations in days (lognormal, right-skewed so median != mean).
DUR_NEW_MQL = {"SMB": 6, "Mid-Market": 8, "Enterprise": 11}
DUR_MQL_SAL = {"SMB": 1, "Mid-Market": 2, "Enterprise": 4}
DUR_SAL_SQL = {"SMB": 3, "Mid-Market": 6, "Enterprise": 12}
DUR_SQL_OPP = {"SMB": 5, "Mid-Market": 10, "Enterprise": 20}
DUR_OPP_CLOSE = {"SMB": 25, "Mid-Market": 55, "Enterprise": 95}
DURATION_SIGMA = 0.5  # lognormal sigma for all stage durations

# ACV (opp amount) by segment — lognormal, median in USD.
ACV_MEDIAN = {"SMB": 5000, "Mid-Market": 24000, "Enterprise": 80000}
ACV_SIGMA = 0.5

# Speed-to-lead: median minutes from MQL to first rep activity (lognormal). Most beat
# the SLA, a realistic tail misses it.
RESPONSE_MEDIAN_MIN = {"SMB": 4, "Mid-Market": 12, "Enterprise": 45}
RESPONSE_SIGMA = 0.9

# ---------------------------------------------------------------------------
# Deliberate data-quality defects (see data_generator/README.md for the ledger).
# Each rate is a knob so the mess is explicit and documented.
# ---------------------------------------------------------------------------
DEFECT_DUP_OPP_RATE = 0.015          # #1  duplicate opportunities (different opp_id, same business key)
DEFECT_DUP_CONTACT_RATE = 0.02       # #2  duplicate HubSpot contacts (same email)
DEFECT_NULL_OWNER_RATE = 0.03        # #3  opps with blank owner_id
DEFECT_INACTIVE_OWNER_RATE = 0.04    # #3  opps owned by an inactive rep
DEFECT_NULL_SEGMENT_RATE = 0.05      # #4  accounts with a blank raw segment label
DEFECT_NULL_AMOUNT_RATE = 0.04       # #7  opps with null amount
DEFECT_ZERO_AMOUNT_RATE = 0.02       # #7  $0 trial opps
DEFECT_NON_USD_RATE = 0.015          # #7  non-USD currency, no conversion supplied
DEFECT_TEST_RECORD_RATE = 0.01       # #8  test/internal opps ("DELETEME")
DEFECT_INTERNAL_CONTACT_RATE = 0.01  # #8  @arcline.com employee contacts
DEFECT_CROSSWALK_BREAK_RATE = 0.08   # #10 hs<->sf id crosswalk rows with null sf_lead_id
DEFECT_LATE_HISTORY_RATE = 0.05      # #6  stage-history rows that arrive after _synced_at
DEFECT_MISSING_HISTORY_RATE = 0.03   # #6  closed opps missing their stage-history trail

# Messy raw segment labels -> canonical. The crosswalk seed resolves them; a naive
# GROUP BY segment_raw would scatter counts across these.
SEGMENT_LABEL_VARIANTS = {
    "SMB": ["SMB", "smb", "Small Business", "SmallBiz"],
    "Mid-Market": ["Mid-Market", "MidMarket", "MM", "Mid Market"],
    "Enterprise": ["Enterprise", "ENT", "Strategic", "enterprise"],
}

# Messy raw lead-source labels -> canonical (staging normalizes; accepted_values on
# the canonical 7 in fct_leads then passes).
LEAD_SOURCE_VARIANTS = {
    "Inbound": ["Inbound", "inbound", "IB"],
    "Outbound": ["Outbound", "outbound", "Cold Outreach"],
    "Partner": ["Partner", "Channel"],
    "Event": ["Event", "Trade Show"],
    "Referral": ["Referral", "Word of Mouth"],
    "Content": ["Content", "Content Download"],
    "Paid": ["Paid", "Paid Ads", "PPC"],
}

INDUSTRIES = [
    "Software", "Financial Services", "Healthcare", "Manufacturing", "Retail",
    "Media", "Logistics", "Energy", "Education", "Telecom",
]
COUNTRIES = ["United States", "Canada", "United Kingdom", "Germany", "Australia"]
NON_USD_CURRENCIES = ["EUR", "GBP", "CAD"]
MARKETING_EVENT_TYPES = ["FormFill", "Webinar", "ContentDownload", "EmailClick", "DemoRequest"]
MARKETING_CAMPAIGNS = [
    "2025-Q4-Webinar-Series", "Always-On-Search", "Gartner-Retargeting",
    "Outbound-Sequence-A", "Annual-User-Conference", "Content-Syndication",
]
OPP_TYPES_NEW = "New Business"
