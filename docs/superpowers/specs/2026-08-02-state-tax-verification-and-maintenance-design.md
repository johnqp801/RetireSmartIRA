# State tax verification and maintenance — design

**Date:** 2026-08-02
**Status:** design, awaiting approval
**Trigger:** Steve Nicolai reported two shipped state-tax bugs in two days (Kansas personal exemption 08-01, Iowa retirement exclusion 08-02). A full 51-jurisdiction audit followed and found roughly 29 jurisdictions with at least one defect.
**Findings this design responds to:** `.claude/memory/roadmap/2026-08-02-full-50-state-verification.md`

---

## 1. Problem

The app carries tax rules for 51 jurisdictions across 13 configuration dimensions, and those rules change every year. Today they live as hardcoded Swift in a 2,100-line file holding exactly one tax year, verified by occasional manual sweeps.

That process has failed in a way worth stating precisely, because the failure mode drives the design:

- **A verified state was still wrong.** Wisconsin's 2025 Act 15 passed ten months before the 2026-05-27 sweep. Wisconsin carries a `Verified 2026-05-27` stamp and records no exclusion where a $24,000 per-person exclusion exists. The stamp is not evidence.
- **Secondary sources actively mislead.** A syndicated advisor guide states Colorado removed its pension caps effective 2026. The bill died in committee. The same guide reports Maine at $25,000, which is the wrong figure the app already has, and denies New York an IRA exclusion it does have. Single-source verification would have confirmed one existing bug and introduced a new one.
- **The false claim already entered the repo.** `TaxsimOracleTests.swift` lists "CO SB25-136" among known engine-vs-TAXSIM disagreements. The dead bill reached a code comment.
- **The existing independent oracle cannot catch this class.** TAXSIM-35 is pinned to TY 2023, its state law is coded through roughly 2020, and state dollar divergence is logged as informational rather than failing.
- **Correct parameters still produce wrong answers.** Backlog item I2: `postExemptionDeduction` is passed correctly in the single-year path (`DataManager.swift:662-671`) and appears **zero times** in `ProjectionEngine.swift`, verified by absence, so multi-year silently drops the New Jersey exemption. E8 is the same shape in the SALT cap: single-year uses `scenarioGrossIncome` as the phase-out basis (`DataManager.swift:1747`) while `MultiYearItemizedDeduction` passes `agi` net of above-the-line deductions, so the two surfaces disagree for anyone with an HSA or deductible IRA contribution. Fixing a number does not fix either.
- **A missing state silently becomes California.** `StateTaxData.swift:2069` returns California's config for any state not found.

The defect rate in the one dimension audited was roughly 29 of 51. The other twelve dimensions have not been audited at all.

## 2. Scope decisions

| Decision | Choice |
|---|---|
| Verification scope | **All of `StateTaxConfig`** — all 13 dimensions, all 51 jurisdictions |
| Data representation | **Bundled versioned JSON**, keyed by tax year, shipped with app releases |
| Verification backbone | **Parameter research + per-state golden scenarios**, golden scenarios hold the gate |
| Sequencing | **Foundation first**, then corrections, all in **one release**; ship date may slip |

Everything in this document ships together. No phased backfill, no deferred companion spec.

## 3. Architecture

Five components. Each is independently testable and has one job.

### 3.1 Data layer

One file per jurisdiction per tax year: `Resources/StateTaxData/2026/KS.json`.

Per-state rather than one table per year, so a change to Kansas produces a one-file diff and the source citation sits beside the data it justifies.

```json
{
  "schemaVersion": 1,
  "state": "KS",
  "taxYear": 2026,
  "verification": {
    "lastVerified": "2026-08-02",
    "primarySources": ["https://www.ksrevenue.gov/webfile/help/scheduleS_A.html"],
    "billReferences": ["SB 1 (2024 special session)"],
    "knownLimitations": [
      "KPERS, federal, military and railroad pensions are not distinguished from private pensions; the app taxes them."
    ]
  },
  "taxSystem": { ... },
  "standardDeduction": { ... },
  "personalExemption": { ... },
  "retirementExemptions": { ... },
  "safeHarbor": { ... },
  "conformity": { ... },
  "localIncomeTax": { ... },
  "capitalGains": { ... }
}
```

**`verification` is required by schema. `knownLimitations` is required even when empty.** A jurisdiction cannot be added without a primary source and a date. This is the forcing function that prevents the current situation from recurring, and it is the single most important property of the format.

**`personalExemption` becomes a first-class field.** It does not exist today. New Jersey's is a hardcoded special case at `DataManager.swift:662-671`; California's are credits. Kansas has none, which is Steve's 08-01 bug.

### 3.2 Loading and validation

`StateTaxDataLoader` decodes JSON into the existing `StateTaxConfig` value types. The engine's consumption of `StateTaxConfig` does not change, which keeps the migration inert by construction.

Three behavior changes:

1. **Remove the California fallback.** `config(for:)` currently returns California's rules for any state not found, which is a confident wrong answer attributed to the wrong state. Replace with a trap in debug, and in release a refusal to produce a state number accompanied by a visible explanation.
2. **Key configs by tax year.** `configs(for: year)`. Adding 2027 becomes additive rather than a rewrite.
3. **Disclose the constant-law assumption.** The app projects decades forward on one year's rules and says so nowhere. Projecting past the last loaded year surfaces "assumes <year> law held constant."

### 3.3 Engine model extensions

Five extensions. Each is required by findings in the audit and none is speculative.

**a. State-aware minimum age.** `TaxCalculationEngine.swift:570` hardcodes `retirementAge = primaryAge >= 59 || (enableSpouse && spouseAge >= 59)`. Iowa qualifies at 55, so config alone still taxes a 55-to-58-year-old Iowan. The gate must read the state's statutory age.

The same line's `||` grants a household-wide exemption when *either* spouse qualifies. Iowa's exclusion is explicitly per-qualifying-spouse. Both the age and the attribution need to become state-driven.

**b. Data-driven Roth conversion exemption.** `TaxCalculationEngine.swift:672` is a hardcoded `switch state` over PA, IL, MS. Iowa belongs in it and would be the first age-gated member. Move the rule into the JSON, with PA's withholding caveat (only the net amount is exempt) preserved as a per-state flag.

**c. Per-source exemptions.** `RetirementIncomeExemptions` is per-state. Nine jurisdictions have rules keyed to *which plan the money came from*: Kansas, Massachusetts, Hawaii, New York, Arizona, North Carolina, Idaho, Vermont, DC. The axes needed are government versus private, defined benefit versus defined contribution, and employer-funded versus employee-contributed. This also closes Alan's NY government-pension report and Steve's suggestion G (403(b)).

This is the largest single engine change in the release.

**d. AGI phase-out mechanism.** Connecticut, Virginia, Maine, Rhode Island, West Virginia and New Mexico all reduce or eliminate an exemption as income rises. Only New Jersey has a bespoke `steppedPhaseoutByFilingStatus` today.

**This matters more here than in a general tax tool.** A Roth conversion is precisely what lifts AGI through these thresholds, so modeling them as unconditional means the app promises an exemption that the recommended action destroys.

**e. Per-individual attribution and age gates.** `exemptionAppliesPerIndividual` is set for two states; at least seven statutes are per-person (OK, DE, LA, AR, AL, WI, RI). Several partial exemptions carry statutory ages the config does not record (DE 60, LA 65, VA 65, WI 67). Today's behavior systematically under-credits married couples.

### 3.4 Verification

**Layer 1, parameter research.** `tools/state-tax-audit/` emits one packet per jurisdiction generated *from the JSON*, so the artifact cannot drift from what the engine uses.

Protocol, run identically and independently against at least two models:

- Verdict per dimension: `CONFIRMS` / `CONTRADICTS` / `CANNOT_VERIFY`.
- Every non-`CANNOT_VERIFY` verdict carries a citation to a state DOR page, a statute, or an enrolled bill. Advisor blogs, tax-prep vendor help pages and news articles are inadmissible as sole basis.
- Any claimed 2024-2026 change must state the **bill number and its final disposition** (signed, vetoed, died). This is the check that catches the Colorado class of error.
- `CANNOT_VERIFY` is valid and encouraged. The failure mode is confident fabrication, not silence.

**Calibration probes**, seeded into the packet: Colorado (caps not removed, SB25-136 died 2025-02-27), Maine (48,216, not the 25,000 currently in the app), New York (the $20,000 exclusion does cover IRA distributions). **Score the model before scoring the states.** A run failing two of three probes is discarded whole rather than adjudicated state by state.

**Consensus rule:** both models confirm plus a primary source in hand, accept and stamp. Any contradiction, John adjudicates against the primary source, no automatic resolution. Both `CANNOT_VERIFY`, the config is left untouched and the jurisdiction is recorded unverified, which then surfaces in the app per §3.5. **Unverified is a legitimate end state.** Model agreement never substitutes for a primary source.

**Citation discipline, added 2026-08-02 after Phase 2 proved it necessary.**

Every fixture carries a `source` citation AND a resolvable `sourceURL`. The loader asserts both are
present and that the URL is https-prefixed. That is a structural control and it works: it caught two
wrong citations in the first three fixtures ever written.

But it has a hard limit, demonstrated concretely in Phase 2: a URL can be well-formed, resolvable,
on-topic, and still not support the specific sentence next to it. `#expect` cannot do semantic
matching.

So Phase 4 carries a PROCESS control that no code can enforce: **the fixture author, and the
reviewer, must each state in their report that they personally opened every `sourceURL` and checked
every clause of `source` against it.** Not "a citation is present". Not "the URL resolves". Every
clause, against the page.

This exists because of a specific failure. The first three fixtures were authored with citations
that were confidently wrong in the way hardest to catch: the expected VALUES were correct, so every
test passed, and the citations read as authoritative. One named the combat-zone pay paragraph of the
Mississippi code instead of the retirement paragraph. One named the Illinois schedule that the
state's own DOR warns causes a double subtraction. A reader following either to check the work would
have found nothing supporting it.

Golden scenarios exist so expected values come from a state's published form rather than from the
engine under test. The citation is the entire mechanism making that auditable. A citation nobody can
follow silently converts the exercise back into trust-me while still looking rigorous.

**Layer 2, golden scenarios. This holds the gate.**

Per jurisdiction, canonical scenarios whose expected state tax is derived from that state's own published form, instructions or worked example, with the form and line numbers cited in the fixture. Stored beside the data as `Resources/StateTaxData/2026/KS.golden.json`.

**Each jurisdiction gets a four-case matrix, not a single case:** single filer below any age threshold, single filer above it, MFJ with both spouses qualifying, and MFJ with only one spouse qualifying. A single minimal case per state would leave an entire tier of this release untested, because the age-gate and per-individual-attribution defects (§3.3e, 13 jurisdictions) are invisible unless the matrix crosses those boundaries. The fourth case is what would have caught Iowa's per-qualifying-spouse rule against the engine's `||` attribution.

States with an AGI phase-out (§3.3d) get a fifth case above the threshold, since for those the conversion itself destroys the exemption and that interaction is the one most likely to be modeled wrongly.

**And at least one of those fifth cases must be MFJ with income between the two thresholds.** Added 2026-08-03 from the Phase 3a Task 4 review, which found this by mutation rather than by argument. The phase-out mechanism selects `thresholdSingle` or `thresholdMFJ` from an `isMarried` flag, and `reduced()`'s own selection is pinned asymmetrically. What is not pinned is that the ENGINE hands it the right flag: hardcoding `isMarried: false` at all three phase-out call sites leaves the entire Phase 3a suite green, because every engine test there is single-only.

Only the band between `thresholdSingle` and `thresholdMFJ` distinguishes the two, so a scenario outside it proves nothing. Virginia is the natural carrier at $50,000 single against $75,000 married: an MFJ filer at $60,000 keeps the full $12,000 under the correct flag and drops to $2,000 under the mutant.

The direction of the error is why this is worth an obligation rather than a note. The mutant makes every married filer phase out at the single threshold, so it errs toward OVER-taxation: Virginia's exclusion disappears $25,000 of income too early, and New Mexico's $8,000 vanishes at $28,501 of joint income instead of $51,001. Nothing about that looks suspicious on screen, which is precisely why a synthetic test was not written for it in Phase 3a and why a real golden scenario has to carry it.

**Every golden scenario asserts against both the single-year path and the multi-year path.** I2, the Kansas multi-year drop and E8's SALT basis mismatch are one bug shape: the two paths disagree while each looks locally correct. A cross-path equality invariant across 51 jurisdictions converts that entire class from a user email into a failing test, and it generalizes to every dimension rather than just retirement exemptions.

User-reported scenarios become permanent golden cases. Steve's Kansas figures and Jonggie F.'s PA scenario are the first two.

### 3.5 Disclosure (Steve's suggestion F)

Generated from the JSON, never hand-written. A prose accuracy page maintained separately from the engine will drift, and a drifted accuracy page is worse than none because it makes a false promise to exactly the users who went looking for the truth.

Per-state "What we model" view: brackets, standard deduction, personal exemption, retirement exemptions with amounts and ages, Social Security treatment, local tax and capital gains, then `knownLimitations` verbatim, then the verification date and source links. Stale beyond 12 months renders a caution badge; beyond 18 months fails a test.

Entry point beside the state tax line in results, not buried in Settings, so it appears when the number matters.

The website's `/accuracy` page consumes the same JSON so app and web cannot make different claims.

**`knownLimitations` carries disproportionate value**: it gives all nine per-source jurisdictions an honest sentence immediately, converting nine silent wrong answers into nine disclosed limitations for the cost of writing sentences.

## 4. Corrections in scope

All defects catalogued in `2026-08-02-full-50-state-verification.md`, applied after that document clears the §3.4 confirmation protocol. Summarized:

- **Tier 1, wrong values (10):** IA, MI, CT, VA, WI, AL, RI, ME, MT, MD. MI, CT, VA overstate exemptions and are the highest-risk of the group.
- **Tier 2, per-source (9):** KS, MA, HI, NY, AZ, NC, ID, VT, DC.
- **Tier 3, attribution and age gates (6):** OK, DE, LA, AR, SC, WV.
- **Tier 4, credits and other (4):** OH, UT, NM credits; WA capital gains, currently modeled as `.noStateTax` against an actual 7% and 9.9% tiered tax.
- **Cross-path defects:** I2 (multi-year drops `postExemptionDeduction`), E8 (SALT cap basis mismatch), Kansas personal exemption in both paths.
- **Stale code comments:** Iowa's "phased out retirement exclusion" claim, Missouri's HB 798 citation (operative bill is HB 426), the TAXSIM header's CO SB25-136 and AL HB388 references.

Explicitly confirmed correct and not to be touched: CO, OK amount, KY, GA, NJ, NY amount, IL, MS, PA, CA, NE, ND, IN, OR, and the no-tax group.

## 4a. Execution model: phases with hard gates

One release, seven phases. **No phase begins until the previous one's gate is green.** Every gate includes the full existing suite (1,570 Swift Testing in 265 suites + 503 XCTest), per CLAUDE.md the suite is the source of truth.

| # | Phase | Gate |
|---|---|---|
| 1 | **Extract to JSON, behavior-inert.** Schema, 51 files generated from the current Swift configs, loader. No corrections, no new fields. | Equivalence test: all 51 jurisdictions produce identical results from JSON as from the hardcoded configs. Suite green. |
| 2 | **Structural safety net.** Remove the California fallback, key configs by tax year, add the constant-law disclosure, build the golden-scenario harness and the cross-path invariant. | Harness runs green against a pilot set drawn from the **confirmed-correct** jurisdictions (PA, IL, MS, CA, NJ). Proving the harness on states known to be right is what establishes that a later failure means the state is wrong rather than the harness. Suite green. |
| 3 | **Schema extensions, still inert.** `personalExemption`, per-source exemptions, AGI phase-out, per-individual and age-gate fields, state-aware minimum age, data-driven Roth conversion rule. Every new field defaults to reproducing today's behavior exactly. | **The Phase 1 equivalence test still passes.** The model got richer and nothing moved. Suite green. |
| 4 | **Golden scenarios, all 51 jurisdictions.** Four cases each, five where an AGI phase-out applies, derived from each state's published form with line numbers cited. Written to reflect **correct law**, not current behavior. | Every case runs. Failures are expected and are the deliverable: a failing golden case is an empirically demonstrated defect, derived from the state's own arithmetic. Catalogue them against the audit's tier list. |
| 5 | **Confirm and correct.** Run the two-model parameter protocol against the Phase 4 failures, then apply corrections tier by tier: 5a values, 5b per-source, 5c attribution and age gates, 5d cross-path (I2, E8, Kansas both paths). | Each sub-phase turns a defined set of golden cases red to green and breaks nothing else. At 5d completion: all golden cases green, cross-path invariant holds across all 51, suite green. |
| 6 | **Disclosure UI.** `knownLimitations` populated for every jurisdiction, per-state "What we model" view, staleness badge, entry point beside the state tax line. | UI tests, suite green, app runs on both platforms. |
| 7 | **Release prep.** Caret scope decision, version bump 63 → 64, release notes with 2-3 wording options per CLAUDE.md. | Full suite green, iOS and macOS builds clean. |

**Why 4 precedes 5.** Writing golden scenarios from primary sources before applying any correction makes them the executable form of the audit. The defect list stops being a research memo and becomes a set of failing tests with a citation to a state form attached to each. The multi-model protocol in Phase 5 then confirms a finding that has already been demonstrated, rather than being the thing that discovers it. Reversing these two would forfeit that.

**Phases 1 and 3 share one property worth naming:** both end with the equivalence test passing. The format changed, then the model got richer, and through both the app computed exactly what it computed before. Every behavior change in this release is therefore isolated to Phase 5, where each one is individually attributable to a named golden case.

## 5. Testing

- **Migration equivalence.** Before any correction, a test asserts all 51 jurisdictions produce identical results from JSON as from the current hardcoded configs. The refactor is proven inert before anything changes.
- **Schema and round-trip.** All 51 files parse, carry required fields including a verification date, and round-trip.
- **Golden scenarios.** 51 jurisdictions × 4 cases (5 where an AGI phase-out applies), each asserted on both the single-year and multi-year paths.
- **Cross-path invariant.** Single-year and multi-year year-1 state tax agree for every golden scenario.
- **Staleness.** Fails when any jurisdiction's `lastVerified` exceeds 18 months.
- **Existing suite stays green.** 1,570 Swift Testing in 265 suites plus 503 XCTest, per CLAUDE.md the suite is the source of truth and a change is not done until it is green.

## 6. Error handling

| Condition | Behavior |
|---|---|
| Missing or malformed JSON | Trap in debug. In release, refuse to produce a state number and say so. Never fall back to another state. |
| Schema mismatch | Caught by test, cannot ship. |
| Projection past last loaded tax year | Explicit "assumes <year> law held constant" disclosure. |
| Jurisdiction unverified | Rendered as unverified in the disclosure view rather than silently presented as authoritative. |

## 7. Risks

- **Golden scenarios are the bulk of the work.** Roughly 51 × reading a state form and deriving an expected figure. This was flagged as a candidate for phased backfill and was explicitly folded into this release.
- **Large release surface.** 29 jurisdictions corrected plus an engine refactor plus a UI feature in one build. Mitigated by the phase gates in §4a: behavior is provably unchanged through Phases 1-3, every behavior change is confined to Phase 5, and each one is attributable to a named golden case with a state form citation. The residual risk is that Phase 4 uncovers substantially more defects than the audit predicted, which would expand Phase 5 rather than threaten it.
- **Per-source model is the largest engine change** and touches nine jurisdictions and two named users. It was considered for a separate spec and folded in here.
- **Alan's caret fix waits.** Owed since 2.3.0 (2026-07-19), and this release extends that. Accepted knowingly.

## 8. Out of scope

Decumulation (Fred, Steve #3), per-year income entry (Alan, Steve suggestion B), Steve's suggestions A/C/D/E, the 2.2 display-audit harness rebase, and the PolicyEngine differential oracle. The oracle was considered as a third verification layer; its public documentation contradicts itself on whether state coverage is seven jurisdictions or all of them, so it needs a spike before it can be relied on and it is not a dependency of anything here.

## 9. Decisions taken here, and the one still open

**Taken:**

- **Golden scenario shape** is the four-case matrix in §3.4, five where an AGI phase-out applies. Resolved against a single minimal case because a whole tier of this release is invisible without it.
- **Models for the parameter protocol** are GPT-5 and Gemini 3 Pro, run cold and independently, matching the Stage-2 display-harness plan. Perplexity acts as a citation-first tiebreaker on contradictions only, never as a third vote, because its value here is retrieval with sources attached rather than judgment. Neither the models nor the tiebreaker can accept a change; §3.4's consensus rule and the golden scenarios do that.

**Still open, and genuinely yours:**

- **Caret fix scope.** `af45404` covers `SettingsView` only. Eight numeric screens remain exposed: `IncomeSourcesView`, `AccountsView`, `RothConversionView`, `QuarterlyTaxView`, `SSDataEntryView`, `TaxPlanningView`, `Year1EditorView`, `YearDetailEditor`. One line each. `IncomeSourcesView` is the sharpest risk. Not a state-tax item, but it rides this release, and the narrow-versus-broad call is a product risk judgment rather than a technical one.
