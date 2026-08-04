# State Tax Phase 4: Golden Scenarios for All 51 Jurisdictions: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every one of the 51 jurisdictions carries hand-derived golden scenarios written to CORRECT LAW, so that each of the ~29 defects the audit predicted becomes a named, pinned, citable failing case rather than a research memo.

**Architecture:** Extend the existing `GoldenScenario` fixture format with a `knownDefect` block. A fixture without one asserts the engine matches the state's published form. A fixture WITH one asserts the engine matches today's observed (wrong) figure AND does *not* match the form, so the suite stays green while every defect is pinned, and the moment Phase 5 corrects a state the assertion fails and forces the block's removal. The harness stops reading a hand-maintained pilot array and drives every `USState.allCases` entry instead.

**Tech Stack:** Swift Testing (`@Suite`/`@Test`/`#expect`), JSON fixtures in `RetireSmartIRATests/GoldenScenarios/`, `xcodebuild test` on macOS.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md`. §3.4 governs fixture shape and citation discipline; §4a defines this phase's gate.
- **Phase 4 corrects NO tax value.** Not one line of `StateTaxData.swift`, `TaxCalculationEngine.swift` or any `Resources/StateTaxData/2026/*.json` changes in this phase. Every correction is Phase 5. A task that "fixes" a state has failed.
- **`expectedStateTax` MUST be derived from the state's own published form, instructions or worked example.** Never from this app's output. A fixture whose expected value came from the engine proves only that the engine agrees with itself.
- **Citation discipline (§3.4, the PROCESS control this phase carries):** every fixture carries `source` and a resolvable https `sourceURL`. **The fixture author, and the reviewer, must each state in their report that they personally opened every `sourceURL` and checked every clause of `source` against it.** Not "a citation is present". Not "the URL resolves". Every clause, against the page. This exists because three fixtures in Phase 2 had confidently wrong citations whose expected VALUES were correct, so every test passed.
- **Admissible sources:** state DOR pages, statutes, enrolled bills, official form instructions. Advisor blogs, tax-prep vendor help pages and news articles are inadmissible as sole basis. Any claimed 2024-2026 change must state the bill number and its final disposition (signed, vetoed, died). This is the check that catches the Colorado class of error, where a syndicated guide reported a bill that was Postponed Indefinitely on 2025-02-27 as enacted law.
- **`CANNOT_VERIFY` is a legitimate outcome.** If a state's rule cannot be established from a primary source, record the jurisdiction as unverified per §3.4 rather than guessing. The failure mode is confident fabrication, not silence.
- **No em dashes** in any file, per user preference. This has been a recurring review finding; a report claiming there are none when there are is treated as the worse half of the defect.
- **Suite is the source of truth** (CLAUDE.md). Baseline at branch point: 1,752 Swift Testing in 285 suites + 505 XCTest, 0 failures.
- **Never edit files by chained `cd`.** Bash cwd resets between calls. Use absolute paths and `git -C`. This bit the previous phase four times, once committing a ledger to the wrong branch.

**Worktree:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4`, branch `feature/state-tax-phase4`, off `main` @ `6097430`.

**Build command (always pass `-project` explicitly, per the build trap in the 2026-08-04 session note):**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

---

## File Structure

| File | Responsibility |
|---|---|
| `RetireSmartIRATests/GoldenScenario.swift` | Fixture value types. Gains `KnownDefect` and `GoldenScenario.knownDefect`. |
| `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift` | Single-year assertion. Gains the two-branch defect logic; `pilot` is replaced by all-51 enumeration. |
| `RetireSmartIRATests/GoldenScenarioCoverageTests.swift` | **New.** Every jurisdiction has a fixture; every fixture obeys the shape invariants. |
| `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift` | **New.** Emits the defect catalogue and pins its size, which is this phase's deliverable. |
| `RetireSmartIRATests/GoldenScenarios/statetax-2026-<XX>.golden.json` | 46 new fixtures, one per remaining jurisdiction. |
| `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md` | SDD progress ledger. |

`RetireSmartIRATests` is a `PBXFileSystemSynchronizedRootGroup`, so new `.json` files under it are bundled automatically with **no `project.pbxproj` edit**. Do not hand-edit the pbxproj. Task 2's coverage test is what proves bundling actually worked; if a fixture silently fails to bundle, that test fails with `LoadError.missing`.

---

## The four-case matrix (§3.4)

Every jurisdiction gets **at least four** scenarios:

1. **Single filer BELOW any age threshold** the state applies.
2. **Single filer ABOVE it.**
3. **MFJ, both spouses qualifying.**
4. **MFJ, only one spouse qualifying.**

Case 4 is the one that matters most and the one a lazy fixture set omits. It is what would have caught Iowa's per-qualifying-spouse rule against the engine's household-wide `||` at `TaxCalculationEngine.swift:570`, and the systematic under-crediting of married couples across the six Tier 3 states.

**States with an AGI phase-out get a fifth case above the threshold**, because for those the Roth conversion is precisely what destroys the exemption, and that interaction is the one most likely to be modeled wrongly.

**At least one fifth case must be MFJ with income BETWEEN `thresholdSingle` and `thresholdMFJ`.** Virginia is the designated carrier ($50,000 single against $75,000 married): an MFJ filer at $60,000 keeps the full $12,000 under the correct flag and drops to $2,000 under a mutant that hardcodes `isMarried: false`. Only the band between the two thresholds distinguishes them, so a scenario outside it proves nothing. Assigned explicitly in Task 6.

**If a state genuinely has no age threshold and no phase-out** (most no-tax states, and the no-exclusion states), cases 1 and 2 collapse. Write the four cases anyway, varying income instead of age, so the matrix stays uniform and a later phase that adds an age gate has a case waiting. Say so in the fixture `name`.

---

## The fixture shape invariant, and why it is load-bearing

`federalAGI` MUST equal `pensionIncome + iraWithdrawals + rothConversion + taxableSocialSecurity` (with `classifiedPensionSources` amounts summed in place of `pensionIncome` when present).

This is not a style rule. The single-year runner reads `federalAGI` directly, but the multi-year runner **derives its own AGI from the income components and never reads `federalAGI` at all** (`ProjectionEngine.swift:680-690`). A Phase 2 fixture set `federalAGI` to $95,000 while pension was $80,000, and that $15,000 mismatch moved the single-year figure by $210 while the multi-year figure could not move at all. It read as an engine divergence and was a **fixture authoring artifact**. Task 2 makes that unrepresentable by asserting it across every fixture.

---

## Task batches

Ordered so that **jurisdictions expected to PASS come first.** If the harness reports a failure on a jurisdiction the audit confirmed correct, that is a harness bug, not a state bug, and it must be diagnosed before any tier where failures are expected. This is the same reasoning §4a used to pick Phase 2's pilot from known-correct states.

| Task | Batch | Jurisdictions | Expectation |
|---|---|---|---|
| 3 | No income tax | AK FL NV SD TN TX WY NH | All pass at $0 |
| 4 | No retirement exclusion, confirmed correct | CA NE ND IN OR | All pass |
| 5 | Exclusion, confirmed correct | CO KY GA MO | All pass |
| 6 | **Tier 1**, wrong values | IA MI CT VA WI AL RI ME MT MD | Failures expected |
| 7 | **Tier 2**, per-source wall | KS MA HI AZ NC ID VT DC | Failures expected |
| 8 | **Tier 3**, attribution and age gates | OK DE LA AR SC WV | Failures expected |
| 9 | **Tier 4** and unclassified | OH UT NM WA MN | Failures expected |

46 jurisdictions. PA, IL, MS, NJ and NY already have fixtures from Phases 2 and 3b and are not rewritten.

**MN is unclassified.** It appears in no tier and in no confirmed-correct list in `2026-08-02-full-50-state-verification.md`, which means it was never audited rather than that it is correct. Research it from primary sources like any other and record the outcome honestly, including `CANNOT_VERIFY` if that is where it lands.

---

### Task 1: The `knownDefect` mechanism

**Files:**
- Modify: `RetireSmartIRATests/GoldenScenario.swift`
- Modify: `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift:127-141`
- Test: `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`

**Interfaces:**
- Produces: `KnownDefect` (`tier: String`, `summary: String`, `observedToday: Double`), `GoldenScenario.knownDefect: KnownDefect?`. Every later task authors fixtures against these names.

**Why two assertions and not one.** A fixture that merely skipped the comparison when a defect is known would go quiet: the state would be free to drift to any other wrong number and nothing would notice. Pinning `observedToday` means any drift fails. Asserting the engine still does NOT match the form means the pin is self-cleaning: when Phase 5 corrects the state, this test fails and the implementer is forced to delete the block rather than leaving a stale defect record behind. This is the same "pin as observed, never as an inequality" discipline already established by `newJerseyCrossPathGapPinnedAsObserved`.

- [ ] **Step 1: Write the failing test**

Add to `GoldenScenarioSingleYearTests.swift`:

```swift
    @Test("A knownDefect fixture pins today's wrong figure and asserts it is still wrong")
    func knownDefectMechanismRoundTrips() throws {
        let json = """
        {"state":"XX","taxYear":2026,"scenarios":[{
          "name":"synthetic",
          "source":"synthetic fixture for the mechanism test, cites no authority",
          "sourceURL":"https://example.invalid/none",
          "filingStatus":"single","primaryAge":65,"spouseAge":null,
          "federalAGI":50000,"taxableSocialSecurity":0,"pensionIncome":50000,
          "iraWithdrawals":0,"rothConversion":0,
          "expectedStateTax":1218.88,
          "knownDefect":{"tier":"tier2","summary":"missing personal exemption","observedToday":2171.52}
        }]}
        """
        let file = try JSONDecoder().decode(GoldenScenarioFile.self, from: Data(json.utf8))
        let scenario = try #require(file.scenarios.first)
        let defect = try #require(scenario.knownDefect)
        #expect(defect.tier == "tier2")
        #expect(abs(defect.observedToday - 2171.52) < 0.01)
        #expect(abs(scenario.expectedStateTax - 1218.88) < 0.01)
    }

    @Test("A fixture with no knownDefect decodes it as nil")
    func absentKnownDefectDecodesNil() throws {
        let file = try GoldenScenario.load(abbreviation: "PA")
        let scenario = try #require(file.scenarios.first)
        #expect(scenario.knownDefect == nil)
    }
```

- [ ] **Step 2: Run and verify it fails**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests 2>&1 | tail -20
```

Expected: COMPILE FAILURE, `value of type 'GoldenScenario' has no member 'knownDefect'`. A compile failure is a valid RED here because the type does not exist yet.

- [ ] **Step 3: Add the type**

In `GoldenScenario.swift`, add above `struct GoldenScenarioFile`:

```swift
/// Records that a jurisdiction's shipped behavior is KNOWN to disagree with
/// its own published form, so the disagreement is pinned rather than silently
/// tolerated.
///
/// Phase 4 writes fixtures to CORRECT LAW, which means roughly 29 jurisdictions
/// are expected to disagree with the engine. Without this block the suite would
/// go red across the board and the phase could not gate. With it, every defect
/// is a named, pinned, citable record and the suite stays green.
///
/// `observedToday` is the figure the engine ACTUALLY produces right now. It is
/// not an endorsement. It exists so that any drift in a defective state fails a
/// test, and so Phase 5 can measure its own correction against a real baseline
/// rather than a remembered one.
struct KnownDefect: Codable {
    /// "tier1" | "tier2" | "tier3" | "tier4" | "unclassified", matching the
    /// tiers in `.claude/memory/roadmap/2026-08-02-full-50-state-verification.md`.
    let tier: String
    /// One sentence naming the mechanism, not the symptom.
    let summary: String
    /// Today's engine output for this scenario, measured, never predicted.
    let observedToday: Double
}
```

And add to `GoldenScenario`, after `classifiedPensionSources`:

```swift
    /// Present only when the engine is KNOWN to disagree with `expectedStateTax`.
    /// Absent (nil) means the jurisdiction is expected to match its own form.
    let knownDefect: KnownDefect?
```

- [ ] **Step 4: Run and verify it passes**

Same command as Step 2. Expected: both new tests PASS, all five existing fixtures still decode (they carry no `knownDefect` key, and Swift's synthesized `decodeIfPresent` for an Optional handles that).

- [ ] **Step 5: Switch the assertion to two branches**

Replace the body of `singleYearMatchesGolden`'s loop:

```swift
        for scenario in file.scenarios {
            let actual = Self.singleYearStateTax(scenario, state: state)
            if let defect = scenario.knownDefect {
                #expect(abs(actual - defect.observedToday) < 0.01,
                        """
                        \(abbreviation) / \(scenario.name): engine now \(actual), \
                        pinned observed value \(defect.observedToday).
                        A DEFECTIVE state moved. Diagnose what changed before touching this pin.
                        Defect: \(defect.summary)
                        """)
                #expect(abs(actual - scenario.expectedStateTax) >= 0.01,
                        """
                        \(abbreviation) / \(scenario.name) now MATCHES its published form \
                        (\(scenario.expectedStateTax)). The defect appears to be FIXED.
                        Delete the knownDefect block from this fixture so the case becomes a
                        normal passing assertion. Do not update observedToday to keep it quiet.
                        """)
            } else {
                #expect(abs(actual - scenario.expectedStateTax) < 0.01,
                        """
                        \(abbreviation) / \(scenario.name): engine \(actual), \
                        form says \(scenario.expectedStateTax).
                        Source: \(scenario.source)
                        Phase 4 corrects no tax value. If the engine is wrong, add a knownDefect
                        block recording the MEASURED observedToday and leave the fix for Phase 5.
                        """)
            }
        }
```

- [ ] **Step 6: Run the full suite**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

Expected: 0 failures. Baseline 1,752 Swift Testing + 505 XCTest, now +2.

- [ ] **Step 7: Prove the mechanism by mutation**

Temporarily add a `knownDefect` block to PA's first fixture with a deliberately wrong `observedToday` of `999.0`. Run the PA test. It MUST fail on the first `#expect`. Then set `observedToday` to PA's real observed figure and confirm it fails on the SECOND `#expect` instead (because PA genuinely matches its form). Revert the fixture completely and confirm `git diff` is empty.

Record both failure messages in the ledger. A mechanism that cannot be shown to fail is not a mechanism.

- [ ] **Step 8: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/GoldenScenario.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): pin known defects instead of tolerating them"
```

---

### Task 2: Drive all 51 jurisdictions, and make the fixture artifact unrepresentable

**Files:**
- Create: `RetireSmartIRATests/GoldenScenarioCoverageTests.swift`
- Modify: `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift:8` (the `pilot` array)

**Interfaces:**
- Consumes: `GoldenScenario.knownDefect` from Task 1.
- Produces: `GoldenScenarioCoverageTests.allAbbreviations: [String]`, the single enumeration every later suite drives from.

**Why enumeration replaces the hand-maintained array.** `pilot` is a literal list. A literal list is exactly how a jurisdiction goes missing, and this codebase already shipped the archetype of that failure: `StateTaxData.swift:2069` returned California's config for any state not found, so a missing state silently became California. Deriving coverage from `USState.allCases` means a jurisdiction cannot be omitted without a test failing.

The array is replaced in two moves. Right now only 5 fixtures exist, so pointing the single-year suite at all 51 immediately would fail 46 times and stay red for the rest of the phase, which would destroy the signal every later task depends on. So: coverage is asserted against a list that GROWS as tasks land, and Task 10 flips the completeness assertion on once every fixture exists.

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/GoldenScenarioCoverageTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

/// Coverage and shape invariants for the golden fixture set.
///
/// Kept separate from the assertion suites because these tests are about the
/// FIXTURES, not about any state's tax. A failure here means a fixture is
/// malformed or missing, which is a different diagnosis from a state being wrong.
@Suite("Golden scenarios, coverage and shape")
struct GoldenScenarioCoverageTests {

    /// Jurisdictions with a bundled fixture today. Task 10 replaces the body of
    /// `everyJurisdictionHasAFixture` with a full `USState.allCases` sweep once
    /// this list reaches 51; until then it grows as each batch task lands, so a
    /// half-finished phase still gates on what it has actually delivered.
    static let covered: [String] = ["PA", "IL", "MS", "NJ", "NY"]

    @Test("Every covered jurisdiction has a bundled, decodable fixture",
          arguments: GoldenScenarioCoverageTests.covered)
    func fixtureLoads(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        #expect(file.state == abbreviation)
        #expect(file.taxYear == 2026)
        #expect(!file.scenarios.isEmpty)
    }

    /// The invariant that makes a whole class of false finding unrepresentable.
    ///
    /// The single-year runner reads `federalAGI` directly; the multi-year runner
    /// derives its own AGI from the income components and never reads
    /// `federalAGI` at all (ProjectionEngine.swift:680-690). A fixture where the
    /// two disagree produces a cross-path gap that looks like an engine defect
    /// and is actually an authoring mistake. Phase 2 shipped exactly that and it
    /// cost a $210 phantom divergence.
    @Test("federalAGI equals the sum of its components",
          arguments: GoldenScenarioCoverageTests.covered)
    func federalAGIIsInternallyConsistent(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            let pension = scenario.classifiedPensionSources?.reduce(0) { $0 + $1.amount }
                ?? scenario.pensionIncome
            let components = pension + scenario.iraWithdrawals + scenario.rothConversion
                + scenario.taxableSocialSecurity
            #expect(abs(scenario.federalAGI - components) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): federalAGI \(scenario.federalAGI) \
                    against components summing to \(components).
                    The multi-year runner never reads federalAGI, so this mismatch would surface
                    as a phantom cross-path divergence. Fix the fixture, not the engine.
                    """)
        }
    }

    @Test("Every fixture carries a resolvable https citation",
          arguments: GoldenScenarioCoverageTests.covered)
    func citationsAreWellFormed(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            #expect(!scenario.source.isEmpty, "\(abbreviation) / \(scenario.name): empty source")
            #expect(scenario.sourceURL.hasPrefix("https://"),
                    "\(abbreviation) / \(scenario.name): sourceURL is not https")
        }
    }

    @Test("Fixtures never set both pensionIncome and classifiedPensionSources",
          arguments: GoldenScenarioCoverageTests.covered)
    func noDoubleCountedPension(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            if let classified = scenario.classifiedPensionSources, !classified.isEmpty {
                #expect(scenario.pensionIncome == 0,
                        "\(abbreviation) / \(scenario.name): both set, would double count")
            }
        }
    }
}
```

- [ ] **Step 2: Run and verify it passes for the existing five**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioCoverageTests 2>&1 | tail -20
```

Expected: PASS. If `federalAGIIsInternallyConsistent` fails on an existing fixture, that is a REAL finding about a Phase 2/3b fixture. Record it in the ledger and report it; do not silently repair the fixture, because the NJ pin in `GoldenScenarioCrossPathTests` is calibrated against today's values.

- [ ] **Step 3: Point the single-year suite at the shared enumeration**

In `GoldenScenarioSingleYearTests.swift`, replace line 8:

```swift
    static let pilot = ["PA", "IL", "MS", "NJ", "NY"]
```

with:

```swift
    /// Single source of truth for which jurisdictions are asserted. Deliberately
    /// NOT a second literal list: a hand-maintained array is how a jurisdiction
    /// goes missing, and this codebase already shipped that failure once
    /// (StateTaxData.swift:2069 silently returned California for any unknown state).
    static let pilot = GoldenScenarioCoverageTests.covered
```

- [ ] **Step 4: Run the full suite**

Expected: 0 failures, same 5 jurisdictions asserted as before.

- [ ] **Step 5: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/GoldenScenarioCoverageTests.swift RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): one enumeration for fixture coverage, and shape invariants"
```

---

### Tasks 3 through 9: The fixture batches

**Every batch task follows the identical procedure below.** It is written once here rather than repeated seven times; the per-batch sections that follow carry only what differs (the jurisdictions, the expectation, and the batch-specific traps).

**Files, for a batch covering jurisdictions X, Y, Z:**
- Create: `RetireSmartIRATests/GoldenScenarios/statetax-2026-X.golden.json` (one per jurisdiction)
- Modify: `RetireSmartIRATests/GoldenScenarioCoverageTests.swift:covered` (append the batch's abbreviations)
- Test: the existing suites, which pick the new fixtures up automatically through `covered`

**Procedure:**

- [ ] **Step 1: Research each jurisdiction from primary sources.** For each state in the batch, find its 2026 (or latest published) form instructions, DOR retirement-income guidance, or statute. Establish: bracket schedule, standard deduction, personal exemption, retirement-income exemption with its amount, age threshold, per-person versus household attribution, any AGI phase-out, and Social Security treatment. Record the URL you actually opened.

- [ ] **Step 2: Read the app's current config** at `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-<XX>.json` so you know what the engine will do. Do NOT let it influence `expectedStateTax`. You are reading it to predict whether this fixture will need a `knownDefect` block, not to derive an answer.

- [ ] **Step 3: Derive the four cases BY HAND from the form.** Show the arithmetic in the fixture's `source` string: which lines, which subtraction, which bracket. A reader must be able to re-derive your number from your citation without running the app. Honor the shape invariant: `federalAGI` equals the sum of its components.

- [ ] **Step 4: Write the fixture file** with no `knownDefect` blocks yet.

- [ ] **Step 5: Append the batch's abbreviations to `GoldenScenarioCoverageTests.covered`.**

- [ ] **Step 6: Run and observe.**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests 2>&1 | tail -60
```

Each failure message prints both the engine figure and the form figure.

- [ ] **Step 7: For each failure, decide which side is wrong.**

This is the judgment the whole phase turns on, and it has two outcomes, not one:

  - **The engine is wrong** → add a `knownDefect` block with the MEASURED `observedToday` (copy it from the failure message, never predict it), the tier, and a one-sentence mechanism. This is a Phase 4 deliverable.
  - **The fixture is wrong** → fix the fixture. A misread form is the more likely explanation for a state the audit listed as CORRECT, and the less likely one for a state it listed as defective. Weight your prior accordingly, but verify either way rather than assuming the audit was right. The audit is single-source and says so.

  If you cannot tell which side is wrong from primary sources, mark the jurisdiction `CANNOT_VERIFY` in the ledger and leave the fixture out of `covered` rather than guessing. An unverified jurisdiction is a legitimate end state per §3.4; a fabricated one is not.

- [ ] **Step 8: Re-run until the batch is green** (every case either matches its form or carries a pinned defect).

- [ ] **Step 9: Run the FULL suite** to confirm nothing else moved.

- [ ] **Step 10: Report, with the citation attestation.** The report MUST state, in these terms: *"I personally opened every sourceURL in this batch and checked every clause of each `source` string against the page."* If that is not true, say what you actually did instead. A false attestation in a phase whose method is evidence before assertion is worse than the defect it hides.

- [ ] **Step 11: Commit** the batch as one commit.

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/GoldenScenarios/ RetireSmartIRATests/GoldenScenarioCoverageTests.swift
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): golden scenarios for <batch name>"
```

Stage explicit paths. Never `git add -A`: it raced a reviewer's in-flight mutation in the previous phase and committed a temporary revert.

---

### Task 3: No-income-tax jurisdictions

**Jurisdictions:** AK, FL, NV, SD, TN, TX, WY, NH, 8 fixtures.

**Expectation: all pass at $0.** These are the cheapest possible proof that the harness scales from 5 fixtures to 51 without something structural breaking.

**Batch-specific notes:**

- These states have no form to derive from. Cite the state's own DOR or legislature page stating there is no individual income tax. That IS the primary source, and `expectedStateTax: 0` follows from it.
- **New Hampshire is the trap.** Its interest and dividends tax was fully repealed effective 2025, so NH is $0 for 2026 but was NOT $0 recently, and the app models it as `.specialLimited`. Cite the repeal explicitly with its bill reference. If the engine returns nonzero for NH, that is a genuine Tier-4-adjacent finding and gets a `knownDefect` block.
- **Washington is NOT in this batch.** It has a capital gains tax and belongs in Task 9.
- Vary income across the four cases anyway (per the matrix rule above) so a future change that accidentally introduces tax in a no-tax state fails four ways rather than one.

---

### Task 4: No retirement exclusion, confirmed correct

**Jurisdictions:** CA, NE, ND, IN, OR, 5 fixtures.

**Expectation: all pass.** The audit confirmed these have no retirement exclusion and that `.none` is correct.

**Batch-specific notes:**

- California is the most consequential fixture in this batch for a reason unrelated to California: `StateTaxData.swift:2069` returns California's config for any state not found, so CA is the value a bundling failure silently resolves to. A correct, exercised CA fixture is what makes that fallback detectable elsewhere.
- CA has exemption CREDITS ($153/person), not exclusions. Credits are applied differently from deductions and the app models them separately. Derive from Form 540 and say which line each figure comes from.
- These states still have brackets, standard deductions and (for some) personal exemptions. "No retirement exclusion" does not mean "no tax". Expect nonzero `expectedStateTax` in most cases, which makes this batch a much stronger harness proof than Task 3.

---

### Task 5: Exclusion present, confirmed correct

**Jurisdictions:** CO, KY, GA, MO, 4 fixtures.

**Expectation: all pass.** Any failure here is most likely a harness or fixture bug and must be diagnosed before Tasks 6 through 9 run, because from here on failures are ambiguous.

**Batch-specific notes:**

- **Colorado is a calibration probe, and it is deliberately adversarial.** The correct 2026 rule is $24,000 at 65+ / $20,000 at 55-64. A widely syndicated advisor guide claims SB25-136 removed all caps effective 2026-01-01; **that bill was Postponed Indefinitely on 2025-02-27 and is dead.** If your research surfaces the uncapped claim, you have found the secondary source, not the law. Cite the bill's disposition in the fixture `source`. The false claim already reached a code comment in `TaxsimOracleTests.swift`, so this is not hypothetical.
- **Kentucky:** $31,110 stands. HB 146 ($41,100) was proposed and not enacted. Same shape of trap.
- **Georgia:** $65,000 at 65+ / $35,000 at 62-64 is correct for TY 2026 and rises to $70,000 in TY 2027. Write the fixture for 2026 and note the 2027 change in `source` so the diary item is attached to the data.
- **Missouri:** substantively right, but the app's code comment cites HB 798 when the operative bill is **HB 426**. That is a stale-comment finding for Phase 5, not a value defect. Also, Missouri's public pension exemption is capped at each individual's maximum Social Security benefit, which the app does not model. If a case exercises that cap it will fail, and it earns a `knownDefect` at tier "unclassified" with the mechanism named.

---

### Task 6: Tier 1, wrong values

**Jurisdictions:** IA, MI, CT, VA, WI, AL, RI, ME, MT, MD, 10 fixtures.

**Expectation: failures, and they are the deliverable.** Every one of these is a wrong number or a missing gate that the existing model shape can already carry.

**Batch-specific notes:**

- **Iowa is the highest-value fixture in the entire phase.** Iowa excludes retirement income from 55+ including **Roth conversion income by name**, no cap, no income limit. The app has `.none`/`.none`. For a Roth conversion planning tool this invents state tax on the exact transaction the product exists to optimize, roughly $7,600 on a $200,000 conversion at 3.8%. Write a case that carries a large `rothConversion` explicitly; the four-case matrix alone would not exercise it. Iowa needs **five or six** cases: the standard four plus a conversion case, plus the 55-to-58 age band that the hardcoded 59½ gate at `TaxCalculationEngine.swift:570` will fail independently of the config.
- **Iowa also carries the `||` attribution defect.** `TaxCalculationEngine.swift:570` grants the household the exemption when EITHER spouse is 59+; Iowa's exclusion is explicitly per-qualifying-spouse. Matrix case 4 (MFJ, only one qualifying) is what exposes it. Make sure the qualifying spouse is the one whose income is NOT being tested, so the household-wide grant is visible.
- **VIRGINIA IS THE DESIGNATED CARRIER OF THE BETWEEN-THRESHOLDS CASE**, per §3.4 and the Phase 3a Task 4 review. Write an MFJ case at **$60,000**, between VA's $50,000 single and $75,000 married thresholds. Under the correct `isMarried` flag the filer keeps the full $12,000; under a mutant that hardcodes `isMarried: false` it drops to $2,000. This case is REQUIRED and its absence fails the phase, because the entire Phase 3a suite stays green under that mutation (every engine test there is single-only). Say in the fixture `name` that it is the between-thresholds carrier so a later reader does not "simplify" it away.
- **Michigan, Connecticut and Virginia are the dangerous three.** All three OVERSTATE the exemption, which pushes users toward converting more than they should. A too-generous number costs real money; a too-stingy one costs only opportunity. Their `knownDefect` summaries should say "overstates" explicitly so Phase 5 can prioritize by error direction.
- **Connecticut and Virginia share the conversion-destroys-the-exemption failure mode**, so both need the fifth AGI-phase-out case. CT: 100% exempt under $75k single / $100k MFJ, phasing out to $100k/$150k. VA: $12,000 at 65+, reduced $1 per $1 of AFAGI over $50k/$75k.
- **Montana:** the old deduction was repealed for TY 2025 and replaced with roughly $5,500 indexed. The app has `.partial(4_640)` plus a stale TODO. Establish the actual 2026 indexed figure from the DOR, and if it is not published yet, say so and mark `CANNOT_VERIFY` rather than interpolating.
- Wisconsin ($24,000 per person at 67+, 2025 Act 15), Alabama (DB fully exempt, DC $6,000/person at 65+), Rhode Island ($20,000/person at SS full retirement age, AGI-limited), Maine ($48,216 indexed, plus a new phase-out, against the app's $25,000), Maryland ($40,600 for 2026 against the app's $41,200).
- **Alabama's rule is per-source in disguise:** defined-benefit pensions fully exempt, defined-contribution capped. That is expressible only through the Phase 3b `PlanStructure` axis. Use `classifiedPensionSources` for Alabama's cases and note in `source` that the structure axis is what the rule keys on.

---

### Task 7: Tier 2, the per-source wall

**Jurisdictions:** KS, MA, HI, AZ, NC, ID, VT, DC, 8 fixtures. (NY is already done, from Phase 3b.)

**Expectation: failures.** None of these can be fixed by editing a number; every one keys on which plan the money came from.

**Batch-specific notes:**

- **Kansas carries a written promise to Steve Nicolai and has TWO independent defects.** (1) The missing personal exemption he found: $18,320 MFJ, $9,160 single, $2,320 per dependent, per SB 1 (2024 special session). His exact figures are $50,000 income, $8,240 standard deduction, 5.2% rate: the app produces **$2,171.52** and the correct answer is **$1,218.88**. **Steve's scenario becomes a permanent golden case, reproduced to the cent**, per §3.4's rule that user-reported scenarios become fixtures. (2) The per-source rule: KPERS, federal, military and Railroad Retirement fully exempt while private pensions, 401(k) and IRA are fully taxable. Write cases for both defects separately so Phase 5 can fix them independently and see each one go green on its own.
- Use `classifiedPensionSources` throughout this batch. That is what the Phase 3b `PlanStructure` x `PlanSource` axes exist for, and this batch is the reason they were built as two axes rather than one flat `.governmentPension` case.
- **The two-axis distinction is load-bearing and easy to lose.** Phase 3b's design revision exists because a single `.governmentPension` case would have handed New York's uncapped exclusion to a California public pension. When writing Kansas or DC, do not reach for a generic "government" classification where the statute names a specific system.
- Massachusetts (contributory MA state and local exempt, noncontributory municipal taxable, US uniformed services exempt), Hawaii (employer-funded portion exempt with no cap and no age; employee contributions, 401(k) deferrals and IRAs taxed), Arizona (the $2,500 exclusion covers GOVERNMENT pensions only and the app applies it to all pensions, so it OVERSTATES), North Carolina (Bailey/Emory/Patton class, vested before 1989-08-12, fully exempt), Idaho (CSRS, Idaho police/fire, military, 65+ or 62 if disabled, income-limited), Vermont ($10,000 military/CSRS, AGI-limited $55k single / $70k MFJ), DC ($3,000 at 62+, DC or federal government pensions only).
- **Hawaii was explicitly scoped as "disclosed, not modelled" in Phase 3b.** Write its fixtures to correct law anyway. A fixture that documents an unmodelled rule with a pinned defect is exactly how Phase 6 knows what sentence to put in Hawaii's `knownLimitations`.
- **North Carolina's Bailey class is a vesting-date rule, not an age or amount rule.** The model has no vesting-date axis. Expect `CANNOT_VERIFY` on expressibility rather than on the law, and say which it is: the law is clear, the model cannot carry it. That distinction matters to Phase 5 scoping.

---

### Task 8: Tier 3, attribution and age gates

**Jurisdictions:** OK, DE, LA, AR, SC, WV, 6 fixtures.

**Expectation: failures, all in the same direction.** Every defect in this tier makes the app **under-credit married couples**, because `exemptionAppliesPerIndividual` is set for only two states while at least seven statutes are per-person.

**Batch-specific notes:**

- **Matrix case 3 (MFJ, both spouses qualifying) is the load-bearing case for this entire batch.** A per-person exemption applied household-wide gives exactly half the correct exclusion for a two-qualifying-spouse couple. Case 4 (only one qualifying) must ALSO be written, because a naive "just double it" fix would pass case 3 and fail case 4, and this phase should catch that in Phase 5 rather than after.
- Oklahoma ($10,000 per person, so $20k MFJ; flag not set; note the amount itself is confirmed CORRECT and HB2190's $40,000 is still in committee, so do not "fix" the amount), Delaware ($12,500 per person at 60+; neither the flag nor `regularExemptionMinAge: 60` is set), Louisiana ($12,000 at 65+, per person, no age gate set), Arkansas ($6,000 per taxpayer at 59.5+), South Carolina (missing the separate $15,000 age-65 deduction against ANY income, reduced by the retirement deduction claimed), West Virginia ($8,000 senior modification at 65+, per person, reduced by other modifications; app has `.none`).
- **South Carolina's rule interacts with itself:** the $15,000 age-65 deduction is REDUCED by the retirement deduction claimed. Write a case where both apply so the interaction is pinned, not just the presence of each.
- **West Virginia's modification is also reduced by other modifications**, the same shape. Same treatment.
- Delaware and Louisiana each need BOTH an age gate and a per-person flag, so a Phase 5 fix that adds only one will still fail. Write cases that isolate each: one MFJ pair both above the age threshold (tests the flag), one single filer below it (tests the gate).

---

### Task 9: Tier 4 and unclassified

**Jurisdictions:** OH, UT, NM, WA, MN, 5 fixtures.

**Expectation: failures, mostly of a different kind.** Three of these are CREDITS rather than exclusions, which the model has no representation for at all.

**Batch-specific notes:**

- Ohio (retirement income credit up to $200 plus a $50 senior credit, MAGI under $100,000), Utah (up to $450 per person, full at or below $54,000 single / $90,000 joint, cannot be combined with the Social Security credit), New Mexico ($8,000 at 65+ but AGI must be under $28,500 single / $51,000 MFJ).
- **For the three credit states, `.none` is arguably the HONEST encoding today**, and all three are income-limited well below this app's typical user. Write the fixtures to correct law anyway, then let the `knownDefect` summary say plainly that the model has no credit representation. That sentence is what Phase 6 puts in `knownLimitations`, and it is a more useful deliverable than a correction nobody in the audience would ever hit.
- **New Mexico is also the second between-thresholds carrier** ($28,500 single against $51,000 MFJ). Under the `isMarried: false` mutant its $8,000 vanishes at $28,501 of JOINT income instead of $51,001. Write an MFJ case in that band. Virginia is the primary carrier per Task 6; New Mexico is the independent confirmation, and having two means a single fixture edit cannot silently disarm the check.
- **Washington is not a retirement exemption problem at all.** The app sets `capitalGainsTreatment: .noStateTax` with a code comment saying "7% on gains > $250K". WA actually levies 7% above the standard deduction (roughly $278,000 for 2025, 2026 figure to be confirmed) and **9.9% above $1M** after SB 5813. Write capital-gains cases, not retirement cases. If the 2026 threshold is not yet published, use the 2025 figure and say so explicitly in `source` rather than projecting one.
- **Minnesota was never audited.** It appears in no tier and in no confirmed-correct list, which means unknown, not correct. Research it like any other jurisdiction. MN has both a Social Security subtraction and a public pension subtraction with income limits; establish both from the DOR and write the matrix accordingly. Whatever you find, say explicitly in the ledger that MN was previously unaudited so its result is a NEW finding rather than a confirmation.

---

### Task 10: Close the phase: completeness, catalogue, and the gate

**Files:**
- Modify: `RetireSmartIRATests/GoldenScenarioCoverageTests.swift`
- Create: `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift`
- Create: `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md`

**Interfaces:**
- Consumes: all 51 fixtures, `KnownDefect` from Task 1.

- [ ] **Step 1: Flip completeness on**

Replace `covered` and add the full sweep:

```swift
    /// All 51 jurisdictions. Derived, not hand-listed: see the doc on
    /// `everyJurisdictionHasAFixture` for why a literal list is a liability here.
    static let covered: [String] = USState.allCases.map(\.abbreviation)

    @Test("Every one of the 51 jurisdictions has a fixture")
    func everyJurisdictionHasAFixture() throws {
        var missing: [String] = []
        for state in USState.allCases {
            if (try? GoldenScenario.load(abbreviation: state.abbreviation)) == nil {
                missing.append(state.abbreviation)
            }
        }
        #expect(missing.isEmpty,
                """
                No golden fixture bundled for: \(missing.sorted().joined(separator: ", ")).
                Phase 4's deliverable is all 51. A jurisdiction with no fixture is not
                "assumed correct", it is unverified, and Phase 6 must render it as such.
                """)
        #expect(USState.allCases.count == 51)
    }
```

- [ ] **Step 2: Run and verify**

Expected: PASS if all seven batches landed. If it fails, the named jurisdictions are genuinely missing and the phase is not done. Do not weaken this test to close the phase.

- [ ] **Step 3: Write the catalogue test**

Create `RetireSmartIRATests/GoldenScenarioDefectCatalogueTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 4's actual deliverable, in executable form.
///
/// The audit in 2026-08-02-full-50-state-verification.md is a single-source
/// research memo and says so. This suite is what converts it into evidence: every
/// entry here is a jurisdiction whose shipped behavior was measured against its
/// own published form and found to disagree, with the form cited.
@Suite("Golden scenarios, defect catalogue")
struct GoldenScenarioDefectCatalogueTests {

    struct Entry {
        let state: String
        let scenario: String
        let tier: String
        let summary: String
        let observed: Double
        let expected: Double
    }

    static func catalogue() throws -> [Entry] {
        var entries: [Entry] = []
        for abbreviation in GoldenScenarioCoverageTests.covered {
            guard let file = try? GoldenScenario.load(abbreviation: abbreviation) else { continue }
            for scenario in file.scenarios {
                guard let defect = scenario.knownDefect else { continue }
                entries.append(Entry(state: abbreviation, scenario: scenario.name,
                                     tier: defect.tier, summary: defect.summary,
                                     observed: defect.observedToday,
                                     expected: scenario.expectedStateTax))
            }
        }
        return entries
    }

    @Test("The catalogue is non-empty and every entry is well formed")
    func catalogueIsWellFormed() throws {
        let entries = try Self.catalogue()
        #expect(!entries.isEmpty, """
            No defects catalogued at all. The audit predicted roughly 29 defective
            jurisdictions. An empty catalogue means either the fixtures were written from
            the app's own output rather than from published forms, or knownDefect blocks
            were omitted. Both are Phase 4 failures.
            """)
        for entry in entries {
            #expect(!entry.summary.isEmpty, "\(entry.state): defect with no mechanism named")
            #expect(["tier1", "tier2", "tier3", "tier4", "unclassified"].contains(entry.tier),
                    "\(entry.state): unrecognised tier '\(entry.tier)'")
            #expect(abs(entry.observed - entry.expected) >= 0.01,
                    "\(entry.state) / \(entry.scenario): catalogued as defective but the two figures agree")
        }
    }

    @Test("Print the catalogue, grouped by tier")
    func printCatalogue() throws {
        let entries = try Self.catalogue()
        let byTier = Dictionary(grouping: entries, by: \.tier)
        var report = "\nPHASE 4 DEFECT CATALOGUE: \(entries.count) cases across "
        report += "\(Set(entries.map(\.state)).count) jurisdictions\n"
        for tier in ["tier1", "tier2", "tier3", "tier4", "unclassified"] {
            guard let group = byTier[tier], !group.isEmpty else { continue }
            report += "\n\(tier.uppercased()), \(group.count) cases, "
            report += "\(Set(group.map(\.state)).count) jurisdictions\n"
            for entry in group.sorted(by: { $0.state < $1.state }) {
                let delta = entry.observed - entry.expected
                let direction = delta > 0 ? "OVERTAXES" : "UNDERTAXES"
                report += String(format: "  %@  %@ by $%.2f, %@\n",
                                 entry.state, direction, abs(delta), entry.summary)
            }
        }
        print(report)
        #expect(!entries.isEmpty)
    }
}
```

- [ ] **Step 4: Run it and capture the output**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioDefectCatalogueTests 2>&1 | tail -80
```

Save the printed catalogue verbatim into the ledger. **This is the artifact Phase 5 consumes.**

- [ ] **Step 5: Compare the catalogue against the audit's predictions**

The audit predicted roughly 29 defective jurisdictions in five categories. Write the comparison into the ledger explicitly:

  - **Predicted and confirmed**: the audit was right.
  - **Predicted and NOT reproduced**: either the audit was wrong or the fixture is. Investigate each one and say which. This is the single most valuable output of the phase, because it is where a single-source memo gets falsified.
  - **NOT predicted but found**: the audit missed it. Expect some, since the audit covered ONE of thirteen configuration dimensions.
  - **`CANNOT_VERIFY`**: list them; they become Phase 6 `knownLimitations` rather than Phase 5 corrections.

- [ ] **Step 6: Run the full suite**

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -40
```

Expected: **0 failures.** Every one of the 51 jurisdictions either matches its own published form or carries a pinned, catalogued defect. That is the Phase 4 gate.

- [ ] **Step 7: Verify no tax value moved**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 diff --stat main -- RetireSmartIRA/
```

Expected: **empty.** Phase 4 touches no production file. If this shows anything under `RetireSmartIRA/`, a task corrected something it should not have and it must be reverted into Phase 5.

- [ ] **Step 8: Write the ledger** at `.claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md`, following the shape of `2026-08-03-state-tax-phase3b-ledger.md`: per-task outcomes, mutations that discriminated, findings recorded but not fixed, and the full defect catalogue.

- [ ] **Step 9: Commit**

```bash
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 add RetireSmartIRATests/ .claude/memory/roadmap/2026-08-04-state-tax-phase4-ledger.md
git -C /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4 commit -m "test(state-tax): all 51 jurisdictions covered, defect catalogue closed"
```

---

## Self-review against the spec

**§3.4 four-case matrix**: Task 3-9 procedure, stated once above the batches. **Fifth case for AGI phase-outs**: Tasks 6 (CT, VA, ME, RI) and 9 (NM). **The MFJ between-thresholds case**: Task 6 assigns Virginia as the required carrier, Task 9 adds New Mexico as independent confirmation.

**§3.4 citation discipline**: Global Constraints, plus the explicit attestation in batch Step 10, plus `citationsAreWellFormed` in Task 2 for the structural half.

**§3.4 user-reported scenarios become permanent golden cases**: Task 7 makes Steve's Kansas figures a fixture to the cent. Jonggie F.'s PA scenario is already covered by the existing PA fixture from Phase 2.

**§3.4 calibration probes**: Colorado is Task 5, with the dead-bill trap spelled out. Maine ($48,216, not $25,000) is Task 6. New York is already fixture-covered from Phase 3b.

**§4a Phase 4 gate, "every case runs, failures are the deliverable"**: resolved by the `knownDefect` mechanism in Task 1 and the catalogue in Task 10. This is the one place the plan adds machinery the spec did not name, because §4a's gate as written is incompatible with CLAUDE.md's "suite green" rule; the two are reconciled by making a defect a passing, pinned test rather than a failing one.

**§5 cross-path assertion on every golden scenario**: **DEFERRED, deliberately, and this is a known gap.** `GoldenScenarioCrossPathTests.agreeing` stays at PA/IL/MS in this phase. Extending it to 51 jurisdictions now would surface the two structural divergences already documented (the tax-funding cascade, and `ProjectionEngine` never subtracting the state standard deduction, which over-taxes New York's multi-year figure by $8,000 single / $16,050 MFJ) as ~46 new failures that have nothing to do with any state's parameters. Those are engine defects with their own fix, not fixture findings. **Phase 5d owns the cross-path work** (I2, E8, Kansas both paths) and is where `agreeing` should expand. Recorded here so it is a decision rather than an omission.

**Out of scope for Phase 4, confirmed:** no correction to any config or engine file; the two-model parameter protocol (§3.4 Layer 1) is Phase 5's opening move, run against THIS phase's catalogue.

---

## Execution notes

**Per-batch review.** Each batch task gets its own review before the next begins. The dominant failure mode in this phase is not a wrong number, it is a **confidently wrong citation attached to a correct number**, which every test passes. Only a reviewer opening the URLs catches it. Phase 2 shipped three such fixtures.

**Do not commit while a review is running.** `git add -A` raced a reviewer's in-flight mutation in Phase 3a and committed its temporary revert. Stage explicit paths.

**The audit is single-source.** Treat `2026-08-02-full-50-state-verification.md` as a strong prior and not as truth. Colorado is in it precisely because a confident secondary source was wrong. A batch that reproduces every prediction exactly is more suspicious than one that falsifies two.
