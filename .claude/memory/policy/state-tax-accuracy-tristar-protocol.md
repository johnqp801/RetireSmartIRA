# TriSTAR Protocol — Triangulated State Tax Accuracy Regimen

**RetireSmartIRA's ongoing process for keeping state-tax calculations
relevant, defensible, and valuable to users.**

Adopted 2026-05-20, following the v1.8.2–v1.8.4 audit cycle.

---

## Name and one-line

**TriSTAR** = **Tri**angulated **S**tate **T**ax **A**ccuracy **R**egimen.

We don't trust any single source — not primary statutes alone, not an
academic oracle alone, not our own author-AI alone, not a single
tester's report alone. We **triangulate** across five independent
sources to find and fix state-tax errors before users notice them, and
to catch them quickly when they do.

---

## Why this exists

In a 4-day window in May 2026 we shipped the same Pennsylvania state-
tax bug twice (v1.8.2 and again in v1.8.3) through a 951-test suite,
because Claude wrote the code, Claude wrote the tests, and Claude
declared the audit complete. Tester feedback eventually surfaced both
the original bug and the cross-view residual.

That experience taught us: **single-source verification is structurally
insufficient** for tax engines. Independent reference points are
mandatory, not optional. TriSTAR codifies how we keep them in place.

---

## What we are (and aren't)

RetireSmartIRA is a **retirement-planning estimator**, in the same
positioning lane as Boldin (formerly NewRetirement). It is **not**
tax-preparation software. We aim for *directionally correct* state
tax projections that lead users to the same retirement decisions a
qualified tax professional would lead them to — we do **not** aim for
filing-grade dollar accuracy.

This positioning shapes everything downstream:

- Calculation tolerance: a planning estimate within ~$200 of a tax
  professional's number is acceptable; a structural exemption being
  applied or denied incorrectly is not.
- App Store description and in-app disclaimers reinforce this.
- TriSTAR's pass/fail thresholds are calibrated to planning-tool, not
  filing-grade, accuracy.

---

## Objectives

1. **Zero structural state-tax bugs reach production**, where
   "structural" means: an exemption applied when none exists, an
   exemption denied when one exists, a cap doubled when it shouldn't
   be, or a calculation that contradicts the cited statute at the
   direction-of-the-money level.

2. **State-tax data stays current** across the 41 income-tax states
   plus DC, with all encoded values traceable to a primary source
   (state DOR publication, statute, or DOR-published technical
   bulletin) accessed within the last 12 months.

3. **Tester-reported errors are root-caused, not point-patched.** Every
   user report that surfaces a bug triggers (a) the specific fix, and
   (b) an audit of related code paths to find sibling bugs in the same
   class.

4. **Every fix ships with a regression test** that pins the corrected
   behavior with a primary-source citation in the test's doc comment.

5. **The audit process is itself audited** — we periodically review the
   defect log to see which TriSTAR sources are catching which bug
   classes, and rebalance investment accordingly.

---

## The Five Triangulation Sources

Every state-tax change must be verified against AT LEAST THREE of the
following, with #1 mandatory.

### 1. Primary source (always mandatory)

The cited statute, DOR publication, technical bulletin, or DOR
guidance page. We quote it verbatim in the code comment and in the
regression test's doc string. Secondary sources (Tax Foundation, blog
summaries, TurboTax help pages) are useful for orientation only — they
never appear as the cited source in committed code.

Acceptable primary sources: state revenue department PDFs and pages,
state legislature bill text on `.gov` domains, official state code
compilations (e.g., O.C.G.A., NJSA, C.R.S., Md Tax-General).

### 2. Independent oracle — NBER TAXSIM-35

We maintain a fixture-based differential harness (`tools/taxsim-refresh/`
plus `RetireSmartIRATests/TaxsimOracleTests.swift`) that POSTs ~20
representative retirement scenarios to NBER's TAXSIM-35 (the
academic-standard tax calculator since 1974, cited in 1,200+ research
papers and used by PolicyEngine US for validation). Federal liability
must match within $200; state liability must agree directionally (no
exempt↔tax flips).

Refresh cadence: scenarios re-validated against TAXSIM whenever state
config changes; the full fixture set re-POSTed when TAXSIM publishes
a new tax-year coding.

### 3. Property-based / metamorphic tests

`RetireSmartIRATests/MetamorphicPropertyTests.swift` pins 20 structural
invariants that hold regardless of specific dollar amounts — federal
tax monotonic in income, MFJ no worse than Single at the same total
income, PA exempts retirement income at 65, etc. These catch entire
bug *classes* that example-based unit tests miss. New invariants are
added whenever a real bug reveals a property we hadn't pinned.

### 4. Multi-LLM independent review

Before any state-tax engine change ships, we run a structured
side-by-side review through ChatGPT and Gemini (separately, identical
prompts) of the diff plus the primary-source quotes. Each model
returns MATCH or MISMATCH per affected state. Disagreement triggers
investigation. The prompt template lives in
`.claude/memory/drafts/2026-05-20-v1.8.4-engine-review-payload.md` and
should be adapted for each release.

Why two LLMs: different training data, different biases. Both agreeing
on a MATCH is a stronger signal than either alone. Both agreeing on a
MISMATCH is a near-certain bug. They disagree often enough on edge
cases that the cost (~10 minutes) is worth the catch rate.

### 5. Tester feedback loop

Real testers — currently Jonggie F. and a small TestFlight cohort —
are the canary on production calculations. When a tester reports an
issue, we (a) reproduce the exact scenario in a regression test before
changing code, (b) audit the broader code path that produced the bug
for sibling instances, (c) reply transparently about what's fixed now
vs. coming in the next release, and (d) notify the tester when each
fix ships.

When budget permits, we add a paid Enrolled Agent (EA) quarterly
review as a sixth source — 4 hours of an EA on Upwork running
~10 representative retirement scenarios through RetireSmartIRA and a
commercial tax tool (Drake, ProConnect, TurboTax), red-lining
discrepancies. This is the single highest-ROI improvement available
beyond the five above.

---

## Process: from report to ship

When a state-tax issue is identified (whether by tester, by oracle, by
property test, by LLM review, or by routine refresh):

1. **Validate the tax law from primary source.** Find and quote the
   statute, DOR bulletin, or DOR guidance page. If primary source is
   unclear, escalate before writing code.

2. **Investigate the architectural shape.** Is this a one-state bug,
   a class of similar state bugs, or an engine-wide gap? Scope the
   fix to match the actual shape, not just the reported symptom.

3. **Write the failing regression test first**, citing the primary
   source in the test's doc comment. The test pins both the corrected
   behavior and the user-relevant scenario that triggered the bug.

4. **Make the test pass with the minimum viable change.** Don't
   refactor adjacent code unless directly required. Add new schema
   fields if the existing model can't express the law correctly.

5. **Mirror the change in any duplicated logic.** Today
   `applyRetirementExemptions` (in `TaxCalculationEngine.swift`) and
   `stateTaxBreakdown` (in `DataManager.swift`) both compute exemption
   amounts; both must stay in lockstep. `StateTaxBreakdownTests` pins
   this.

6. **Run the full triangulation:** full test suite green, TAXSIM
   oracle re-pass, property tests re-pass, and (for engine-touching
   changes) multi-LLM review.

7. **Ship with transparent release notes** naming the state(s)
   affected, the primary source(s), and the specific change.

8. **Reply to the originating tester** when their scenario verifies on
   the live app, naming what's fixed and what's still pending.

9. **Update the defect log** (`.claude/memory/decisions/` audit notes)
   with the bug class, source(s) that caught it, and any blind spots
   the catch revealed.

---

## Refresh cadence

| What | Frequency | Trigger |
|---|---|---|
| Federal constants audit | Annually | IRS Rev. Proc. release (~October) |
| State-by-state primary-source re-verification | Annually | After state legislatures close (typically July-August) |
| TAXSIM fixture re-POST | Each release that touches engine | Or quarterly minimum |
| Property test review | Each release | Add invariants suggested by bug post-mortems |
| Multi-LLM review | Each release that touches state-tax engine | Or whenever schema changes |
| EA review (when budgeted) | Quarterly | Independent of releases |
| Defect taxonomy review | Quarterly | Look for emerging classes |

---

## Non-objectives

We are **not** trying to:

- Match TurboTax / H&R Block / Drake to the dollar on filed returns.
- Provide tax advice or substitute for a CPA/EA.
- Cover every edge case in every state's tax code (e.g., AGI-based
  phaseout for NJ's pension exclusion is documented as a TODO; we
  prioritize the structural rule over the marginal tier).
- Track local / county income taxes (we cover state-level only).
- Calculate quarterly estimated tax obligations to filing-grade
  precision (we provide a planning estimate via SALT).

When we discover an area we can't model accurately, we document the
known approximation as a code TODO with the relevant primary source
cited, rather than silently producing the wrong number.

---

## Promises to users (and we publish these)

1. We will not knowingly ship a state-tax calculation that contradicts
   the cited primary source for that state.

2. When we discover an error after shipping, we will fix it in the
   next release we can, name what changed in the App Store "What's
   New," and reach out directly to any tester who reported the issue
   or whose scenarios are affected.

3. We will keep TriSTAR's verification sources up to date — TAXSIM
   fixtures current, property tests expanding, primary-source quotes
   refreshed annually — for as long as RetireSmartIRA ships.

4. We will document known approximations openly in this protocol and
   in code comments, so users and reviewers can see exactly where the
   planning estimate may diverge from a filed-return calculation.

---

## How TriSTAR has performed

(Track this section over time. Initial entries below from the v1.8.4
audit cycle.)

**v1.8.4 release (May 2026):**

- Bug class found by **primary source review**: PA exempts retirement
  income (Jonggie's original report, 1.8.2 fix).
- Bug class found by **TAXSIM oracle**: 5 state-config bugs (MD IRA
  qualification, NY per-individual cap, GA age tiers, NJ age gate, CO
  shared cap).
- Bug class found by **multi-LLM review**: 3 bugs the oracle missed
  (NY age-59½ gate, GA shared cap, per-individual multiplier
  threshold).
- Bug class found by **property tests**: P3 ratio bound was too tight
  (calibration miss, not engine bug).
- Bug class found by **tester feedback**: cross-view consistency
  (Jonggie's screenshots, May 19), drove the 5-bug audit.

Five independent source types each caught at least one bug that the
others missed. That's the protocol working as designed.

---

*This document is the working policy. Edit it as the protocol evolves.
Major revisions get a memory commit and a session note entry.*
