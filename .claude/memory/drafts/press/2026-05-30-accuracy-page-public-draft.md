# Public `/accuracy` page — draft copy

**Created:** 2026-05-30
**For:** retiresmartira.com new `/accuracy` page (footer → Product column)
**Source decisions:** `2026-05-30-gemini-methodology-placement-prompt.md`
(4-model review → John's decisions)
**Tier:** PUBLIC (short). Full technical brief = `tax-data-methodology.md`
(on-request / PDF).
**Length:** ~520 words (target was ~500–700).

Applies: lead-with-user-benefit second person · **Missouri example OMITTED**
(John changed his mind 2026-05-30 — kept the *principle* "we check primary-source
documents, not summary pages" folded into the verification paragraph, but dropped
the named case study) · Swift file paths CUT · §4 reframed as scope · hedged
accuracy line (no "no known errors") · five-layer collapsed to one sentence ·
LLM-review downplayed · headline numbers instead of the state-inventory table ·
"full methodology on request" CTA.

---

## Page title

# Accuracy & Tax Data

### Subhead
*How we make sure the numbers you see are current, source-backed, and honest
about their limits.*

---

## Lead (reassurance, conclusion first)

RetireSmartIRA is a retirement-**planning** tool, not tax-preparation software.
Its job is to give you a clear, year-by-year picture of how withdrawals, Roth
conversions, and Social Security timing affect your federal and state taxes —
so you can compare decisions *before* you act. For that to be useful, the
underlying tax data has to be current and traceable to official sources. Here's
how we make sure it is.

## Where the numbers come from

**Federal.** Tax parameters come from official IRS guidance for the current
planning tax year — the annual IRS Revenue Procedure that sets inflation-adjusted
brackets, the standard deduction, and contribution limits, plus any signed
legislation in effect for that year (for example, the One Big Beautiful Bill Act
senior bonus deduction).

**State.** All 50 states plus DC are modeled. When a state changes its tax law,
we verify the change against **primary sources** — the state's department of
revenue, official rate schedules and forms, and enacted legislation. Secondary
summaries (Tax Foundation, Kiplinger, and similar) are used only as a sanity
cross-check, never as the basis for a change.

## How changes are verified

Every materially changed state goes through primary-source verification plus
automated regression testing and an independent review of the change against the
cited official source — and we check changed states against specific
primary-source documents (forms, schedules, statutes), not general tax-summary
pages that may quietly reflect a different tax year. The app's tax engine is
backed by **1,100+ automated tests** that re-check the math on every release, so
a correct number stays correct.

## What this app doesn't cover

These are deliberate scope choices — RetireSmartIRA is built to be the best tool
for retirement-decision planning, not a general-purpose tax calculator:

- **Local and city income taxes** (e.g., NYC, Yonkers, certain county and
  municipal taxes) are not modeled.
- **Filing status.** The app models Single and Married Filing Jointly — the two
  statuses most relevant to retirement planning. Married Filing Separately and
  Head of Household are not separately modeled.
- **Certain state surtaxes and retirement-income phaseouts** are modeled at the
  primary level rather than every step, which can slightly over- or understate
  state tax near phaseout boundaries.
- **Estate, gift, and inheritance taxes** are out of scope — this is a
  retirement-planning tool, not an estate-planning tool.
- **General tax credits** (EITC, child tax credit, and similar) not typically
  relevant at or near retirement are not modeled.

## Kept current

We refresh state and federal tax data at least once per tax year, and fold in
mid-year state changes through maintenance releases when they're material. The
app version is bumped on every release that touches tax data, so you can always
confirm you're on a current build.

After our latest verification pass (v1.8.5), we are not aware of any materially
wrong state rate structure within the app's supported filing statuses and
retirement-planning use. As always, RetireSmartIRA produces estimates for
planning — please consult a qualified tax professional or financial advisor
before making financial decisions.

---

## CTA (bottom of page)

**Want the full detail?**
Our complete Tax Data Methodology — including the per-state verification process,
source hierarchy, and release-by-release inventory — is available for press and
professional review.
**[Read the full methodology (PDF)]** · **[Contact us](mailto:support@retiresmartira.com)**

---

## Implementation notes (not page copy)

- **Footer:** add "Accuracy & Tax Data" → `/accuracy` under the **Product**
  column.
- **Cross-links to add:**
  - /press "By the Numbers" strip → link "1,100+ tests" (or a new "How we verify"
    line) to `/accuracy`.
  - /support: new FAQ "How accurate are the tax calculations?" → 2-sentence
    answer + link to `/accuracy`.
  - /whats-new v1.8.5 "verified against official sources" card → link to
    `/accuracy` (optional).
  - Home "verified against official sources" banner → could deep-link to
    `/accuracy` (optional; closes Claude Chat's "dead-end" gap).
- **PDF:** link the full brief as `RetireSmartIRA_Tax_Methodology_v1.8.5.pdf`
  (Gemini's suggested filename) at the CTA + in the /press kit zip.
- **Word count:** ~620 (page copy only, excludes title/notes).
