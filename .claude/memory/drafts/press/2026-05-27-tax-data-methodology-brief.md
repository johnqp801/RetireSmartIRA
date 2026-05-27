# RetireSmartIRA — Tax Data Methodology Brief

**Subject:** How RetireSmartIRA sources and verifies the tax parameters it ships
**Audience:** Press, reviewers, and informed readers
**Document date:** May 27, 2026
**App version referenced:** 1.8.5
**Prepared by:** John Urban, Alamo Ventures Group LLC

---

## At a glance

RetireSmartIRA is a retirement-planning tool, not tax-preparation
software. Its job is to give households a directionally correct,
year-by-year picture of how withdrawals, Roth conversions, and Social
Security timing affect federal and state taxes through retirement —
not to file a return.

For tax year 2026, the app's tax engine is built on:

1. **Federal tax parameters** based on IRS Revenue Procedure 2025-32
   and IRS guidance on One Big Beautiful Bill Act (OBBBA) provisions
   effective for 2026.
2. **State tax data** changed in this release verified against
   official primary sources (state departments of revenue, official
   forms, enacted legislation, state statute pages), with internal
   audit notes retained for each change.
3. **In-app disclosures** positioning output as estimates for planning
   purposes, explicitly excluding items outside scope (local taxes,
   MFS/HoH filing status, certain phaseouts), and directing users to a
   qualified professional before making financial decisions.

The "Updated with 2026 federal tax parameters and current state tax
rules verified against official sources" framing is what the technical
record supports.

---

## 1. Federal tax engine

The federal tax engine for TY 2026 is built from:

- **IRS Revenue Procedure 2025-32** — the official 2026 inflation-adjusted
  parameters (standard deduction, brackets, AMT, IRA/401(k) limits, etc.)
- **IRS guidance on OBBBA provisions** effective for 2026, including the
  per-individual senior bonus deduction and other retirement-relevant
  changes
- **26 USC** statutes for items that are not inflation-indexed (NIIT
  threshold, certain statutory floors)

Combining these into a working engine still involves interpretive
modeling decisions wherever federal rules interact — for example, the
ordering of Social Security taxability, NIIT applicability, AMT
calculation, and Roth conversion impact on IRMAA tiers. Those modeling
choices are documented in code and covered by automated tests.

The federal engine is exercised by an automated test suite with more
than 950 tests, including end-to-end stress scenarios that combine high
income, multiple income sources, AMT triggers, and NIIT triggers, with
expected values checked against independently reviewed calculations.

---

## 2. State tax engine

The state engine models 50 states + DC (51 jurisdictions). Each is
encoded as a per-state configuration: tax system (flat, progressive,
none, or special), bracket arrays per filing status, retirement-income
exemption rules, standard deduction, capital gains treatment, and
safe-harbor rules where applicable.

### 2.1 Sources of truth

Our policy is to source every materially changed state bracket from
the highest-tier primary source available:

1. State department of revenue (e.g., CA FTB, NY DTF, MN DOR)
2. Enacted legislation (signed acts, codified statute)
3. Official forms (withholding formulas, rate schedules)
4. State statute pages

Secondary aggregators (Tax Foundation, RetirementLiving, Kiplinger, Nolo)
are used only as cross-checks, never as the basis for a change.

### 2.2 Verification process

For every state in which v1.8.5 materially changed bracket data, the
change went through up to five verification layers, with the minimum
bar being three of five and primary-source verification always
mandatory:

1. **Primary-source verification** *(mandatory)* — a state-government
   URL or enacted-statute citation captured in the audit notes.
2. **External calculator reasonableness check, where applicable** —
   bracket math compared against external reference calculators for
   sanity. This is used as a cross-check, not as an authoritative
   source for 2026 state law.
3. **Property-based regression tests** — automated tests asserting
   structural invariants the engine must satisfy (e.g., tax is
   non-decreasing in income, MFJ thresholds are at least equal to
   Single thresholds, an explicit zero-bracket produces zero tax at
   zero income, etc.).
4. **Independent review of the diff against the cited primary source** —
   a structured checklist applied independently to each change.
   Automated diff-checking tools may be used as an additional
   error-detection layer in this step. Any disagreement is resolved by
   direct verification against the primary source, never by reviewer
   majority.
5. **User-reported feedback** captured into the change log.

### 2.3 State inventory in v1.8.5

| Category | Count | Meaning |
|---|---|---|
| Materially changed in v1.8.5 and verified against primary sources | 26 | Rate, threshold, structural, or retirement-treatment change applied this release |
| No broad wage / retirement-income tax | 9 | AK, FL, NV, SD, TN, TX, WY + NH (interest/div only, phased out) + WA (capital gains only). No bracket schedule to update. |
| Re-checked in v1.8.5 against current official sources; no code change required | 4 | Verified TY 2026-current; carried forward unchanged |
| Carried forward from prior verified release; no published TY 2026 change identified | 12 | Existing model remained directionally current; no rate-structure change observed in primary sources |
| **Total jurisdictions modeled** | **51** | |

After this verification pass, we have no known errors in supported
state rate structures within scope (Single, MFJ, retirement-planning
use). Some state-specific details — local taxes, certain surtaxes,
filing-status variants beyond Single and MFJ, and exact phaseout
mechanics — are intentionally outside scope and disclosed below.

Small one-year inflation adjustments to bracket thresholds generally
have much less impact on long-range retirement projections than
assumptions about investment returns, inflation, longevity, future law
changes, and Roth conversion size. Structural errors, rate changes,
and missing surtaxes are treated as material and prioritized for
correction.

### 2.4 Audit trail

Each state change in v1.8.5 produced two artifacts retained as internal
verification records in the project repository:

- A **review payload** — the diff sent to the independent-review step,
  with the cited primary-source URL and the bracket-engine semantics
  needed to interpret the code.
- A **review result** — the verbatim reviewer responses and the
  disagreement-resolution notes when applicable.

During the v1.8.5 review, this process caught a Missouri threshold
error before release: one official-looking DOR page reflected a
prior-year return schedule, while the 2026 withholding formula PDF
contained the current thresholds. The code was corrected before
shipping. This is exactly why changed states are reviewed against
specific primary-source documents rather than general tax-summary
pages.

---

## 3. In-app disclosures

The app explicitly tells users what it is and isn't:

### First-launch terms (clickwrap)
> *"RetireSmartIRA provides educational estimates only. Results are not
> tax, legal, or investment advice. Consult a qualified professional
> before making financial decisions."*
>
> *Source: `ClickwrapView.swift:142`*

### Guide disclaimer (visible throughout the in-app Guide)
> *"This app provides estimates for planning purposes only. Local and
> city income taxes (e.g., NYC, Yonkers) are not included. Consult with
> a qualified tax professional or financial advisor for personalized
> advice. Tax laws and regulations may change."*
>
> *Source: `GuideView.swift:764`*

### Output framing
Every dollar value derived from the tax engine is presented with
language consistent with estimation, not filing: "Tax Projection,"
"Estimated quarterly payment," "Projected federal tax."

---

## 4. Known limitations (disclosed)

These items are explicitly out of scope and communicated to users
through the disclaimer text or the in-app Guide:

- **Local and city income taxes.** New York City, Yonkers, MD county
  taxes, OH/PA municipal, IN counties, and similar are not modeled.
- **Filing-status scope.** The current release models Single and
  Married Filing Jointly, the two statuses most relevant to
  RetireSmartIRA's target retirement-planning use cases. Married
  Filing Separately and Head of Household are not separately modeled
  and should not be used as the basis for decisions by users in those
  filing statuses.
- **State-specific surtaxes on capital gains** (e.g., MA 9% short-term,
  MD 2% high-AGI cap-gains surtax) are not separately modeled.
- **State retirement-income phaseouts.** Some states (NJ, RI, MN, etc.)
  have AGI-based phaseouts of pension or Social Security exemptions.
  Some of these exclusions are modeled at the primary exemption level
  rather than with every phaseout step. This may slightly over- or
  understate state tax near phaseout boundaries and is disclosed as a
  planning-tool limitation.
- **Estate, gift, and inheritance taxes** are not modeled. This is a
  retirement-planning tool, not an estate-planning tool.
- **General tax credits.** EITC, child tax credit, and similar credits
  not typically relevant at or near retirement are not modeled.

These limitations reflect a deliberate scope decision: build the best
tool for retirement-decision planning, not a general-purpose tax
calculator.

---

## 5. Update cadence and versioning

State and federal tax data is refreshed at least once per tax year.
Mid-year state rate changes are incorporated through maintenance
releases when material.

Each release ships with internal notes documenting which states were
materially changed and what primary source backs each change. The app
version (e.g., 1.8.5) is bumped on every release that touches tax data
so users can confirm they're on a current build.

---

## 6. Bottom line

RetireSmartIRA is not tax-preparation software. It is a
retirement-planning tool with a documented tax-data methodology,
primary-source review, automated regression tests, and disclosed scope
limitations. In v1.8.5, federal 2026 parameters are based on
IRS-published guidance, and material state tax changes were reviewed
against official state sources. The app's goal is to help users
evaluate retirement decisions — Roth conversions, withdrawals, Social
Security timing, RMDs, and long-term tax exposure — with current,
source-backed assumptions, while making clear that users should
consult a qualified professional before acting.

---

## 7. Available for review on request

For press or professional review, we can provide state-specific
verification notes on request, including:

- The exact bracket data shipped in v1.8.5
- The primary-source URL(s) used to verify it
- The internal review responses for that state
- The before/after diff vs. the prior release

Contact: support@retiresmartira.com

---

*RetireSmartIRA is an Alamo Ventures Group LLC product.*
*App Store: https://apps.apple.com/app/retiresmartira/*
*Website: https://retiresmartira.com*
