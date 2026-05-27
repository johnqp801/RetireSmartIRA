# RetireSmartIRA — Tax Accuracy Technical Brief

**Subject:** How RetireSmartIRA verifies its "Updated for 2026 taxes" claim
**Audience:** Press, reviewers, and informed readers
**Document date:** May 27, 2026
**App version referenced:** 1.8.5
**Prepared by:** John Urban, Alamo Ventures Group LLC

---

## TL;DR

RetireSmartIRA is a retirement-planning tool. It is not tax-preparation
software. Its job is to give households a directionally correct,
year-by-year picture of how withdrawals, Roth conversions, and Social
Security timing affect federal and state taxes through retirement —
not to file a return.

For tax year 2026, the app's tax engine is built on:

1. **Federal**: 100% IRS Revenue Procedure 2025-32 (the official 2026
   inflation-adjusted brackets and figures), plus the One Big Beautiful
   Bill Act (OBBBA) provisions effective for TY 2026.
2. **State**: A formal verification protocol we call TriSTAR
   (Triangulated State Tax Accuracy Regimen) applied to every state in
   which we materially changed bracket data, with an audit trail of
   primary sources.
3. **In-app disclosures** that explicitly position the output as
   estimates for planning purposes, exclude local taxes, and direct
   users to a qualified professional before making financial decisions.

The "Updated for 2026 taxes" claim is defensible because the federal
schedule is verified 100% TY 2026 and the 50 state + DC schedules are
either explicitly verified to TY 2026 primary sources (26 jurisdictions
in this release) or already structurally current with only inflation
drift within one year (~20 jurisdictions). No state in the engine is
known to be materially wrong as of the v1.8.5 ship date.

---

## 1. Federal tax engine

The federal tax engine for TY 2026 is built directly from:

- **IRS Revenue Procedure 2025-32** — official 2026 inflation-adjusted
  numbers (standard deduction, brackets, AMT, IRA/401(k) limits, etc.)
- **One Big Beautiful Bill Act (OBBBA)** — for 2026 provisions including
  the per-individual senior bonus deduction and other retirement-relevant
  changes.
- **26 USC** statutes for items that aren't inflation-indexed (e.g., NIIT
  threshold, statutory MHST-style thresholds where applicable).

The federal engine is covered by 951+ automated tests in the codebase,
including five end-to-end stress tests (Scenarios A through E) that
exercise high-income, multi-source, AMT-triggering, and NIIT-triggering
combinations. These tests assert specific dollar values against
hand-verified math and serve as a regression net for every change.

---

## 2. State tax engine

The state engine models 50 states + DC (51 jurisdictions). Each is
encoded as a `StateTaxConfig` with: tax system (flat, progressive, none,
or special), bracket arrays per filing status, retirement-income
exemption rules, standard deduction, capital gains treatment, and
safe-harbor rules where they exist.

### 2.1 Sources of truth

Our policy is to source every materially changed state bracket from
the highest-tier primary source available:

1. **State department of revenue** (e.g., CA FTB, NY DTF, MN DOR)
2. **Enacted legislation** (state house/senate bills, signed acts)
3. **Official forms** (withholding formulas, rate schedules)
4. **State statute pages** (codified law)

Secondary aggregators (Tax Foundation, RetirementLiving, Kiplinger, Nolo)
are used only as cross-checks, never as a primary source.

### 2.2 TriSTAR (Triangulated State Tax Accuracy Regimen)

For every state in which v1.8.5 materially changed bracket data, the
change went through up to five independent sources:

- **#1 — Primary source verification** (mandatory): A state-government
  URL or enacted statute citation captured for the audit trail.
- **#2 — NBER TAXSIM-35 oracle** (where applicable): The engine output
  is cross-checked against TAXSIM-35, an academic tax-simulation model
  used in published economics research.
- **#3 — Metamorphic property tests**: Automated tests that verify
  invariants (e.g., tax monotonically increases with income, MFJ
  thresholds are at least 1.0x Single thresholds, etc.).
- **#4 — Multi-LLM independent review**: The same diff is sent to two
  large language models (ChatGPT and Gemini 2.5 Pro) in fresh,
  independent conversations against the cited primary source. Each
  model returns MATCH or MISMATCH per check item. Both must agree, or
  the disagreement is resolved by direct primary-source verification.
- **#5 — Tester feedback**: User-reported screenshots and reproductions
  of unexpected bracket math, captured into the change log.

The minimum bar to ship a state change is three of the five with
source #1 mandatory.

### 2.3 What "Updated for 2026 taxes" actually means

In v1.8.5, the 51 state + DC jurisdictions break down as follows:

- **26 explicitly TriSTAR-verified to TY 2026 in this release**:
  Arkansas, California, Connecticut, Delaware, Hawaii, Idaho, Kansas,
  Louisiana, Maine, Maryland, Massachusetts, Michigan, Minnesota,
  Mississippi, Missouri, Montana, Nebraska, New York, North Dakota,
  Ohio, Oklahoma, Rhode Island, South Carolina, Vermont, West Virginia,
  Wisconsin.
- **~20 structurally already TY 2026-current** (no changes needed
  because the state's brackets, rates, or structure were unchanged
  vs. our prior verified version): Alabama, Arizona, Colorado, DC,
  Illinois, Indiana, Iowa, Kentucky, New Jersey, New Mexico, North
  Carolina, Oregon, Pennsylvania, Utah, Virginia, plus the 7
  no-income-tax states (Alaska, Florida, Nevada, South Dakota,
  Tennessee, Texas, Wyoming), plus New Hampshire (interest/dividends
  only, phased out) and Washington (capital gains only).
- The remainder are within one inflation cycle of their published
  primary source. For planning-tool tolerance — where projections
  span 20-30 years and rates compound across many uncertain inputs —
  threshold drift of a few percent in a single year is well inside
  the noise floor of the model.

No state in the engine is known to be materially wrong as of v1.8.5.

### 2.4 Audit trail

Every TriSTAR cycle in v1.8.5 produced two artifacts saved to the
project's persistent memory:

- A **review payload** (the exact diff sent to the multi-LLM reviewers,
  with primary-source URLs and bracket-engine semantics explained).
- A **review result** (verbatim responses from both LLMs, plus
  disagreement-resolution notes when applicable).

In this release cycle alone, ChatGPT caught a real error that Gemini
missed: Missouri thresholds had been pulled from the MO DOR
"year-changes" page (which displays the prior tax year's schedule for
returns filed the following April). Direct PDF verification of the MO
DOR 2026 Withholding Tax Formula confirmed ChatGPT's flag, and the
engine was corrected before ship. This is exactly the failure mode
TriSTAR #4 is designed to surface — a primary source that *looks* current
but isn't.

---

## 3. In-app disclosures

The app explicitly tells users what it is and isn't, in multiple
locations:

### 3.1 Clickwrap (first-launch terms)
> *"RetireSmartIRA provides educational estimates only. Results are not
> tax, legal, or investment advice. Consult a qualified professional
> before making financial decisions."*
>
> Source: `ClickwrapView.swift:142`

### 3.2 Guide disclaimer (visible throughout the in-app Guide)
> *"This app provides estimates for planning purposes only. Local and
> city income taxes (e.g., NYC, Yonkers) are not included. Consult with
> a qualified tax professional or financial advisor for personalized
> advice. Tax laws and regulations may change."*
>
> Source: `GuideView.swift:764`

### 3.3 Output labels
Every dollar value derived from the tax engine is presented with
language consistent with estimation, not filing: "Tax Projection,"
"Estimated quarterly payment," "Projected federal tax," etc.

---

## 4. Known limitations (disclosed)

The following are explicitly out of scope and are communicated to the
user either in the disclaimer text, the Guide, or the relevant
calculator view:

- **Local and city income taxes**: New York City, Yonkers, MD county
  taxes, OH/PA municipal, IN counties, and similar are NOT modeled.
- **Filing status simplification**: The engine supports Single and
  Married Filing Jointly. MFS and HoH are not separately modeled.
- **State-specific surtaxes on capital gains** (e.g., MA 9% short-term,
  MD 2% high-AGI cap-gains surtax) are not separately modeled.
- **State-specific retirement-income phaseouts**: Some states (NJ, RI,
  MN, etc.) have AGI-based phaseouts of pension/SS exemptions that are
  encoded at the "headline" exemption level for planning purposes. The
  app may slightly over- or under-exempt at exact phaseout boundaries.
- **Estate, gift, and inheritance taxes**: Not modeled (this is a
  retirement-planning tool, not an estate-planning tool).
- **Tax-credit modeling**: Limited to retirement-relevant credits.
  General credits (EITC, child tax credit, etc.) are not modeled because
  the target user is at or near retirement.

These limitations are documented in the in-app Guide and reflect a
deliberate scope decision: build the best tool for retirement-decision
planning, not a general-purpose tax calculator.

---

## 5. Update cadence and versioning

State and federal tax data is refreshed at least once per tax year,
and more often when material legislation changes mid-year (e.g., the
Arkansas TY 2026 rate cut enacted in May 2026 was incorporated within
the same release cycle).

Each release ships with internal release notes documenting which states
were materially changed and what primary source backs each change.
The app version (e.g., 1.8.5) is bumped on every release that touches
tax data so users can confirm they're on a current build.

---

## 6. Why "Updated for 2026 taxes" is honest

Three claims, three foundations:

1. **"Federal taxes for 2026"** — backed 100% by IRS Rev. Proc. 2025-32
   and OBBBA. No interpretation, no waiting on guidance, all in the
   engine.
2. **"All 50 states for 2026"** — backed by the inventory above:
   26 explicitly TriSTAR-verified to TY 2026, ~20 structurally current,
   none known to be materially wrong.
3. **"Updated"** — refers to the release cycle in which we did the
   verification work, not a claim that every threshold is filing-grade.
   The in-app disclaimer language makes this explicit.

The claim is not that the app replaces a CPA. The claim is that the
app's tax engine is current, primary-source-backed, and updated for
TY 2026.

---

## 7. Available for press review

For any individual state, we can provide on request:

- The exact Swift bracket data shipped in v1.8.5
- The primary source URL(s) used to verify it
- The multi-LLM review responses for that state
- The before/after diff vs. the prior release

Contact: support@retiresmartira.com

---

*RetireSmartIRA is an Alamo Ventures Group LLC product. App Store
listing: https://apps.apple.com/app/retiresmartira/* (insert app ID)*
*Website: https://retiresmartira.com*
