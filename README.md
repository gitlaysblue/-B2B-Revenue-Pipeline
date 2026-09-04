# 📊 B2B Revenue Pipeline — Multi-Source Star Schema, Power BI Dashboard & Live Write-Back

## Objective

This project builds an end-to-end B2B sales operations system: it unifies deal
data scattered across three different sources (a MySQL CRM export, a legacy
CSV of pre-migration deals, and a SharePoint-hosted quota list) into a single
star-schema data model, layers on DAX-driven KPIs and time intelligence, and
turns the result into something reps can actually act on — not just look at —
via an embedded write-back portal and an automated SharePoint notification.

The project follows a full analytics-engineering workflow: multi-source data
modeling → DAX measure design → interactive Power BI dashboard → automation
(Power Automate) → operational write-back (Power Apps) → cross-platform
validation (Tableau + raw SQL).

> **Note on the data:** all deal, account, rep, and quota data used here is
> **synthetic** — generated to resemble a realistic B2B sales pipeline for
> the purpose of building and demonstrating this architecture. No real
> company or customer data is used.

## Table of Contents
- [Data Sources](#data-sources)
- [Technologies](#technologies)
- [Data Model](#data-model)
- [DAX Measures](#dax-measures)
- [Dashboard](#dashboard)
- [Automation: Power Automate](#automation-power-automate)
- [Write-Back: Power Apps Portal](#write-back-power-apps-portal)
- [Performance](#performance)
- [Validation: SQL vs. DAX](#validation-sql-vs-dax)
- [Tableau Executive Mirror](#tableau-executive-mirror)
- [Challenges & Troubleshooting](#challenges--troubleshooting)
- [How to Explore This Project](#how-to-explore-this-project)

## Data Sources

Three intentionally mismatched sources, simulating what a real integration
project actually looks like:

| Source | Format | What it holds | Quirks |
|---|---|---|---|
| `mysql_seed.sql` | MySQL dump | Core CRM data: `dim_accounts`, `dim_reps`, `dim_products`, `dim_stages`, `fact_deals` (1,600 rows) | Clean, relational, surrogate keys |
| `legacy_deals_2021_2022.csv` | CSV | 420 pre-migration deals (2021–2022) | Inconsistent date formats row-to-row, currency stored as mixed plain numbers / `"$X,XXX.XX"` strings |
| `sharepoint_rep_quotas.csv` → SharePoint list | CSV → SharePoint | Quarterly rep quotas by territory | Case-inconsistent region values (`West` vs `west`), joined by `rep_name` (no surrogate key) |

## Technologies

- **Database:** MySQL
- **Modeling & Dashboard:** Power BI (Power Query M, DAX)
- **Automation:** Power Automate (SharePoint trigger → Outlook notification)
- **Operational write-back:** Power Apps (embedded in-report)
- **Data hosting for live editing:** SharePoint Lists
- **Cross-platform validation:** Tableau, raw SQL

## Data Model

Star schema, 9 tables:

```
                dim_products      dim_reps
                     \                /
                      \              /
   legacy_deals_2021_2022 -- fact_deals -- dim_accounts
                      /              \
                     /                \
              dim_stages          Calendar (date table)
                                        \
                                sharepoint_rep_quotas
                                   (joined by rep_name)
```

- `fact_deals` is the primary fact table (MySQL-native, 1,600 rows, 2023–2026).
- `legacy_deals_2021_2022` is deliberately **kept as a separate table**, not
  appended into `fact_deals` — this preserves the source boundary and avoids
  silently blending two different data quality regimes into one fact table.
- `Calendar` is a DAX-generated date table with **two relationships** to
  `fact_deals`: one active (`created_date`), one inactive (`closed_date`,
  invoked via `USERELATIONSHIP` in revenue-facing measures) — since revenue
  should be recognized on close date, not creation date.
- `sharepoint_rep_quotas` relates to `dim_reps` via `rep_name` (text match,
  the one non-surrogate-key relationship in the model — a deliberate
  trade-off since the SharePoint source has no numeric rep ID).

## DAX Measures

All measures live in a dedicated `_Measures` table (no data, just formulas —
keeps the Fields pane clean).

| Category | Measures |
|---|---|
| Core KPIs | `Total Revenue`, `Deal Count`, `Win Rate`, `Average Deal Size`, `Open Pipeline Value` |
| Time Intelligence | `Revenue YTD`, `Revenue QTD`, `Revenue MTD`, `Revenue PY`, `Revenue YoY %`, `Revenue 3M Moving Avg` |
| Velocity | `Avg Sales Cycle Days`, `Avg Cycle by Current Stage`, `Deal Velocity` |
| Ranking | `Rep Revenue Rank`, `Product Revenue Rank`, `Is Top 5 Rep` |
| Quota | `Quota Attainment %` |

Example — the pattern used throughout for revenue-by-close-date:

```DAX
Total Revenue =
CALCULATE (
    SUM ( fact_deals[amount] ),
    USERELATIONSHIP ( 'Calendar'[Date], fact_deals[closed_date] ),
    fact_deals[status] = "Won"
)
```

## Dashboard

Three pages, 26 visuals total, built in Power BI Desktop:

**Executive Summary** — 5 KPI cards, a revenue trend line (actual + 3-month
moving average), a YoY growth bar chart, and slicers for Year / Region /
Manager.

**Rep Performance** — ranked rep table, a rep revenue bar chart, a
quota-attainment pivot, and a sales-cycle-by-stage bar chart.

**Pipeline & Funnel** — a stage funnel, deal velocity card, an open-deals
detail table, a category × region revenue pivot, and the embedded **Power
Apps write-back portal**.

*(Add dashboard screenshots / exported PDF here once finalized.)*

## Automation: Power Automate

**Trigger:** *"When an item is created or modified"* on the SharePoint
`Rep Quotas` list.
**Action:** *"Send an email (V3, Outlook.com connector)"* — notifies when
any rep's quota is edited, with the rep name, new quota, and editor's name
pulled in as dynamic content.

This closes the loop between "data changes" and "someone finds out about
it" without anyone needing to check the dashboard manually.

## Write-Back: Power Apps Portal

Reps and managers shouldn't only *view* stalled deals — they should be able
to act on them from the same screen. The **Deal Intervention Portal**:

1. Built on a dedicated `Open Deals` SharePoint list (populated via a direct
   SQL export of `status = 'Open'` deals from `fact_deals`, not a manual
   CSV — see [Challenges](#challenges--troubleshooting)).
2. Auto-generated in Power Apps from that list (Browse / Detail / Edit
   screens).
3. Embedded directly into the **Pipeline & Funnel** page via the native
   Power Apps visual.
4. Verified end-to-end: editing a deal's stage/notes *inside the Power BI
   report* writes the change back to the live SharePoint list — confirmed
   by checking the list directly after an in-report edit.

## Performance

Ran via Power BI's built-in **Performance Analyzer** on the Executive
Summary page. All visuals rendered in the 60–270ms range (well under the
~1000ms threshold usually considered "slow"). One notable finding: KPI
cards using `USERELATIONSHIP`-based measures took roughly **2x longer**
after a slicer change (~250ms vs ~120ms) than simple `COUNTROWS`-based
measures — an expected cost of the dual-date-relationship pattern, not a
problem worth re-engineering at this scale, but a useful data point for
explaining trade-offs.

## Validation: SQL vs. DAX

Cross-checked three headline DAX measures against equivalent raw SQL run
directly against `mysql_seed.sql`:

| Measure | SQL | Power BI | Result |
|---|---|---|---|
| Total Revenue | 12,845,400 | 12.85M | ✅ Exact match |
| Deal Count | 1,600 | "2K" | ✅ Match — see note below |
| Win Rate | 54.1% | 53% | ✅ Match (rounding tolerance) |

**Note on Deal Count:** the "2K" display initially looked like a
discrepancy. It isn't — it's Power BI's default compact-number formatting
(0 decimal places) rounding `1,600 → 1.6 → 2K` for display only. The
underlying measure and the SQL query return the identical value.

## Tableau Executive Mirror

*(In progress — Tableau connects directly to the same MySQL source as
Power BI and rebuilds the Executive Summary KPIs/charts independently, to
demonstrate the same business logic implemented on a second BI platform.
Screenshots and workbook link to be added here once complete.)*

## Challenges & Troubleshooting

Real issues hit while building this, and how they were resolved — kept here
deliberately, since working through these was most of the actual learning:

- **Dual date relationships:** `fact_deals` has both `created_date` and
  `closed_date`, but a table can only have one *active* relationship to a
  date table. Solved by making `created_date` active and using
  `USERELATIONSHIP()` for `closed_date`-based revenue measures — but this
  first required manually creating the second (inactive) relationship in
  Model view, since `USERELATIONSHIP` can only toggle between relationships
  that already exist, not create new ones.
- **Chronological sorting on text columns:** `MonthYear` (e.g. "Jan 2023")
  sorted alphabetically by default. Fixed with a numeric `MonthYearSort`
  helper column (`YEAR*100 + MONTH`) and Power BI's **Sort by Column**
  feature — a two-field Year/Month hierarchy was tried first but caused
  Power BI to collapse the axis into a drill hierarchy, hiding month-level
  detail entirely.
- **Column renamed during cleaning:** `Quota (USD)` no longer existed under
  that exact name after Power Query cleanup, breaking a measure reference.
  Fixed by using DAX autocomplete (rather than retyping column names from
  memory) to always match the model's real column names.
- **Wrong SharePoint connector picked twice:** first between *"When a file
  is created or modified"* (document libraries) vs *"When an item is
  created or modified"* (lists) — needed the latter for structured list
  data. Then between the **Office 365 Outlook** email connector (work/school
  accounts only) vs **Outlook.com** (personal accounts) — the OAuth
  `Unauthorized` error traced back to a university tenant blocking the
  work/school connector, resolved by switching both the email connector and
  the signed-in account to a personal Microsoft account.
- **Wrong embedded visual:** the "Power Automate" button visual and the
  "Power Apps" embed visual look similar in the visual picker but do
  completely different things — had to delete and re-add with the correct
  one.
- **Open Deals list population:** exporting the filtered table visual to
  Excel only carried the 4 columns that happened to be on that visual, not
  the 8 needed for the write-back list. Solved by writing a direct SQL
  query against the source tables instead of relying on a UI export.
- **Deal Count mismatch investigation:** SQL returned 1,600, the dashboard
  card showed "2K" — initially misdiagnosed as an unintentional merge with
  the legacy CSV table (420 rows). Re-checked against the actual model
  diagram, which confirmed `legacy_deals_2021_2022` was never merged into
  `fact_deals`; the real cause was compact-number display rounding, not a
  data issue.
- **Raw source data quality:** the legacy CSV mixed date formats
  (`2021/12/06`, `27-04-2021`, `11/04/2022`) and currency-formatted strings
  (`"$4,926.14"`) with plain numbers in the same column; the SharePoint
  quota data had inconsistent region casing (`West`/`west`) — both cleaned
  in Power Query before modeling.

## How to Explore This Project

- **Raw data sources:** [`mysql_seed.sql`](dataset/mysql_seed.sql) ·
  [`legacy_deals_2021_2022.csv`](legacy_deals_2021_2022.csv) ·
  [`sharepoint_rep_quotas.csv`](sharepoint_rep_quotas.csv)
- **Power BI dashboard:** [`b2bdashboard.pbix`](b2bdashboard.pbix) — open in
  Power BI Desktop (free) to explore the full model, all DAX measures, and
  all three report pages.
- **Tableau workbook:** *(link to be added once the Tableau mirror is
  complete)*
- To load the source data yourself: run `mysql_seed.sql` against a local
  MySQL instance, then point Power BI's MySQL connector at it — the
  `.pbix` file's Power Query steps will pick up from there.

---
