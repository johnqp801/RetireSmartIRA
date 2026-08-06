# Task 10 report: Close Phase 5b

Reporting task. **No tax behaviour changed.** No pin, `knownDefect` block, frozen baseline or
shipped config was touched. No decided jurisdiction was re-opened.

## 0. Pre-flight, printed and verified before the first edit

```
worktree : /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase5b
branch   : feature/state-tax-phase5b
HEAD     : cac85bd3005ea901dbb798a90f9718bd99174640
status   : clean (git status --porcelain empty)
```

**ONE BRIEF CORRECTION, and it changes how the diff must be taken.** The brief says "Branch point
off main: c5a7bce". `c5a7bce` IS an ancestor of HEAD and IS the branch point, but `main` was merged
INTO the branch at `b0039d3` to pick up the test wrapper, so `git merge-base HEAD main` returns
`378c110`, not `c5a7bce`. Consequences:

- Every diff in this report is `main...HEAD` (three dots, i.e. against `378c110`). A two-dot
  `main..HEAD` would additionally show `main`'s own wrapper commit as a deletion, and a naive
  `git diff c5a7bce HEAD` would attribute `tools/run-tests.sh` and two docs commits to this phase.
- The defect BASELINE, however, is correctly taken at `c5a7bce`, because that is where the "99
  across 32" figure was established and the three commits `main` gained since then touch no
  fixture. Verified: the 5a-close count reproduces exactly at `c5a7bce` (below).

Both facts are now recorded in the ledger and in RESUME-HERE.

## 1. Step 1: THE COUNT, derived with the command shown

Command against the committed branch:

```bash
grep -c '"knownDefect"' RetireSmartIRATests/GoldenScenarios/*.golden.json \
  | grep -v ':0$' | sed 's#.*/statetax-2026-##; s/\.golden\.json//' | sort
```

and the same parse against `c5a7bce` via `git show`.

```
Phase 5a close (c5a7bce):  99 defect cases across 32 jurisdictions   <- brief's baseline, REPRODUCED
Phase 5b close (cac85bd):  88 defect cases across 29 jurisdictions
NET:                      -11 cases, -3 jurisdictions
```

**Gross, because net understates the work in both directions:**

```
blocks DELETED:  12   AZ 3, DC 3, KS 3, MA 3
blocks ADDED:     1   ID-8
net:            -11
```

Golden scenarios overall: **207 -> 218** across the same 50 fixtures. **11 new cases, 10 of them
guards carrying no `knownDefect` at all** (AZ 4, KS 2, ID 2, DC 1, NC 1), plus ID-8.

Per-jurisdiction delta, every line derived:

| State | 5a close | 5b close | Delta | What happened |
|---|---|---|---|---|
| AZ | 4 | 1 | -3 | AZ-2, AZ-3, AZ-5 resolved. **AZ-4 deliberately pinned.** 4 guard cases ADDED (case count 5 -> 9). |
| DC | 3 | 0 | -3 | DC-2, DC-3, DC-4 resolved. DC-6 (Maryland survivor guard) added. |
| KS | 3 | 0 | -3 | KS-4, KS-5, KS-6 resolved. KS-7 and KS-8 guards added (case count 6 -> 8). |
| MA | 3 | 0 | -3 | MA-1, MA-3, MA-4 resolved. No cases added. |
| ID | 4 | **5** | **+1** | **All four originals INTACT.** ID-8 added as a new PINNED cap guard; ID-6 and ID-7 added as non-defect guards (case count 5 -> 8). |
| HI | 3 | 3 | 0 | Unchanged, by decision. No config and no production Swift changed for Hawaii at all. |
| NC | 3 | 3 | 0 | Unchanged, by decision. NC-5 added as a non-defect guard (case count 4 -> 5). |
| VT | 6 | 6 | 0 | Unchanged, by decision. No cases added. |
| all others | | | 0 | Untouched. |

**The brief's expected shape checked line by line.** "Kansas: all defects resolved" TRUE. "Arizona:
three resolved, one deliberately pinned" TRUE. "DC: three resolved" TRUE. "Massachusetts: three
resolved" TRUE. "Hawaii, North Carolina, Idaho, Vermont: deliberately UNCHANGED, all blocks intact"
TRUE for all four; note the wording needs care for Idaho, whose blocks are all intact but whose
COUNT ROSE to five. "Arizona and Idaho both added cases" TRUE, but they added different KINDS:
Arizona's four are all guards with no defect, Idaho's three include one new pin.

A second count moved further than the pins did and belongs in any honest summary:
**`GoldenScenarioDefectCatalogueTests.knownButUnpinned` went from 1 entry to 11.** At `c5a7bce`
only Missouri's existed; this phase added AZ x2, KS, MA x2, HI, NC x2, ID and DC. Most of what 5b
learned is a defect no fixture can hold.

## 2. Step 2: full suite

See section 8. Run in the foreground with `tools/run-tests.sh`, at the committed state.

## 3. Step 3: PRODUCTION INVENTORY. The plan's premise did not survive, and here is the real diff.

The plan asked me to "show that the Swift diff is confined to the model extension and that no
engine logic changed beyond consuming new fields." **Both halves are false and I am not going to
massage them.** What follows is the full inventory from `git diff main...HEAD -- RetireSmartIRA/`.

**20 production files changed: 15 Swift, 5 shipped JSON configs. 1,180 insertions, 98 deletions.**

### 3.1 Additive model extension (the part the plan did anticipate)

| File | Change | Task |
|---|---|---|
| `RetirementPlanClassification.swift` | +3 `PlanSource` cases (`ownStateOrLocal`, `uniformedServices`, `railroadRetirement`), `isSurvivorBenefit: Bool?`; and a whole new `UnclassifiedPensionDisclosure` enum with a `Scope` and `{scope}` token | 1, 3b |
| `IncomeModels.swift` | `IncomeSource.isSurvivorBenefit: Bool?` + `CodingKeys`. **A persisted user-data field.** | 9 |
| `RetirementDistributionComponent.swift` | The same flag on the in-memory component | 9 |
| `StateTaxData.swift` | `unclassifiedPensionDisclosure: String?` on `RetirementIncomeExemptions`; `matchedPerSourceRule` widened | 3b, 9 |
| `StateTaxCodable.swift` | encode/decode for that string, `encodeIfPresent` so 49 files stay byte-identical | 3b |

### 3.2 NEW MATCHING BEHAVIOUR. This is where the premise breaks first.

| File | Change | Task |
|---|---|---|
| `PerSourceExemptionRule.swift` | **Two new matching dimensions**, `matchIsSurvivorBenefit` and `matchMinAge`, and `matches()` widened by two defaulted parameters. Task 1 had left `matches()` byte-for-byte unchanged on purpose; Task 9 changed it. | 9 |
| `TaxCalculationEngine.swift` | `ageOf(_:)` owner-age resolver; `componentRule(_:)` replacing two inline filters so the flag and the owner's age reach matching | 9 |
| `DataManager.swift` | The same two in the breakdown mirror, **plus** `incomeSources(asResidentOf:)`, a residence remapping applied to pension and RMD rows. That is a suppression predicate, not a field read. | 3, 9 |
| `MultiYearInputAdapter.swift` | The survivor flag travels with the pooled classification, with a deliberate disagreement-falls-back-to-nil rule | 9 review |
| `ProjectionEngine.swift` | The flag forwarded into each projected year's components | 9 review |

The last two exist because of a review finding worth keeping: without them, single-year State
Comparison would drop a qualifying DC survivor annuity to $0 while every year of the Multi-Year
projection kept taxing it in full. **DC is the first jurisdiction whose discriminant is not fully
described by `(structure, source)`, which is why New York, Kansas, Massachusetts and Arizona never
exposed those two sites.**

### 3.3 USER-FACING. The plan did not anticipate any of this.

| File | Change | Task |
|---|---|---|
| `IncomeSourcesView.swift` (+447) | Three new picker rows; `options(for:selected:)` suppression; `jurisdictionNamedSources`; `residenceUsesSurvivorDimension`; the DC survivor toggle and caption; NC, ID and VT captions | 3, 7, 8, 9 |
| `AccountsView.swift` | The account picker uses the same suppression | 3 |
| `StateComparisonView.swift` | The unclassified-pension banner stops hardcoding New York, reads the VIEWED state's config | 3b |
| `MultiYearCPABriefing.swift` | The same for the briefing, gating on RESIDENCE. The asymmetry is deliberate and now structural. | 3b |
| `MultiYearPlanView.swift` | The call site | 3b |

### 3.4 Shipped config

`statetax-2026-KS.json`, `-MA.json`, `-AZ.json`, `-DC.json`: each gains `perSourceExemptions` and an
`unclassifiedPensionDisclosure` sentence. `-NY.json`: gains only the sentence, hoisted out of Swift.
No other jurisdiction's file changed.

### 3.5 Why the premise failed, in three steps

1. **Task 3.** A controller audit before dispatch found `PlanClassificationChoice`, the enum driving
   the user-facing picker, is SEPARATE from `PlanSource` and had no option writing any of Task 1's
   three new cases. A correct Kansas rule would have turned every golden case green while a real
   KPERS holder got nothing. John chose to add all three rows once.
2. **Task 3b was not in the plan at all.** It exists because Kansas shipped a correct rule and got
   neither the classification prompt nor the disclosure New York got, and fixing that meant two
   view layers.
3. **Task 9.** The survivor dimension had to be threaded end to end, plus a whole new `matchMinAge`
   the brief's own dependency chain omitted.

### 3.6 The narrower claim that IS true, and is worth keeping

**No jurisdiction's numbers move without a config opting in.** Task 1 proved inertness with New York
as the canary and 20 exclusivity tests proving both directions for every new-versus-old `PlanSource`
pair. Every numeric movement in this phase is attributable to one of four `perSourceExemptions`
blocks. That is a weaker guarantee than the plan wanted, and it is the one that actually held.

## 4. Step 4: THE KANSAS PROMISE

**Kansas is complete.** Two defects: Phase 5a fixed the personal exemption, Phase 5b Task 3 fixed
the retirement exclusion. Zero pinned defect cases, two permanent guards (KS-7 California, KS-8
unestablished jurisdiction). **Complete in the engine AND selectable in the app**, and the second
half was never true before Task 3 added the picker rows. Steve Nicolai's report is fully addressed.
That has not been true of any jurisdiction at any prior point in this program.

Two caveats, stated because a bare "complete" would overclaim. **Neither touches a Kansas KPERS
holder who classifies their pension, which is the reported case, so the claim is sound for that
user:**

1. **TSP.** Schedule S Line A14 also names Thrift Savings Plans, which are defined-contribution;
   the rule matches `definedBenefit` only, so a Kansas TSP holder is still taxed in full. Recorded
   in `knownButUnpinned`. Deliberate and the safer error: Line A14 names "KPERS ANNUITIES", not the
   separate KPERS 457 plan, so dropping the structure constraint would grant an unauthorised full
   exclusion to every government salary-reduction plan. Also unpinnable, since no picker row writes
   a federal defined-contribution plan.
2. **`ownStateOrLocal` goes stale on a residence change**, erring toward UNDER-taxation. Task 3
   closed the COMPARING route and not the MOVING route, and its commit message says so.

An earlier caveat is CLOSED by Task 3b: an unclassified Kansas pension used to get no warning while
an identically-placed New York user was warned on two surfaces.

## 5. The four no-rule jurisdictions, as decisions

Written up in full in the ledger. In brief, and none is a to-do item: Hawaii, North Carolina, Idaho
and Vermont each ship nothing by a reviewed decision, each keeps all its `knownDefect` blocks, and
each carries guard cases where guards were expressible, a `knownButUnpinned` entry with a deletion
guard, and a caption. In every one of the four **the green outcome was AVAILABLE and MEASURED, and
it was wrong in the UNDER-taxation direction.**

**Vermont is the phase's most important single finding.** Task 1's extension dissolved exactly the
source collision it was built for, and Vermont is STILL unsatisfiable, because the binding
constraint was never sources: Vermont needs two exclusions with different caps AND different AGI
bands, and its CSRS exclusion applies "only to benefits not covered by the Social Security Act",
which `federalCivilian` cannot express because that case covers CSRS and FERS. **Task 1 extended the
WHO axis; Vermont's remainder lives on the HOW MUCH and WHEN axes.** Vermont also carries the
largest gap in the phase, $5,211.50 a year at VT-6's shape (observed $8,086.65 against expected
$2,875.15), verified from the fixture.

## 6. FOUR ITEMS AWAITING JOHN, recorded as PENDING and not as settled

1. DC's `unclassifiedPensionDisclosure` sentence (`statetax-2026-DC.json`).
2. DC's survivor toggle label and its explanatory caption (`IncomeSourcesView.swift`).
3. Vermont's caption (`IncomeSourcesView.swift`).
4. The Vermont hold-versus-ship judgement call. **Implementer, reviewer and controller all
   recommend HOLD. John has not answered.**

Verified in the tree: three of the four carry "PROPOSED COPY, AWAITING JOHN" markers at
`IncomeSourcesView.swift:456`, `:1481`, `:1563`, `Phase5bDCSurvivorTests.swift:727` and
`Phase5bVermontDecisionTests.swift:344`. The DC JSON sentence carries its marker in the Task 9
report (section 6.1) instead, since JSON takes no comment. Every other Phase 5b copy item is
approved (decisions log, 2026-08-05, three entries).

## 7. Step 5: the ledger

Written to `.claude/memory/roadmap/2026-08-04-state-tax-phase5b-ledger.md`, following the Phase 5a
ledger's shape, with the Phase 6 inheritance organised BY MISSING MODEL FIELD:

1. An employee-contributory axis (MA categorical, HI proportion). Assigned to Phase 6 by John.
   Explicitly NOT recorded as unvalidatable for Hawaii: a fixture could stipulate the share as an
   input, and the real obstacles are a field, an affordance, and whether a user can compute it.
2. A vesting-date or Bailey-class fact (NC). Buildable, declined, with the reasons to weigh.
3. An eligibility fact plus a second age gate over one shared cap (ID). Notes that `matchMinAge`
   already shipped, so half the earlier ask is done.
4. A second capped pool and a second AGI phase-out band (VT), plus a `matchMaxIncome` sibling, plus
   the income-basis decision and the VT-7 fixture ($130,000 AGI, $172.53) that would pin it.
5. Per-taxpayer exemption attribution (AZ-4), also unpinnable for lack of an owner field.
6. Residence-relative source labels (`ownStateOrLocal` staleness).
7. A structural fix for the capped per-source treatment.
8. One fact with two encodings (`IncomeType.militaryRetirement` vs `PlanSource.uniformedServices`).

Plus the disclosure finding (three surfaces all gate on "did this state ship rules"; four
jurisdictions now fail all three; `knownButUnpinned` has no production consumer).

`.claude/memory/roadmap/2026-08-05-state-tax-phase5b-RESUME-HERE.md` was brought up to date: its
header said "ready to run Task 7" and its resume block pointed at Task 3 and HEAD `e5acef4`. It now
opens with the phase-close state, the four pending items and the Vermont finding, adds outcome
sections for Tasks 7, 8 and 9, and corrects two standing rules that had gone stale (the test wrapper
now exists; `phase5CorrectedJurisdictions` now has nine members, not six).

`.claude/memory/roadmap/2026-08-05-disclosure-surfaces-miss-the-no-rule-case.md` gained a dated
amendment only: it was written at Task 8 and its two counts (three jurisdictions, eight
`knownButUnpinned` entries) were both moved by Task 9. Nothing in it was retired.

## 8. Full suite gate

Run in the FOREGROUND at the committed state, `timeout: 600000`:

```
tools/run-tests.sh
```

Wrapper header (it derives the project from its own location, so this confirms it built THIS
worktree at THIS commit rather than a sibling checkout):

```
Project:  .../.worktrees/state-tax-phase5b/RetireSmartIRA.xcodeproj
Branch:   feature/state-tax-phase5b @ faf79b1
```

RESULT:

```
Swift Testing:  Test run with 2020 tests in 304 suites passed
XCTest:         Executed 509 tests, with 0 failures (0 unexpected)
PASS. 2529 test(s) ran, no failures.
```

Matches the brief's stated current state exactly (2,020 Swift Testing in 304 suites + 509 XCTest, 0
failures). **`MultiYearPerfTests` did NOT flake on this run**, so the wrapper's isolation re-run was
never triggered and there is nothing to qualify.

## 9. Constraints checked

- `rulesAndDisclosuresStayInLockstep` present and untouched
  (`Phase5bUnclassifiedPensionDisclosureTests.swift:193`).
- All 11 `knownButUnpinned` entries, their deletion guards and all six captions present and
  untouched.
- `git diff main...HEAD -- RetireSmartIRA/ RetireSmartIRATests/` identical before and after this
  task. Task 10 touched only three markdown files under `.claude/memory/roadmap/` plus this report.
- No em dash characters in anything written here. `grep -c` returns 0 on all four files.
