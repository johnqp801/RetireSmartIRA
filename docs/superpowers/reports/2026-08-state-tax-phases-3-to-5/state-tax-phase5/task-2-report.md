# Task 2 report: Kansas, the personal exemption

## Status: BLOCKED on one test, everything else complete and verified

The production correction is made, both golden and frozen-baseline gates are
green, and Steve Nicolai's exact scenario now computes the promised figure.
One pre-existing Phase 1 gate test fails because keeping it green requires
editing a Swift file, which this task's binding constraints forbid without
stopping to report BLOCKED first. See "The one remaining failure" below for
the full diagnosis and the two paths forward.

---

## 1. The config edit

Only production file changed:
`RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json`.

Added a top-level `personalExemption` object, a sibling of `stateDeduction`
and `retirementExemptions` (not nested inside either), matching New Jersey's
shape:

```json
"personalExemption" : {
  "marriedFilingJointly" : 18320,
  "seniorAdditionalPerFiler" : 0,
  "seniorAge" : 65,
  "single" : 9160
},
```

Values are Kansas SB1 (2024 special session): $9,160 single, $18,320 married
filing jointly. `seniorAdditionalPerFiler` is 0 because Kansas has no senior
addition.

Confined diff (production files only):

```
diff --git a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
index 0170ebf..25535e0 100644
--- a/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
+++ b/RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
@@ -9,6 +9,12 @@
   },
   "hsaContributionsTaxableForState" : false,
   "otherPreTaxDeductionsTaxableForState" : false,
+  "personalExemption" : {
+    "marriedFilingJointly" : 18320,
+    "seniorAdditionalPerFiler" : 0,
+    "seniorAge" : 65,
+    "single" : 9160
+  },
   "pretax401kContributionsTaxableForState" : false,
   "retirementExemptions" : {
     "capitalGainsTreatment" : "followsFederal",
```

No other production file changed. `git status --porcelain` confirms exactly
one modified file under `RetireSmartIRA/`.

---

## 2. Dependent-modeling finding and the scope decision

Kansas SB1 also sets $2,320 per dependent. I grepped the codebase for a
dependent-count input before deciding anything:

- `StatePersonalExemption` (`RetireSmartIRA/StatePersonalExemption.swift`)
  has exactly four fields: `single`, `marriedFilingJointly`,
  `seniorAdditionalPerFiler`, `seniorAge`. No dependent field.
- A broad grep for "dependent" across `RetireSmartIRA/` turned up no tax-
  dependents input anywhere in the app (the closest hits are
  `dependentOnlyYears` in `FundingFeasibilitySummary.swift`, an unrelated
  funding-feasibility concept, and a Kiddie Tax disclosure string that
  explicitly says the scenario is "not modeled here").

**Decision:** the correction is scoped to the single and married filing
jointly amounts only. The $2,320 per-dependent amount is NOT modeled and is
NOT folded into either base figure, because doing so would invent a
household composition the user never described and would misstate the
number for the single/no-dependent filers who are the app's typical case.

This is stated in the code (no change needed there, the struct already had
no such field) and recorded explicitly in the golden fixture as a new
top-level `personalExemptionScopingNote` key (harmless to the decoder, which
ignores unknown keys):

> "Kansas SB1 (2024 special session) sets $9,160 single, $18,320 married
> filing jointly, and $2,320 per dependent. StatePersonalExemption... has no
> dependent-count field, and a codebase grep found no dependent-count input
> anywhere in the app... The Phase 5a Task 2 correction is therefore scoped
> to the single and married filing jointly amounts only; the $2,320
> per-dependent amount is NOT modelled and is not folded into either base
> figure. None of the scenarios in this file describe a household with
> dependents, so no expectedStateTax value here is affected by this gap."

---

## 3. Steve Nicolai's scenario, explicitly

**Before this fix:** $2,171.52 (engine taxed the full $50,000 minus only the
$8,240 MFJ standard deduction, with no personal exemption).

**After this fix:** the golden suite confirms the engine now computes
**$1,218.88** for Steve Nicolai's exact scenario ($50,000 MFJ ordinary
income, no pension), matching the Kansas Department of Revenue's own
published form to the cent
($50,000 - $8,240 standard deduction - $18,320 personal exemption = $23,440
taxable x 5.2% = $1,218.88).

This is measured, not predicted: the golden test failure before I deleted
the `knownDefect` block read `"... now MATCHES its published form
(1218.88)"`.

---

## 4. `knownDefect` blocks: deleted vs. remaining

Six cases in `statetax-2026-KS.golden.json`. Three deleted, three remain.

**Deleted (personal-exemption defect resolved):**

1. **KS-1** ("Steve Nicolai's reported scenario...") -- engine now matches
   $1,218.88 exactly.
2. **KS-2** ("single filer, ordinary income, the same missing personal
   exemption...") -- engine now matches $896.22 exactly.
3. **KS-3** ("single filer, private pension: correctly fully taxable...")
   -- engine now matches $1,432.31 exactly. This is the contrast case that
   isolates the personal-exemption defect from the per-source defect; it
   confirms the ONLY gap here was the personal exemption.

**Remain, by design (per-source defect, out of scope for Task 2):**

4. **KS-4** ("single filer, KPERS pension...") -- still fails against its
   $0.00 published form. `observedToday` updated from 1943.44 to **1432.31**
   (measured): the personal-exemption fix changed what the still-defective
   engine returns (it now equals KS-3's figure exactly, since KPERS is still
   pooled as ordinary income identically to a private pension).
5. **KS-5** ("MFJ, both spouses have exempt pensions...") -- still fails
   against its $0.00 published form. `observedToday` updated from 2171.52 to
   **1218.88** (measured): same mechanism, now equals KS-1's corrected
   figure because per-source is still unmodeled.
6. **KS-6** ("MFJ, one spouse's KPERS pension is exempt and the other
   spouse's private pension is not... COMBINED case") -- **still fails by
   design.** Its own summary explicitly predicted this: with only the
   personal-exemption fix applied, the case computes $1,218.88, not the
   $0.00 its published form requires. `observedToday` updated from 2171.52
   to **1218.88** (measured, and it now exactly equals the case's own
   pre-written prediction for "personal-exemption fix only"). I did not
   delete this block and did not otherwise change its logic; I only updated
   the number and the trailing sentence of its summary (which previously
   said "today the engine has neither fix," no longer true) to state
   plainly that the personal-exemption fix is now present. This case will
   not go green until Phase 5b's `perSourceExemptions` work lands.

---

## 5. Baseline movements

**None recorded. This is a measured finding, not an oversight.**

I ran `RetireSmartIRATests/StateTaxBehaviorBaselineTests` (the frozen 1,020-
entry gate) both before and after the config edit. All 51 jurisdictions x 20
scenarios passed with zero issues both times -- including Kansas.

Diagnosis: `StateTaxBehaviorBaselineTests.computedTax` calls
`TaxCalculationEngine.calculateStateTax` directly and passes
`postExemptionDeduction` as an explicit **literal** per scenario (0 for most
KS-relevant rows, a generic 1,000/2,000 for a couple of rows that exist to
exercise the NJ-style pass-through mechanism, unrelated to Kansas).
`calculateStateTax` never reads `config.personalExemption` itself -- it only
subtracts whatever `postExemptionDeduction` it is handed
(`TaxCalculationEngine.swift:392`). Computing `config.personalExemption` and
folding it into that parameter is the caller's job (`DataManager.swift:663,
1072`), and the frozen-baseline gate does not exercise that caller by
design -- its own doc comment at `StateTaxBehaviorBaselineTests.swift:81-87`
says explicitly: "It does NOT guard personal-exemption logic:
`calculateStateTax` never computes that, it receives the already computed
figure as `postExemptionDeduction`, passed here as a literal. The guard for
that logic is `NJOtherExclusionAndExemptionsTests`."

So the Task 2 brief's stated expectation ("every Kansas key whose scenario
has taxable income" should move) did not materialize, and the measured
result (zero movements, verified by two full runs of the baseline suite) is
authoritative over that prediction. `statetax-behavior-movements-2026.json`
is left as `[]`, unmodified -- adding fabricated entries for values that did
not move would violate the ledger's own well-formedness test
(`abs(before - after) >= 0.005`).

---

## 6. The one remaining failure

Full suite: **1,857 Swift Testing tests in 293 suites, 1 issue** + **509
XCTest, 0 failures**.

```
✘ Test "Re-encoding the JSON-loaded config is byte-identical to re-encoding
the legacy config" recorded an issue with 1 argument state → .kansas at
StateTaxJSONEquivalenceTests.swift:560:9: Expectation failed:
(jsonEncoded → 1715 bytes) == (legacyEncoded → 1570 bytes)
```

**Diagnosis.** This is the Phase 1 Layer B gate
(`StateTaxJSONStructuralEquivalenceTests.structurallyIdentical`), which
re-encodes the JSON-loaded config and a hardcoded Swift mirror
(`StateTaxData.configs2026Legacy`, in the PRODUCTION file
`RetireSmartIRA/StateTaxData.swift`) and requires them byte-identical, for
every state. `configs2026Legacy` is a defensive fallback used only if the
bundled JSON fails to load (`StateTaxData.swift:2290-2298`); its own doc
comment calls that path "unreachable in practice" since both tables are
complete for every `USState` case. The JSON path is what actually ships and
loads in production.

Kansas's entry in `configs2026Legacy` was written before this task and has
no `personalExemption` literal, so it no longer matches the JSON I just
edited. New Jersey's `personalExemption` is present in BOTH places already
(Phase 3a added it to the legacy mirror too, per the comment at
`StateTaxData.swift:1839-1842`: "a lift-and-shift of njPersonalExemptions...
not a Phase 3a correction"), which is why NJ's Layer B check still passes
and Kansas's is the only one that broke.

**Why I did not fix it.** The fix is a one-literal addition to
`configs2026Legacy[.kansas]` in `StateTaxData.swift` -- a Swift file. This
task's binding constraints are explicit: "The ONLY production file you may
change is `statetax-2026-KS.json`. No Swift file. If you believe a Swift
change is needed, STOP and report BLOCKED: that would mean the scope
boundary was drawn wrongly, which is worth knowing immediately." I have not
touched `StateTaxData.swift` or any other Swift file.

**Production impact today: none.** `TaxCalculationEngine.config(for:)`
tries `configs2026` (JSON) first and only falls back to `configs2026Legacy`
if that lookup fails, which does not happen in the shipped app. Every user
gets the corrected $1,218.88 figure right now. The divergence is confined to
an unreachable defensive fallback and a test that guards it.

**Two ways to close this, for the coordinator to choose between:**

(a) Widen this task's scope by exactly one Swift file: add the identical
    `personalExemption: StatePersonalExemption(single: 9_160,
    marriedFilingJointly: 18_320, seniorAdditionalPerFiler: 0, seniorAge:
    65)` literal to `StateTaxData.configs2026Legacy[.kansas]`, mirroring
    exactly what Phase 3a did for New Jersey. This is additive data, not new
    logic, and keeps the fallback path correct too.

(b) Leave it as a tracked, deliberate gap (the fallback path is
    unreachable in practice) and file it as Phase 5a follow-up work,
    updating the Layer B test's own documentation to note the known
    exception until (a) lands.

I did neither without direction, per the binding constraint.

---

## 7. Other suites: full output

`RetireSmartIRATests/GoldenScenarioSingleYearTests` (after both edits):

```
✔ Test "Single-year path matches each state's own published form" with 50 test cases passed after 0.041 seconds.
✔ Test "classify covers all five outcomes of the defect-pin decision" passed after 0.001 seconds.
✔ Test "A fixture with no knownDefect decodes it as nil" passed after 0.001 seconds.
✔ Test "The .conformsToFederal branch deducts the age-65+ addition and OBBBA senior bonus" passed after 0.001 seconds.
✔ Suite "Golden scenarios, single-year path" passed after 0.042 seconds.
✔ Test run with 4 tests in 1 suite passed after 0.042 seconds.
```

`RetireSmartIRATests/StateTaxBehaviorBaselineTests`:

```
✔ Test "Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline" with 51 test cases passed after 0.048 seconds.
✔ Suite "PHASE 3a GATE: state tax behavior baseline" passed after 0.049 seconds.
✔ Test run with 1 test in 1 suite passed after 0.049 seconds.
```

Full suite (`xcodebuild test`, no `-only-testing` filter), before the two
Phase-3a-scoped test updates in section 8 below:

```
✘ Test "Exactly one jurisdiction ships a personalExemption key in Phase 3a" recorded an issue at StateTaxJSONEquivalenceTests.swift:650:9: Expectation failed: (carriers → ["KS", "NJ"]) == ["NJ"]
✘ Test "New Jersey's config carries the personal exemption; no other state does" recorded an issue at StateTaxPhase3aMechanismTests.swift:192:17: Expectation failed: (config.personalExemption → StatePersonalExemption(single: 9160.0, marriedFilingJointly: 18320.0, seniorAdditionalPerFiler: 0.0, seniorAge: 65)) == nil
✘ Test run with 1857 tests in 293 suites failed after 318.318 seconds with 3 issues.
```

Full suite, after the two test updates (final state, one remaining issue,
diagnosed in section 6):

```
✘ Test "Re-encoding the JSON-loaded config is byte-identical to re-encoding the legacy config" recorded an issue with 1 argument state → .kansas at StateTaxJSONEquivalenceTests.swift:560:9: Expectation failed: (jsonEncoded → 1715 bytes) == (legacyEncoded → 1570 bytes)
✘ Test run with 1857 tests in 293 suites failed after 312.195 seconds with 1 issue.
	Executed 509 tests, with 0 failures (0 unexpected) in 21.267 (21.616) seconds
Test Suite 'All tests' passed at 2026-08-04 20:48:10.458.
Failing tests:
	-[StateTaxJSONStructuralEquivalenceTests structurallyIdentical(state:)]
** TEST FAILED **
```

Full log saved at
`/private/tmp/claude-501/-Users-johnurban-Projects-RetireSmartIRA/35a1e769-e7eb-4569-9b30-0b84ac041d5b/scratchpad/ks-full-suite.log`.

---

## 8. Other suites that moved, and why (legitimate, per Step 9)

Two Phase-3a-era tests encoded "New Jersey is the only carrier of
`personalExemption`" as a literal assertion. Both names and bodies say
"Phase 3a" explicitly, and one of them (`StateTaxPhase3aMechanismTests.swift`
line 196, before my edit) even said outright: "Kansas and the rest are
Phase 5a" -- i.e. this exact test was written expecting to need updating
once Kansas's fix landed. I updated both to assert the new, correct set of
carriers (`{KS, NJ}`) rather than weakening either into an allow-anything
check:

- `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`: renamed
  `onlyNewJerseyShipsAPersonalExemptionKey` to
  `onlyNewJerseyAndKansasShipAPersonalExemptionKey`, now asserts
  `carriers.sorted() == ["KS", "NJ"]`. Doc comment on
  `optionalTopLevelKeys` updated to name both states.
- `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`: renamed
  `onlyNewJerseyCarriesAPersonalExemptionInPhase3a` to
  `onlyNewJerseyAndKansasCarryAPersonalExemption`, now checks
  `[.newJersey, .kansas]` as the carrier set and asserts every other state
  is still `nil`.

Both are TEST files under `RetireSmartIRATests/`, not production files, so
editing them is within the binding constraints.

---

## 9. Em dash check

Grepped every touched file (the KS production JSON, the KS golden fixture,
and both updated test files) for the em dash character (U+2014). None
found in any of the four.

---

## 10. Commit

**Not committed.** Per the binding constraint "Tests are the source of
truth... Not done until the full suite is green," and per the explicit
instruction to stop rather than work around a Swift-file requirement, I am
leaving the four modified files staged-but-uncommitted in the worktree
pending a decision on section 6's two options. `git status --porcelain`:

```
 M RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
 M RetireSmartIRATests/GoldenScenarios/statetax-2026-KS.golden.json
 M RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift
 M RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift
```

---

## 11. Unblocking (this session): the decision, implemented

The coordinator decided between section 6's two options: neither, exactly.
The legacy table is frozen at pre-correction law (not deleted, not kept
updated), and the equivalence gate is scoped to jurisdictions Phase 5 has
corrected. Implemented as three pieces.

**a. The corrected-jurisdictions list.** Added
`StateTaxJSONStructuralEquivalenceTests.phase5CorrectedJurisdictions: Set<USState>`
in `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`, immediately
above `structurallyIdentical`. Currently `[.kansas]`. Its doc comment
states plainly where to append for later Phase 5 tasks and what the list
means: not "skip," but "these two MUST differ."

**b. The assertion now has two branches.** For a state on the list,
`structurallyIdentical` now asserts `jsonEncoded != legacyEncoded` (with a
failure message naming exactly what a false match would mean: reverted
correction or an edited legacy table). For every other state, the original
`==` assertion is unchanged. This required rewording the `@Test` title to
a triple-quoted string literal, since string concatenation is not a
compile-time constant Swift's `@Test` macro accepts (`+` on two literals
failed to compile with "expect a compile-time constant literal"); the
`Self.firstDivergence` helper is untouched.

**c. The doc comment on `configs2026Legacy`** (`RetireSmartIRA/StateTaxData.swift`,
directly above the declaration) now states: frozen at pre-Phase-5 law;
still a live fallback reached only when the bundled JSON fails to load; a
user in a corrected jurisdiction hitting that fallback would silently get
pre-correction rules; and it must not be hand-updated to match
corrections, because `phase5CorrectedJurisdictions` is what encodes the
intended divergence, not this comment. This is the ONLY change to any
Swift file; it is comment-only, verified below.

**Divergence-probe proof (step 3).** Temporarily removed the
`personalExemption` block from `statetax-2026-KS.json` (Edit tool, not
committed) and re-ran `StateTaxJSONStructuralEquivalenceTests` alone. It
failed on exactly `.kansas`, message verbatim:

```
✘ Test "Re-encoding the JSON-loaded config is byte-identical to re-encoding
the legacy config, except for jurisdictions Phase 5 has corrected, which
must diverge" recorded an issue with 1 argument state → .kansas at
StateTaxJSONEquivalenceTests.swift:584:13: Expectation failed:
(jsonEncoded → 1570 bytes) != (legacyEncoded → 1570 bytes)
KS is listed in phase5CorrectedJurisdictions, so its corrected JSON is
expected to diverge permanently from the frozen legacy table
(configs2026Legacy is deliberately not updated alongside corrections).
Byte-identical here means either the correction was reverted from the
JSON or the legacy table was edited to match it; both are failures that
need fixing, not this test.
```

All 50 other jurisdictions passed in that same run; only Kansas failed.
Restored the JSON block immediately after, then confirmed the restore with
`git diff -- RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json`,
which shows only the original 6-line `personalExemption` addition, nothing
else.

**Focused suite** (`StateTaxJSONEquivalenceTests`, `GoldenScenarioSingleYearTests`,
`StateTaxBehaviorBaselineTests`): 6 tests in 3 suites, 0 failures.

**Full suite:** 1,857 Swift Testing tests in 293 suites passed (317.5s) +
509 XCTest, 0 failures, 21.8s. 6 skips, all pre-existing and expected (4
`RUN_AUDIT_HARNESS`-gated tests + 2 fixture-generator tests). Matches the
baseline exactly: 1,857 + 293 + 509 + 6 skipped. Did not isolate
`MultiYearPerfTests` separately since the full run had zero failures (no
flake observed this run).

**Production diff confinement (step 6):**

```
git diff --stat main -- RetireSmartIRA/
 .../StateTaxData/2026/statetax-2026-KS.json         |  6 ++++++
 RetireSmartIRA/StateTaxData.swift                   | 21 +++++++++++++++++++++
 2 files changed, 27 insertions(+)
```

Exactly two files, as required. Read the full `StateTaxData.swift` diff
directly: every added line (21 insertions, 0 deletions) is a `///` doc
comment line above the existing `static let configs2026Legacy` declaration.
No braces, no code, no data. Confirmed comment-only.

**Frozen baseline file:** `git diff --stat main -- '**/statetax-behavior-baseline-2026.json'`
produced no output. Untouched.

**Em dash check (step 8):** re-ran across the diff of every file touched
this session, plus the two files from section 9 already checked. All
clean.

**Commit:** all five modified files (the Kansas JSON and golden fixture
from the earlier, blocked pass; both Phase 3a-era test renames; and this
session's two files) committed in one commit. SHA and message below.

---

## 12. Commit record
