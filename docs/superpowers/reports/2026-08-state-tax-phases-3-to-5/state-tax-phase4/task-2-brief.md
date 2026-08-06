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
                + scenario.taxableSocialSecurity + (scenario.otherOrdinaryIncome ?? 0)
            #expect(abs(scenario.federalAGI - components) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): federalAGI \(scenario.federalAGI) \
                    against components summing to \(components).
                    The multi-year runner never reads federalAGI, so this mismatch would surface
                    as a phantom cross-path divergence. Fix the fixture, not the engine.
                    If the excess is deliberate unmodelled ordinary income, DECLARE it in
                    otherOrdinaryIncome rather than leaving it implicit.
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

Expected: `federalAGIIsInternallyConsistent` FAILS on exactly one case, New York's first fixture, reporting `federalAGI 90000.0 against components summing to 70000.0`. This is a KNOWN, pre-identified failure and it is why `otherOrdinaryIncome` exists. Every other case in all five existing fixtures passes.

If any OTHER case fails, stop: that is a genuine new finding about a Phase 2 or 3b fixture. Record it in the ledger and report it rather than repairing it, because the NJ pin in `GoldenScenarioCrossPathTests` is calibrated against today's values and a fixture edit would move it.

- [ ] **Step 2a: Declare New York's unmodelled income**

In `RetireSmartIRATests/GoldenScenarios/statetax-2026-NY.golden.json`, add to the FIRST scenario only (`"NYC employee pension alone: fully excluded, Line 26"`), beside `rothConversion`:

```json
      "otherOrdinaryIncome": 20000,
```

That $20,000 is already described in that scenario's own `source` string ("leaving only $20,000 of unrelated ordinary income taxable"). This change moves the figure from prose into a checked field and **must not change any computed value**: `otherOrdinaryIncome` is declarative and reaches no engine.

Re-run the coverage suite. Expected: PASS.

Then confirm New York's tax figures did not move:

```bash
xcodebuild test -project /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase4/RetireSmartIRA.xcodeproj -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests 2>&1 | tail -20
```

Expected: PASS, all four NY cases still matching their form-derived values ($487.75, $273.00, $273.00, $273.00). If any NY figure moved, `otherOrdinaryIncome` was wired into the runner and must be reverted to declarative.

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

