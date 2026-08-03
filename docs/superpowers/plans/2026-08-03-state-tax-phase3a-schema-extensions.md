# State Tax Phase 3a: Schema Extensions (behavior-inert) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `StateTaxConfig` the five schema extensions Phase 5 needs to correct 29 jurisdictions, with every new field defaulting to reproducing today's computed tax exactly.

**Architecture:** All state tax flows through one function, `TaxCalculationEngine.applyRetirementExemptions`, which both the single-year (`DataManager`) and multi-year (`ProjectionEngine`) paths call via `calculateStateTax`. Each extension replaces a hardcoded constant or `switch state` in that function with a config-driven value whose default is the constant it replaced. The 51 JSON files are regenerated from the legacy Swift table at the end, so the shipped data carries the full schema at inert values and Phase 5 becomes a value edit rather than a key addition.

**Tech Stack:** Swift 6, Swift Testing (`@Test`/`@Suite`) plus legacy XCTest, `xcodebuild` on macOS and iOS, bundled JSON resources loaded by `StateTaxDataLoader`.

**Spec:** `docs/superpowers/specs/2026-08-02-state-tax-verification-and-maintenance-design.md` §3.3 and §4a row 3.
**Audit (the requirements source for every value below):** `.claude/memory/roadmap/2026-08-02-full-50-state-verification.md`.
**Predecessors:** Phase 1 ledger `.claude/memory/roadmap/2026-08-02-state-tax-phase1-ledger.md`, Phase 2 ledger `.claude/memory/roadmap/2026-08-02-state-tax-phase2-ledger.md`. Read both before Task 1; they record five distinct ways a test in this area can look like verification and provide none.

**Worktree:** `.worktrees/state-tax-phase3a`, branch `feature/state-tax-phase3a`, off local `main` @ `e540e9f`.

**Out of scope, deliberately:** per-source exemptions (government vs private, DB vs DC, 403(b)) are **Phase 3b**, planned separately, and ship with their own UI so the nine affected jurisdictions are actually reachable. Do not add a source-classification axis in this phase.

---

## Global Constraints

- **PHASE 3a IS BEHAVIOR-INERT.** No computed tax value changes for any state, any scenario, any filing status, any age. A moved number is a defect in this phase, never a tax correction. Corrections happen in Phase 5, each gated by a golden scenario derived from a state's own published form.
- **Do not change any state's tax parameters.** Iowa stays `.none`/`.none`. Kansas gains no personal exemption. Michigan, Connecticut, Virginia and Arizona keep today's values. The only config values added are ones that reproduce behavior that already exists in hardcoded form: New Jersey's personal exemption, and Pennsylvania/Illinois/Mississippi's Roth conversion exemption.
- **Do not fix I2.** Multi-year still passes no `postExemptionDeduction`. `GoldenScenarioCrossPathTests` pins the observed NJ divergence at single-year `42.0` and multi-year `200.40469973890345`; both must still hold at the end of this phase. I2 is Phase 5d.
- **Never edit `RetireSmartIRA.xcodeproj/project.pbxproj`.** Both `RetireSmartIRA/` and `RetireSmartIRATests/` are `PBXFileSystemSynchronizedRootGroup` (objectVersion 77), so new files under them are bundled automatically. If you believe a project-file edit is needed, stop and report BLOCKED.
- **No em dash characters** anywhere in code, comments, tests, JSON or commit messages. Use commas, colons, or a rewrite.
- **Bash cwd resets to `/Users/johnurban/Projects/RetireSmartIRA` between calls and does NOT persist.** Every command must `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && ...` in the SAME invocation. Before trusting any suite count, grep the log for the `.xcodeproj` path and confirm it contains `.worktrees/state-tax-phase3a`. A plausible-looking count is not proof of which tree ran. This mistake was made twice in Phase 1.
- **Paste runner transcripts verbatim in every report, both legs.** The Swift Testing summary line AND the XCTest summary line. Summarising instead of pasting was a repeated finding in Phase 1.
- **To claim a test discriminates, mutate the code under test, not the expectation.** Mutating a fixture only proves the comparison is wired up. State plainly in your report which mutations you actually ran and which you did not.
- **Fixture values must never equal the default they would fall back to**, and among N same-typed sibling fields you need enough fixtures that every field has a unique value signature (for Booleans, ceil(log2 N) fixtures). Both rules come from real defects found in Phase 1.

### Baseline

Full macOS suite on `main` @ `e540e9f` before Task 1: **1,620 Swift Testing in 275 suites + 503 XCTest, 0 failures**. Any failure after that is attributable to the change that produced it. Capture it yourself; do not take this number on faith.

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/phase3a-baseline.log | tail -40
```

---

## Why Task 1 exists, and why it comes first

The Phase 1 gate compares the JSON-loaded config against the legacy Swift config. Both are edited together in this phase, so **they move together and Layer A stays green even if every number in the app changes.** The Phase 1 gate cannot see a Phase 3a regression at all.

The real contract of this phase is "today's output equals yesterday's output," and nothing in the repo asserts that. Task 1 builds it: a frozen fixture of computed state tax for 51 jurisdictions across a scenario grid, captured from `main` before any model change, checked in as literal expected values. Every later task runs against it.

This is the fifth time in this program that a plausible-looking gate turned out to be blind to the thing it was supposed to catch. Do not skip it, and do not let a later task "update the baseline" to make itself pass. A baseline change in this phase is a defect report, not a fix.

---

## File Structure

**Created:**
| File | Responsibility |
|---|---|
| `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift` | The frozen 51-jurisdiction output baseline and its scenario grid. The real gate for this phase. |
| `RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` | Checked-in expected values, generated once from `main`, never hand-edited. |
| `RetireSmartIRA/StatePersonalExemption.swift` | The `StatePersonalExemption` value type and its `amount(...)` computation. |
| `RetireSmartIRA/StateAGIPhaseout.swift` | The `AGIPhaseout` value type and its `reducedExclusion(...)` computation. |
| `RetireSmartIRA/StateRothConversionExemption.swift` | The `RothConversionExemption` value type. |
| `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift` | Proves each new field is load-bearing when set to a non-default value. |

**Modified:**
| File | Change |
|---|---|
| `RetireSmartIRA/StateTaxData.swift` | New fields on `RetirementIncomeExemptions` and `StateTaxConfig`; NJ and PA/IL/MS configs gain the values that reproduce their hardcoded behavior. |
| `RetireSmartIRA/StateTaxCodable.swift` | Codable for the three new types; new keys on the two existing conformances. |
| `RetireSmartIRA/TaxCalculationEngine.swift` | Five hardcoded constants and one `switch state` become config reads. |
| `RetireSmartIRA/DataManager.swift:659-671` and `:903-915` | Read `config.personalExemption` instead of calling the NJ-only helper. |
| `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift` | Layer C learns required-versus-optional top-level keys. |
| `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift` | JSON-shape assertions extended to the new keys. |
| `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-*.json` | Regenerated (51 files) in Task 9. Never hand-edited. |

**Task order and why:** Task 1 freezes the baseline. Tasks 2 to 6 add one extension each, smallest blast radius first, each with its own test cycle and gate. Task 7 proves the mechanisms are load-bearing. Task 8 updates Layer C and regenerates the JSON in one commit, so no commit lands with a knowingly-red test. Task 9 is the phase gate.

---

### Task 1: Freeze the behavior baseline

**Files:**
- Create: `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`
- Create: `RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json` (generated, not typed)

**Interfaces:**
- Produces: `BaselineScenario` (internal to the test file), and the checked-in JSON keyed `"<ABBR>|<scenario name>"` to a Double. Later tasks consume nothing from this task except the requirement that its test stays green.

The grid deliberately crosses every boundary the later tasks touch: the 59 distribution gate (ages 55, 57, 58, 61 against a spouse at 56), the per-individual doubling (MFJ with both spouses qualifying versus one), NJ's stepped phase-out bands, and a large conversion in PA/IL/MS.

- [ ] **Step 1: Write the generator and the assertion together, with the fixture absent**

Create `RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

/// PHASE 3a GATE: today's computed state tax equals yesterday's.
///
/// The Phase 1 gate compares the JSON-loaded config against the legacy Swift
/// config. Phase 3a edits BOTH, so they move together and that gate stays
/// green even if every number in the app changes. It is structurally blind to
/// a Phase 3a regression.
///
/// This suite closes that. The expected values were captured from `main`
/// @ e540e9f BEFORE any Phase 3a model change and are checked in as literal
/// data. Every new field added in this phase must default to reproducing
/// them exactly.
///
/// IF THIS SUITE FAILS, THE CHANGE THAT BROKE IT IS THE DEFECT. Do not
/// regenerate the fixture to make it pass. Regeneration is legitimate only in
/// Phase 5, where each moved value is attributable to a named golden scenario
/// citing a state's own published form.
struct BaselineScenario {
    let name: String
    let income: Double
    let filingStatus: FilingStatus
    let taxableSocialSecurity: Double
    let retirementDistributions: Double
    let rothConversion: Double
    let rothConversionWithholding: Double
    let primaryAge: Int
    let spouseAge: Int
    let enableSpouse: Bool
    let postExemptionDeduction: Double
    let pensionIncome: Double
    let rmdRowIncome: Double
}

@Suite("PHASE 3a GATE: state tax behavior baseline")
struct StateTaxBehaviorBaselineTests {

    static let scenarios: [BaselineScenario] = [
        // Ages below, at, and above the hardcoded 59 distribution gate that
        // Task 2 makes configurable. 55 is the age Iowa will use in Phase 5.
        .init(name: "single 55, distributions only", income: 60_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 55, spouseAge: 55, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "single 58, distributions only", income: 60_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 58, spouseAge: 58, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "single 59, distributions only", income: 60_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 59, spouseAge: 59, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // The `||` household gate: primary below, spouse above. Task 5 makes
        // this attribution configurable and MUST leave this value unmoved.
        .init(name: "MFJ 57 with spouse 61", income: 120_000, filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 50_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 57, spouseAge: 61, enableSpouse: true,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "MFJ 61 with spouse 56", income: 120_000, filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 50_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 61, spouseAge: 56, enableSpouse: true,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // Both spouses qualify: exercises exemptionAppliesPerIndividual doubling (NY, GA).
        .init(name: "MFJ 68 both qualify, pension + IRA", income: 140_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 24_000, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 67, enableSpouse: true,
              postExemptionDeduction: 2_000, pensionIncome: 60_000, rmdRowIncome: 0),
        // MFJ filing status with NO spouse enabled. njPersonalExemptions treats
        // this as a single filer; Task 3 must reproduce that exactly.
        .init(name: "MFJ status but spouse disabled, 66", income: 95_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 66, spouseAge: 66, enableSpouse: false,
              postExemptionDeduction: 1_000, pensionIncome: 80_000, rmdRowIncome: 0),
        // NJ stepped phase-out bands: below 100k, inside 100k-125k, inside
        // 125k-150k, and over the cliff. Task 4 adds a phase-out mechanism that
        // must not disturb any of them.
        .init(name: "single 65 pension, total 95k", income: 95_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 65, spouseAge: 65, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 80_000, rmdRowIncome: 0),
        .init(name: "MFJ 68 pension, total 120k", income: 120_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 68, enableSpouse: true,
              postExemptionDeduction: 2_000, pensionIncome: 110_000, rmdRowIncome: 0),
        .init(name: "MFJ 68 pension, total 140k", income: 140_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 68, enableSpouse: true,
              postExemptionDeduction: 2_000, pensionIncome: 110_000, rmdRowIncome: 0),
        .init(name: "MFJ 68 pension, total 200k over the cliff", income: 200_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 68, spouseAge: 68, enableSpouse: true,
              postExemptionDeduction: 2_000, pensionIncome: 110_000, rmdRowIncome: 0),
        // Roth conversion with and without withholding: PA exempts only the net
        // deposited amount, IL and MS exempt the gross. Task 6 moves this rule
        // into config and must preserve BOTH behaviors.
        .init(name: "single 62 conversion 100k no withholding", income: 160_000,
              filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 20_000, rothConversion: 100_000,
              rothConversionWithholding: 0, primaryAge: 62, spouseAge: 62, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "single 62 conversion 100k with 22k withheld", income: 160_000,
              filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 20_000, rothConversion: 100_000,
              rothConversionWithholding: 22_000, primaryAge: 62, spouseAge: 62, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // A conversion BELOW the distribution age gate. The conversion exemption
        // is not age-gated today; the distributions alongside it are.
        .init(name: "single 54 conversion 80k", income: 140_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 30_000, rothConversion: 80_000,
              rothConversionWithholding: 0, primaryAge: 54, spouseAge: 54, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        // `.rmd`-typed IncomeSource rows, which are UNGATED by age today while
        // scenarioRetirementDistributions is gated at 59. This is the cross-path
        // divergence Phase 2 found. Pinned here so Task 2 cannot quietly close it.
        .init(name: "single 55 rmd rows not scenario distributions", income: 60_000,
              filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 55, spouseAge: 55, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 40_000),
        // Age-tier boundary: GA's 62-64 early tier versus its 65+ regular tier.
        .init(name: "single 63 in the early age tier", income: 90_000, filingStatus: .single,
              taxableSocialSecurity: 18_000, retirementDistributions: 40_000, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 63, spouseAge: 63, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0),
        .init(name: "zero income", income: 0, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              rothConversionWithholding: 0, primaryAge: 65, spouseAge: 65, enableSpouse: false,
              postExemptionDeduction: 0, pensionIncome: 0, rmdRowIncome: 0)
    ]

    static func key(_ state: USState, _ scenario: BaselineScenario) -> String {
        "\(state.abbreviation)|\(scenario.name)"
    }

    static func computedTax(state: USState, scenario: BaselineScenario) -> Double {
        var sources: [IncomeSource] = []
        if scenario.pensionIncome > 0 {
            sources.append(IncomeSource(name: "Pension", type: .pension,
                                        annualAmount: scenario.pensionIncome))
        }
        if scenario.rmdRowIncome > 0 {
            sources.append(IncomeSource(name: "RMD", type: .rmd,
                                        annualAmount: scenario.rmdRowIncome))
        }
        return TaxCalculationEngine.calculateStateTax(
            income: scenario.income,
            forState: state,
            filingStatus: scenario.filingStatus,
            taxableSocialSecurity: scenario.taxableSocialSecurity,
            incomeSources: sources,
            currentAge: scenario.primaryAge,
            enableSpouse: scenario.enableSpouse,
            spouseBirthYear: 2026 - scenario.spouseAge,
            currentYear: 2026,
            scenarioRetirementDistributions: scenario.retirementDistributions,
            scenarioRothConversionAmount: scenario.rothConversion,
            scenarioRothConversionWithholdingAmount: scenario.rothConversionWithholding,
            postExemptionDeduction: scenario.postExemptionDeduction,
            localIncomeTaxRate: 0
        )
    }

    static func loadBaseline() throws -> [String: Double] {
        let url = try #require(
            Bundle(for: BehaviorBaselineMarker.self).url(
                forResource: "statetax-behavior-baseline-2026", withExtension: "json"),
            "baseline fixture is not bundled")
        return try JSONDecoder().decode([String: Double].self, from: Data(contentsOf: url))
    }

    @Test("Every jurisdiction and scenario matches the frozen pre-Phase-3a baseline",
          arguments: USState.allCases)
    func matchesFrozenBaseline(state: USState) throws {
        let baseline = try Self.loadBaseline()
        for scenario in Self.scenarios {
            let k = Self.key(state, scenario)
            let expected = try #require(baseline[k], "no baseline entry for \(k)")
            let actual = Self.computedTax(state: state, scenario: scenario)
            #expect(
                actual == expected,
                """
                \(k): computed \(actual), baseline \(expected).
                Phase 3a is behavior-inert. A moved value is a defect in the \
                change that moved it, NOT a reason to regenerate this fixture.
                """
            )
        }
    }
}
```

Declare the bundle marker at the bottom of the same file. `StateTaxDataLoader`'s own `BundleMarker` is `private` and unreachable from tests, so this follows the pattern the test target already uses at `RetireSmartIRATests/GoldenScenario.swift:68`:

```swift
private final class BehaviorBaselineMarker {}
```

The tests are app-hosted, so `Bundle(for:)` on a class defined in the test target resolves the test bundle, which is where the generated fixture lands once it sits under `RetireSmartIRATests/`. `RetireSmartIRATests/` is a `PBXFileSystemSynchronizedRootGroup`, so the JSON is picked up with no project-file edit; if it is not found at Step 5, check bundle flattening before touching anything else. Phase 1 hit exactly that: `Resources/StateTaxData/2026/CA.json` bundles as a bare `CA.json` with the directory stripped, which is why the state files are year-prefixed. The single fixture name here is already unique, so flattening is harmless.

- [ ] **Step 2: Run it and watch it fail because the fixture does not exist**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -30
```

Expected: FAIL, "baseline fixture is not bundled". Paste the transcript.

- [ ] **Step 3: Add the generator that writes the fixture**

Append to the same file. It follows the pattern and the two gotchas documented in `StateTaxDataGeneratorTests.swift`: the env var must be shell-prefixed `TEST_RUNNER_`, and the sandbox must be disabled for the write.

```swift
/// Writes the frozen baseline. Run ONCE, from `main` before any Phase 3a
/// model change, and never again in this phase. See
/// StateTaxDataGeneratorTests.swift for why the env var needs the
/// TEST_RUNNER_ prefix and why ENABLE_APP_SANDBOX=NO is required.
///
///     TEST_RUNNER_STATE_TAX_BASELINE=1 xcodebuild test -scheme RetireSmartIRA \
///         -destination 'platform=macOS' \
///         -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineGeneratorTests \
///         ENABLE_APP_SANDBOX=NO
@Suite("State tax behavior baseline generator (manual)")
struct StateTaxBehaviorBaselineGeneratorTests {

    @Test("Generate the frozen behavior baseline",
          .enabled(if: ProcessInfo.processInfo.environment["STATE_TAX_BASELINE"] == "1"))
    func generate() throws {
        var baseline: [String: Double] = [:]
        for state in USState.allCases {
            for scenario in StateTaxBehaviorBaselineTests.scenarios {
                baseline[StateTaxBehaviorBaselineTests.key(state, scenario)] =
                    StateTaxBehaviorBaselineTests.computedTax(state: state, scenario: scenario)
            }
        }
        #expect(baseline.count == USState.allCases.count
                * StateTaxBehaviorBaselineTests.scenarios.count)

        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let outDir = repoRoot.appendingPathComponent("RetireSmartIRATests/Baselines")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(baseline).write(
            to: outDir.appendingPathComponent("statetax-behavior-baseline-2026.json"))
    }
}
```

- [ ] **Step 4: Generate the fixture**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && TEST_RUNNER_STATE_TAX_BASELINE=1 xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineGeneratorTests ENABLE_APP_SANDBOX=NO 2>&1 | tail -20
```

Then confirm the file exists and has 51 × 17 = 867 entries:

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && python3 -c "import json;d=json.load(open('RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json'));print(len(d))"
```

Expected: `867`. If the generator skipped (wrong env prefix) the file will not exist at all rather than being wrong; that is the failure mode to watch for.

- [ ] **Step 5: Run the assertion and watch it pass**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -20
```

Expected: PASS.

- [ ] **Step 6: Prove the baseline discriminates, by mutating the CODE**

Temporarily change `TaxCalculationEngine.swift`'s distribution gate from `>= 59` to `>= 60`:

```swift
let retirementAge = primaryAge >= 60 || (enableSpouse && spouseAge >= 60)
```

Re-run Step 5. Expected: FAIL, naming the "single 59, distributions only" scenario for the states with a non-`.none` IRA exemption. **Revert the mutation.** Paste both transcripts and name which states failed.

A second mutation, because one is not enough for a gate this load-bearing: change NJ's `regularExemptionMinAge` from `62` to `65` in `StateTaxData.swift`, re-run, expect NJ failures on the pension scenarios, revert.

- [ ] **Step 7: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add RetireSmartIRATests/StateTaxBehaviorBaselineTests.swift RetireSmartIRATests/Baselines/statetax-behavior-baseline-2026.json && git commit -m "test(state-tax): freeze the pre-Phase-3a behavior baseline for 51 jurisdictions"
```

---

### Task 2: State-aware distribution minimum age

Spec §3.3a. `TaxCalculationEngine.swift` hardcodes 59 in two places. Iowa qualifies at 55, so Phase 5 cannot fix Iowa by config alone.

**Files:**
- Modify: `RetireSmartIRA/StateTaxData.swift` (add the field to `RetirementIncomeExemptions`)
- Modify: `RetireSmartIRA/StateTaxCodable.swift` (encode and decode it)
- Modify: `RetireSmartIRA/TaxCalculationEngine.swift:539` and `:583`
- Test: `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift` (create)

**Interfaces:**
- Produces: `RetirementIncomeExemptions.distributionMinAge: Int` (default `59`). Tasks 5 and 6 read it.

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 3a adds fields that every state leaves at its default, so the phase
/// gate proves only that they changed nothing. That is necessary and not
/// sufficient: a field the engine never reads would also change nothing.
///
/// This suite proves each new field is LOAD-BEARING, by building a synthetic
/// config with the field set away from its default and asserting the engine
/// responds. Every state's real config still uses the default; these are
/// hand-built configs passed through `configOverride`.
@Suite("Phase 3a mechanisms are load-bearing")
struct StateTaxPhase3aMechanismTests {

    /// A flat 10% state with a full IRA exemption, so the exemption's presence
    /// or absence is visible as a clean 10% of the distribution amount.
    static func flatTenPercent(
        exemptions: RetirementIncomeExemptions
    ) -> StateTaxConfig {
        StateTaxConfig(
            state: .iowa,
            taxSystem: .flat(rate: 0.10),
            retirementExemptions: exemptions,
            stateDeduction: .none
        )
    }

    static func tax(config: StateTaxConfig, age: Int, distributions: Double) -> Double {
        TaxCalculationEngine.calculateStateTax(
            income: distributions,
            forState: .iowa,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: [],
            currentAge: age,
            enableSpouse: false,
            spouseBirthYear: 2026 - age,
            currentYear: 2026,
            scenarioRetirementDistributions: distributions,
            configOverride: config
        )
    }

    @Test("distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59")
    func distributionMinAgeIsHonored() {
        let atFiftyFive = Self.flatTenPercent(
            exemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full,
                distributionMinAge: 55))
        let atDefault = Self.flatTenPercent(
            exemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full))

        // Age 56: exempt under a 55 gate, taxed under the default 59 gate.
        #expect(Self.tax(config: atFiftyFive, age: 56, distributions: 40_000) == 0)
        #expect(Self.tax(config: atDefault, age: 56, distributions: 40_000) == 4_000)

        // Age 60 is above both gates, so both exempt. This second pair is what
        // stops the first pair from passing for the wrong reason (a config that
        // simply never exempts anything).
        #expect(Self.tax(config: atFiftyFive, age: 60, distributions: 40_000) == 0)
        #expect(Self.tax(config: atDefault, age: 60, distributions: 40_000) == 0)
    }

    @Test("distributionMinAge defaults to 59, reproducing the previous hardcoded gate")
    func distributionMinAgeDefaultsTo59() {
        #expect(RetirementIncomeExemptions().distributionMinAge == 59)
    }
}
```

- [ ] **Step 2: Run it and watch it fail to compile**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests 2>&1 | tail -30
```

Expected: compile error, `extra argument 'distributionMinAge' in call`. Paste it.

- [ ] **Step 3: Add the field**

In `RetireSmartIRA/StateTaxData.swift`, inside `struct RetirementIncomeExemptions`, immediately after `regularExemptionMinAge`:

```swift
    /// Minimum age at which `scenarioRetirementDistributions` (RMDs computed
    /// from balances, inherited-IRA RMDs, and extra withdrawals) becomes
    /// eligible for the state's IRA exemption, and the fallback age used to
    /// decide whether a spouse qualifies when `regularExemptionMinAge` is 0.
    ///
    /// 59 reproduces the constant this replaced, which was hardcoded in
    /// `TaxCalculationEngine.applyRetirementExemptions` in two places and
    /// therefore unreachable from config. Iowa qualifies at 55 (HF 2317), so
    /// config alone could not fix Iowa while this was a literal. The value is
    /// 59 rather than 59.5 because the engine works in integer ages; that
    /// approximation predates this phase and is unchanged by it.
    ///
    /// Changed away from 59 only in Phase 5, gated by a golden scenario.
    var distributionMinAge: Int = 59
```

- [ ] **Step 4: Make the engine read it**

In `RetireSmartIRA/TaxCalculationEngine.swift`, inside `applyRetirementExemptions`, replace the body of `ageQualifiesForExemption`'s final line:

```swift
            return age >= exemptions.distributionMinAge
```

and replace the `retirementAge` line:

```swift
        let retirementAge = primaryAge >= exemptions.distributionMinAge
            || (enableSpouse && spouseAge >= exemptions.distributionMinAge)
```

Also delete the now-false clause from the comment block above `var adjusted = income` that says this function "applies a flat 59.5 baseline to `scenarioRetirementDistributions`, which is wrong for Iowa (qualifies at 55)". That statement stops being true at this step; leaving it would point a future engineer at work already done. Keep the sentence about pension and IRA not being splittable by source, which is still true and is Phase 3b's job.

- [ ] **Step 5: Add Codable support**

In `RetireSmartIRA/StateTaxCodable.swift`, `extension RetirementIncomeExemptions: Codable`, add `distributionMinAge` to `CodingKeys`, add to `encode(to:)`:

```swift
        try c.encode(distributionMinAge, forKey: .distributionMinAge)
```

and to `init(from:)`, as an argument to `self.init(...)` in declaration order (after `regularExemptionMinAge`, before `earlyAgeTier`):

```swift
            distributionMinAge: try c.decodeIfPresent(Int.self, forKey: .distributionMinAge) ?? 59,
```

The `?? 59` matters: the 51 checked-in JSON files do not carry this key until Task 8 regenerates them, and the Phase 1 gate runs against them in the meantime.

- [ ] **Step 6: Run the mechanism test and the baseline**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -25
```

Expected: both PASS. The baseline passing is the inertness proof for this task.

- [ ] **Step 7: Run the full suite**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/phase3a-task2.log | tail -40
```

Expected: 0 failures, Swift Testing count = baseline + 2. Confirm the tree with:

```bash
grep -c "worktrees/state-tax-phase3a" /tmp/phase3a-task2.log
```

Expected: a non-zero count. Paste both summary lines.

- [ ] **Step 8: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "feat(state-tax): make the distribution age gate configurable, defaulting to 59"
```

---

### Task 3: `personalExemption` as a first-class field

Spec §3.1 and §4. New Jersey's personal exemption is a hardcoded function today; Kansas has none at all, which is Steve Nicolai's 08-01 bug. This task adds the field and moves NJ onto it **without changing NJ's computed value and without giving Kansas anything.**

**Files:**
- Create: `RetireSmartIRA/StatePersonalExemption.swift`
- Modify: `RetireSmartIRA/StateTaxData.swift` (field on `StateTaxConfig`; NJ config gains a value)
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRA/DataManager.swift:659-671` and `:903-915`
- Modify: `RetireSmartIRA/TaxCalculationEngine.swift:452-466` (`njPersonalExemptions` becomes a deprecated shim)
- Test: `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`

**Interfaces:**
- Produces: `StatePersonalExemption` with `amount(filingStatus:enableSpouse:primaryAge:spouseAge:) -> Double`, and `StateTaxConfig.personalExemption: StatePersonalExemption?` (default `nil`). Task 8 adds its key to Layer C's optional set and regenerates NJ's file with it.

**The exactness requirement:** `njPersonalExemptions` grants the spouse's amounts only when `filingStatus == .marriedFilingJointly && enableSpouse`. A filer on MFJ with no spouse configured gets the single amounts. `amount(...)` must reproduce that, which is why it takes `enableSpouse` rather than filing status alone. Baseline scenario "MFJ status but spouse disabled, 66" exists to catch getting this wrong.

- [ ] **Step 1: Write the failing test**

Add to `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`:

```swift
    // MARK: - personalExemption

    /// New Jersey's four documented outcomes, from
    /// TaxCalculationEngine.njPersonalExemptions' own doc comment:
    ///   single under 65 -> 1,000; single 65+ -> 2,000;
    ///   MFJ both under 65 -> 2,000; MFJ both 65+ -> 4,000.
    static let njExemption = StatePersonalExemption(
        single: 1_000, marriedFilingJointly: 2_000,
        seniorAdditionalPerFiler: 1_000, seniorAge: 65)

    @Test("StatePersonalExemption reproduces New Jersey's four documented outcomes")
    func personalExemptionMatchesNJ() {
        let e = Self.njExemption
        #expect(e.amount(filingStatus: .single, enableSpouse: false,
                         primaryAge: 64, spouseAge: 64) == 1_000)
        #expect(e.amount(filingStatus: .single, enableSpouse: false,
                         primaryAge: 65, spouseAge: 65) == 2_000)
        #expect(e.amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                         primaryAge: 64, spouseAge: 64) == 2_000)
        #expect(e.amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                         primaryAge: 65, spouseAge: 65) == 4_000)
    }

    @Test("A filer on MFJ with no spouse configured gets the single amounts")
    func personalExemptionIgnoresMFJWithoutASpouse() {
        let e = Self.njExemption
        #expect(e.amount(filingStatus: .marriedFilingJointly, enableSpouse: false,
                         primaryAge: 64, spouseAge: 64) == 1_000)
        #expect(e.amount(filingStatus: .marriedFilingJointly, enableSpouse: false,
                         primaryAge: 70, spouseAge: 70) == 2_000)
    }

    @Test("Only one spouse over the senior age gets exactly one senior addition")
    func personalExemptionSeniorIsPerFiler() {
        #expect(Self.njExemption.amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                                        primaryAge: 66, spouseAge: 60) == 3_000)
    }

    @Test("A state with no senior addition ignores age entirely")
    func personalExemptionWithoutSeniorTierIgnoresAge() {
        // Shaped like Kansas: a flat per-return amount, no age component.
        // NOTE: Kansas's real config is NOT given this value in Phase 3a.
        // Correcting Kansas is Phase 5a, gated by a golden scenario.
        let flat = StatePersonalExemption(
            single: 9_160, marriedFilingJointly: 18_320,
            seniorAdditionalPerFiler: 0, seniorAge: 65)
        #expect(flat.amount(filingStatus: .single, enableSpouse: false,
                            primaryAge: 80, spouseAge: 80) == 9_160)
        #expect(flat.amount(filingStatus: .marriedFilingJointly, enableSpouse: true,
                            primaryAge: 80, spouseAge: 80) == 18_320)
    }

    @Test("New Jersey's config carries the personal exemption; no other state does")
    func onlyNewJerseyCarriesAPersonalExemptionInPhase3a() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        for state in USState.allCases {
            let config = try #require(configs[state])
            if state == .newJersey {
                #expect(config.personalExemption != nil)
            } else {
                #expect(config.personalExemption == nil,
                        "\(state.abbreviation) gained a personal exemption in Phase 3a. \
                        Phase 3a adds no state's exemption except New Jersey's, which \
                        already existed in hardcoded form. Kansas and the rest are Phase 5a.")
            }
        }
    }
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests 2>&1 | tail -30
```

Expected: compile error, `cannot find 'StatePersonalExemption' in scope`. Paste it.

- [ ] **Step 3: Create the type**

Create `RetireSmartIRA/StatePersonalExemption.swift`:

```swift
import Foundation

/// A state's personal exemption: an amount subtracted from state taxable
/// income AFTER retirement-income exclusions and their income-gated
/// phase-outs, because those phase-outs key off total income rather than
/// income net of exemptions.
///
/// This did not exist as a field before Phase 3a. New Jersey's was a hardcoded
/// function (`TaxCalculationEngine.njPersonalExemptions`) and California's are
/// credits rather than exemptions, computed separately. Kansas has one and the
/// app grants none, which overstates every married Kansas filer by $952.64 a
/// year: that is Steve Nicolai's 2026-08-01 report, and it is corrected in
/// Phase 5a, not here.
///
/// Amounts are stated per RETURN, not per filer, because that is how state
/// instructions publish them. New Jersey's $1,000-per-filer regular exemption
/// therefore appears as `single: 1_000, marriedFilingJointly: 2_000`.
struct StatePersonalExemption: Codable, Equatable, Sendable {
    /// Total regular exemption for a single filer.
    let single: Double

    /// Total regular exemption for a joint return with a spouse configured.
    let marriedFilingJointly: Double

    /// Additional amount granted for EACH filer at or above `seniorAge`.
    /// New Jersey grants $1,000 each. Most states grant nothing; set 0.
    let seniorAdditionalPerFiler: Double

    /// Age at which `seniorAdditionalPerFiler` applies. Ignored when that is 0.
    let seniorAge: Int

    /// The exemption for this household.
    ///
    /// `enableSpouse` is a separate argument rather than being inferred from
    /// `filingStatus` on purpose: the app allows a filing status of married
    /// filing jointly with no spouse actually configured, and the behavior this
    /// replaces treated that case as a single filer. Reproducing it exactly is
    /// a Phase 3a requirement.
    func amount(
        filingStatus: FilingStatus,
        enableSpouse: Bool,
        primaryAge: Int,
        spouseAge: Int
    ) -> Double {
        let hasSpouse = filingStatus == .marriedFilingJointly && enableSpouse
        var total = hasSpouse ? marriedFilingJointly : single
        if seniorAdditionalPerFiler > 0 {
            if primaryAge >= seniorAge { total += seniorAdditionalPerFiler }
            if hasSpouse && spouseAge >= seniorAge { total += seniorAdditionalPerFiler }
        }
        return total
    }
}
```

- [ ] **Step 4: Add the field to `StateTaxConfig` and give New Jersey its value**

In `RetireSmartIRA/StateTaxData.swift`, add a stored property after `verification`:

```swift
    /// The state's personal exemption, or nil where the state grants none.
    /// Applied by the caller as `postExemptionDeduction`, after the retirement
    /// exclusions. Only New Jersey carries one in Phase 3a; the states the
    /// 2026-08-02 audit found to need one (Kansas first among them) get theirs
    /// in Phase 5a, each gated by a golden scenario.
    let personalExemption: StatePersonalExemption?
```

Add the init parameter last, `personalExemption: StatePersonalExemption? = nil`, and the matching assignment.

In the `configs[.newJersey]` entry (around line 1614), add:

```swift
            // NJ-1040 personal exemptions: $1,000 regular per filer, plus
            // another $1,000 per filer age 65+. NJ has no standard deduction.
            // These values are a lift-and-shift of njPersonalExemptions, which
            // this replaces; they are not a Phase 3a correction.
            personalExemption: StatePersonalExemption(
                single: 1_000, marriedFilingJointly: 2_000,
                seniorAdditionalPerFiler: 1_000, seniorAge: 65)
```

- [ ] **Step 5: Add Codable support**

In `StateTaxCodable.swift`, `extension StateTaxConfig: Codable`: add `personalExemption` to `CodingKeys`, and to `encode(to:)`:

```swift
        try c.encodeIfPresent(personalExemption, forKey: .personalExemption)
```

`encodeIfPresent`, not `encode`, so the key appears only in New Jersey's file rather than as `null` in 50 others. Task 8 teaches Layer C about optional keys.

To `init(from:)`, as the last argument:

```swift
            personalExemption: try c.decodeIfPresent(
                StatePersonalExemption.self, forKey: .personalExemption)
```

- [ ] **Step 6: Move both call sites onto the config**

In `RetireSmartIRA/DataManager.swift` at both line 659-671 and line 903-915, replace the `state == .newJersey ? TaxCalculationEngine.njPersonalExemptions(...) : 0` expression with:

```swift
        // Personal exemptions reduce taxable income AFTER the retirement
        // exclusions and their income-gated phaseouts, so they are passed as
        // `postExemptionDeduction` rather than subtracted from the phaseout
        // gate here. States with no personal exemption return 0.
        let statePersonalExemption = config.personalExemption?.amount(
            filingStatus: filingStatus, enableSpouse: enableSpouse,
            primaryAge: currentAge, spouseAge: spouseCurrentAge) ?? 0
```

and pass `postExemptionDeduction: statePersonalExemption`. Check the local variable names at each site before editing; the second site (around line 903) may name the ages differently.

**Do not touch `ProjectionEngine.computeStateTax`.** Multi-year still passes no `postExemptionDeduction`. That divergence is I2 and it is pinned by `GoldenScenarioCrossPathTests`; closing it here would move a pinned value and take a Phase 5d correction without its golden scenario.

- [ ] **Step 7: Turn `njPersonalExemptions` into a shim**

Four tests in `NJOtherExclusionAndExemptionsTests.swift` and one call in `GoldenScenarioSingleYearTests.swift` call it. Keep the symbol, delegate the arithmetic, so those tests keep testing the same behavior through the new path:

```swift
    /// Retained for tests that predate Phase 3a. New Jersey's amounts now live
    /// in `StateTaxConfig.personalExemption`; this delegates so there is one
    /// implementation rather than two that can drift.
    static func njPersonalExemptions(
        filingStatus: FilingStatus,
        enableSpouse: Bool,
        primaryAge: Int,
        spouseAge: Int
    ) -> Double {
        guard let exemption = StateTaxData.config(for: .newJersey).personalExemption else {
            return 0
        }
        return exemption.amount(filingStatus: filingStatus, enableSpouse: enableSpouse,
                                primaryAge: primaryAge, spouseAge: spouseAge)
    }
```

- [ ] **Step 8: Run the mechanism tests, the NJ tests, the golden scenarios and the baseline**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests -only-testing:RetireSmartIRATests/NJOtherExclusionAndExemptionsTests -only-testing:RetireSmartIRATests/GoldenScenarioCrossPathTests 2>&1 | tail -30
```

Expected: all PASS, including the pinned cross-path values 42.0 and 200.40469973890345.

- [ ] **Step 9: Full suite, then commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/phase3a-task3.log | tail -40
```

Paste both summary lines and confirm the tree, then:

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "feat(state-tax): personalExemption as a config field, New Jersey moved onto it"
```

---

### Task 4: AGI phase-out mechanism

Spec §3.3d. Six jurisdictions reduce or eliminate an exemption as income rises and only New Jersey has a bespoke mechanism. The audit item calls this "arguably more important than any single state" for a conversion tool, because a large conversion is exactly what lifts AGI through these thresholds.

**Two shapes, both taken from the audit, neither speculative:**
- **Cliff.** New Mexico's $8,000 requires AGI under $28,500 single / $51,000 MFJ. Rhode Island's modification is AGI-limited the same way.
- **Linear reduction.** Virginia reduces its $12,000 by $1 for every $1 of AGI over $50,000 single / $75,000 married. Connecticut's ramp from $75,000/$100,000 to $100,000/$150,000 is the same shape with a fractional rate.

**Files:**
- Create: `RetireSmartIRA/StateAGIPhaseout.swift`
- Modify: `RetireSmartIRA/StateTaxData.swift` (field on `RetirementIncomeExemptions`)
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRA/TaxCalculationEngine.swift` (apply it to the computed exclusion)
- Test: `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`

**Interfaces:**
- Produces: `AGIPhaseout` with `reduced(exclusion:totalGrossIncome:isMarried:) -> Double`, and `RetirementIncomeExemptions.agiPhaseout: AGIPhaseout?` (default `nil`).

**Basis note, to be settled in Phase 5 not here:** the phase-out gates on the `income` argument, the same total-gross-income figure New Jersey's stepped tiers already use. Virginia's statute keys off Virginia AFAGI, which is not the same number. Phase 3a deliberately does not attempt that distinction; every state's `agiPhaseout` is nil, so nothing is decided by this choice yet, and Virginia's golden scenario in Phase 4 will pin the correct basis. Record this in the type's doc comment so nobody later assumes the basis was verified.

- [ ] **Step 1: Write the failing test**

Add to `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`:

```swift
    // MARK: - AGI phase-out

    @Test("A cliff phase-out removes the whole exclusion above the threshold and nothing below it")
    func agiPhaseoutCliff() {
        let cliff = AGIPhaseout(thresholdSingle: 28_500, thresholdMFJ: 51_000, shape: .cliff)
        #expect(cliff.reduced(exclusion: 8_000, totalGrossIncome: 28_500, isMarried: false) == 8_000)
        #expect(cliff.reduced(exclusion: 8_000, totalGrossIncome: 28_501, isMarried: false) == 0)
        // The MFJ threshold is a DIFFERENT number, so a single/married swap is visible.
        #expect(cliff.reduced(exclusion: 8_000, totalGrossIncome: 40_000, isMarried: true) == 8_000)
        #expect(cliff.reduced(exclusion: 8_000, totalGrossIncome: 40_000, isMarried: false) == 0)
    }

    @Test("A dollar-for-dollar phase-out reduces the exclusion by the excess and floors at zero")
    func agiPhaseoutLinearDollarForDollar() {
        // Virginia's shape: $12,000 reduced $1 per $1 over $50,000 / $75,000.
        let va = AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                             shape: .linear(perDollar: 1.0))
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 50_000, isMarried: false) == 12_000)
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 55_000, isMarried: false) == 7_000)
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 62_000, isMarried: false) == 0)
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 90_000, isMarried: false) == 0)
        #expect(va.reduced(exclusion: 12_000, totalGrossIncome: 80_000, isMarried: true) == 7_000)
    }

    @Test("A fractional ramp reaches zero at the far end of the band")
    func agiPhaseoutLinearFractional() {
        // Connecticut's shape: full below 75,000, zero at 100,000, so a
        // 100% exclusion of a 40,000 pension ramps out over a 25,000 band.
        let ct = AGIPhaseout(thresholdSingle: 75_000, thresholdMFJ: 100_000,
                             shape: .linear(perDollar: 40_000 / 25_000))
        #expect(ct.reduced(exclusion: 40_000, totalGrossIncome: 75_000, isMarried: false) == 40_000)
        #expect(ct.reduced(exclusion: 40_000, totalGrossIncome: 87_500, isMarried: false) == 20_000)
        #expect(ct.reduced(exclusion: 40_000, totalGrossIncome: 100_000, isMarried: false) == 0)
    }

    @Test("agiPhaseout reaches the engine and reduces real computed tax")
    func agiPhaseoutIsWiredIntoTheEngine() {
        let exemptions = RetirementIncomeExemptions(
            socialSecurityExempt: true,
            pensionExemption: .partial(maxExempt: 12_000),
            iraWithdrawalExemption: .none,
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                                     shape: .linear(perDollar: 1.0)))
        let config = Self.flatTenPercent(exemptions: exemptions)

        func tax(income: Double) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: income, forState: .iowa, filingStatus: .single,
                taxableSocialSecurity: 0,
                incomeSources: [IncomeSource(name: "Pension", type: .pension,
                                             annualAmount: 40_000)],
                currentAge: 70, enableSpouse: false, spouseBirthYear: 1956,
                currentYear: 2026, configOverride: config)
        }
        // At 50,000: full 12,000 exclusion -> 38,000 taxable -> 3,800.
        #expect(tax(income: 50_000) == 3_800)
        // At 55,000: exclusion cut to 7,000 -> 48,000 taxable -> 4,800.
        #expect(tax(income: 55_000) == 4_800)
        // At 70,000: exclusion gone -> 70,000 taxable -> 7,000.
        #expect(tax(income: 70_000) == 7_000)
    }

    @Test("No jurisdiction carries an agiPhaseout in Phase 3a")
    func noStateHasAnAGIPhaseoutYet() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        for state in USState.allCases {
            let config = try #require(configs[state])
            #expect(config.retirementExemptions.agiPhaseout == nil,
                    "\(state.abbreviation) gained an AGI phase-out in Phase 3a. \
                    CT, VA, ME, RI, WV and NM get theirs in Phase 5, each gated \
                    by a golden scenario that also pins the correct income basis.")
        }
    }
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests 2>&1 | tail -30
```

Expected: compile error, `cannot find 'AGIPhaseout' in scope`. Paste it.

- [ ] **Step 3: Create the type**

Create `RetireSmartIRA/StateAGIPhaseout.swift`:

```swift
import Foundation

/// Reduces a computed retirement-income exclusion as income rises.
///
/// Six jurisdictions in the 2026-08-02 audit need this (CT, VA, ME, RI, WV,
/// NM) and before Phase 3a only New Jersey had a mechanism, bespoke to its own
/// stepped Worksheet D bands. For a Roth conversion planner this matters more
/// than the individual state values: a large conversion is precisely what
/// lifts AGI through these thresholds, so modeling an exemption as
/// unconditional promises the user something the recommended action destroys.
///
/// INCOME BASIS, NOT YET VERIFIED. `reduced(exclusion:totalGrossIncome:...)`
/// is called with the same total-gross-income figure New Jersey's stepped
/// tiers already gate on. Several statutes key off a state-specific AGI that
/// is not that number (Virginia uses Virginia AFAGI). Phase 3a does not decide
/// this, because no state carries a phase-out yet; each state's Phase 4 golden
/// scenario pins its own basis and Phase 5 corrects the call site if needed.
/// Do not read this type's existence as evidence the basis was checked.
struct AGIPhaseout: Codable, Equatable, Sendable {
    /// Income at or below which the exclusion is unreduced, for a single filer.
    let thresholdSingle: Double

    /// The same, for a joint return.
    let thresholdMFJ: Double

    let shape: Shape

    enum Shape: Equatable, Sendable {
        /// The exclusion drops to zero the moment income exceeds the
        /// threshold. New Mexico's $28,500 / $51,000 limits are this shape.
        case cliff

        /// The exclusion is reduced by `perDollar` for every dollar of income
        /// above the threshold, floored at zero.
        ///
        /// Virginia reduces $1 per $1, so `perDollar` is 1.0. A ramp that
        /// reaches zero at some `end` is `perDollar = exclusion / (end - threshold)`.
        case linear(perDollar: Double)
    }

    func reduced(exclusion: Double, totalGrossIncome: Double, isMarried: Bool) -> Double {
        let threshold = isMarried ? thresholdMFJ : thresholdSingle
        let excess = totalGrossIncome - threshold
        guard excess > 0 else { return exclusion }
        switch shape {
        case .cliff:
            return 0
        case .linear(let perDollar):
            return max(0, exclusion - excess * perDollar)
        }
    }
}
```

`Shape` needs a hand-written Codable because it carries an associated value; write it in `StateTaxCodable.swift` in Step 5 alongside the others rather than here, matching where every other hand-written conformance in this codebase lives.

- [ ] **Step 4: Add the field and wire the engine**

In `StateTaxData.swift`, inside `RetirementIncomeExemptions`, after `otherRetirementIncomeExclusion`:

```swift
    /// Reduces the computed pension and IRA exclusion as income rises. nil
    /// (the default, and every state's value in Phase 3a) means no reduction.
    var agiPhaseout: AGIPhaseout? = nil
```

In `TaxCalculationEngine.applyRetirementExemptions`, apply it to each computed exclusion before subtracting. In the shared-cap branch:

```swift
            let rawExclusion = effectivePensionExemption.excludedAmount(
                eligibleIncome: combinedIncome,
                totalGrossIncome: income,
                isMarried: isMarried,
                perIndividualMultiplier: perIndividualMultiplier
            )
            let pensionIRAExclusion = exemptions.agiPhaseout?.reduced(
                exclusion: rawExclusion, totalGrossIncome: income, isMarried: isMarried
            ) ?? rawExclusion
            adjusted -= pensionIRAExclusion
```

Note `pensionIRAExclusion` is read again by the Worksheet D block below it, so introduce the reduced value under the existing name and leave that block untouched.

In the independent-cap branch, apply it to each of the two subtractions the same way, binding each to a local first so the reduction is visible in a debugger and in a diff:

```swift
            let rawPension = effectivePensionExemption.excludedAmount(
                eligibleIncome: pensionIncome, totalGrossIncome: income,
                isMarried: isMarried, perIndividualMultiplier: perIndividualMultiplier)
            adjusted -= exemptions.agiPhaseout?.reduced(
                exclusion: rawPension, totalGrossIncome: income, isMarried: isMarried) ?? rawPension

            let rawIRA = effectiveIRAExemption.excludedAmount(
                eligibleIncome: iraIncome, totalGrossIncome: income,
                isMarried: isMarried, perIndividualMultiplier: perIndividualMultiplier)
            adjusted -= exemptions.agiPhaseout?.reduced(
                exclusion: rawIRA, totalGrossIncome: income, isMarried: isMarried) ?? rawIRA
```

- [ ] **Step 5: Codable for `AGIPhaseout.Shape`**

In `StateTaxCodable.swift`:

```swift
extension AGIPhaseout.Shape: Codable {
    private enum CodingKeys: String, CodingKey { case kind, perDollar }
    private enum Kind: String, Codable { case cliff, linear }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .cliff:
            try c.encode(Kind.cliff, forKey: .kind)
        case .linear(let perDollar):
            try c.encode(Kind.linear, forKey: .kind)
            try c.encode(perDollar, forKey: .perDollar)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .cliff:
            self = .cliff
        case .linear:
            self = .linear(perDollar: try c.decode(Double.self, forKey: .perDollar))
        }
    }
}
```

No `default:` branch in either switch, so a third shape breaks compilation instead of silently misdecoding. That is the convention every other conformance in this file follows and Phase 1's reviewer verified it deliberately.

Add `agiPhaseout` to `RetirementIncomeExemptions`'s `CodingKeys`, `try c.encodeIfPresent(agiPhaseout, forKey: .agiPhaseout)` to `encode(to:)`, and `agiPhaseout: try c.decodeIfPresent(AGIPhaseout.self, forKey: .agiPhaseout)` to `init(from:)` in declaration order.

- [ ] **Step 6: Add a round-trip test with asymmetric data**

Add to `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`:

```swift
    @Test("AGIPhaseout round-trips both shapes with distinct per-field values")
    func agiPhaseoutRoundTrips() throws {
        // Thresholds deliberately different from each other so a single/MFJ
        // swap is detectable, and perDollar deliberately not 1.0 so a dropped
        // payload is not masked by a plausible default.
        let cases: [AGIPhaseout] = [
            AGIPhaseout(thresholdSingle: 28_500, thresholdMFJ: 51_000, shape: .cliff),
            AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                        shape: .linear(perDollar: 1.6))
        ]
        for original in cases {
            let decoded = try JSONDecoder().decode(
                AGIPhaseout.self, from: JSONEncoder().encode(original))
            #expect(decoded == original)
        }
    }
```

- [ ] **Step 7: Run the mechanism tests and the baseline, then the full suite**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests -only-testing:RetireSmartIRATests/StateTaxCodableRoundTripTests 2>&1 | tail -25
```

Then the full suite, tee'd to `/tmp/phase3a-task4.log`, both summary lines pasted, tree confirmed.

- [ ] **Step 8: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "feat(state-tax): general AGI phase-out mechanism, no jurisdiction using it yet"
```

---

### Task 5: Per-qualifying-spouse attribution

Spec §3.3e. The age gate today is `max(primaryAge, spouseAge)` for the exemption level and `||` for the distribution gate, so **either** spouse qualifying unlocks the exemption for all household retirement income. At least seven statutes (OK, DE, LA, AR, AL, WI, RI) are per-person, and Iowa's exclusion is explicitly per-qualifying-spouse.

**Files:**
- Modify: `RetireSmartIRA/StateTaxData.swift`
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRA/TaxCalculationEngine.swift`
- Test: `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`

**Interfaces:**
- Produces: `ExemptionAttribution` (enum, `.household` default) and `RetirementIncomeExemptions.exemptionAttribution: ExemptionAttribution`.

**The convention this task chooses, and it is the only place in Phase 3a that chooses one.** Under `.perQualifyingSpouse`:
- A `.pension` or `.rmd` `IncomeSource` row is gated by ITS OWNER's age. `IncomeSource` already carries `owner: Owner` and the military-retirement loop directly above already uses it this way, so this reuses an established pattern rather than inventing one.
- An `.joint`-owned row is gated by the more generous of the two ages, matching what `.joint` means everywhere else in this codebase.
- `scenarioRetirementDistributions` is a single scalar with no owner in the engine's signature, so it is gated on the PRIMARY's age. Write this limitation into the doc comment in the same sentence as the rule, and state that a state adopting `.perQualifyingSpouse` must carry a matching `knownLimitations` entry.

None of this is reachable in Phase 3a: every state stays `.household`. Iowa's Phase 4 golden scenario is what confirms or corrects the convention, and it will be the first case that can.

- [ ] **Step 1: Write the failing test**

Add to `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`:

```swift
    // MARK: - attribution

    static func mfjTax(
        config: StateTaxConfig, primaryAge: Int, spouseAge: Int,
        sources: [IncomeSource], scenarioDistributions: Double = 0
    ) -> Double {
        let income = sources.reduce(0) { $0 + $1.annualAmount } + scenarioDistributions
        return TaxCalculationEngine.calculateStateTax(
            income: income, forState: .iowa, filingStatus: .marriedFilingJointly,
            taxableSocialSecurity: 0, incomeSources: sources,
            currentAge: primaryAge, enableSpouse: true,
            spouseBirthYear: 2026 - spouseAge, currentYear: 2026,
            scenarioRetirementDistributions: scenarioDistributions,
            configOverride: config)
    }

    static func attributionConfig(_ attribution: ExemptionAttribution) -> StateTaxConfig {
        flatTenPercent(exemptions: RetirementIncomeExemptions(
            socialSecurityExempt: true,
            pensionExemption: .full,
            iraWithdrawalExemption: .full,
            regularExemptionMinAge: 65,
            exemptionAttribution: attribution))
    }

    @Test("Household attribution exempts a non-qualifying spouse's pension when the other qualifies")
    func householdAttributionIsTodaysBehavior() {
        let config = Self.attributionConfig(.household)
        let spousePension = [IncomeSource(name: "Pension", type: .pension,
                                          annualAmount: 40_000, owner: .spouse)]
        // Primary 70 qualifies, spouse 60 does not. Household: fully exempt.
        #expect(Self.mfjTax(config: config, primaryAge: 70, spouseAge: 60,
                            sources: spousePension) == 0)
    }

    @Test("Per-qualifying-spouse attribution taxes the non-qualifying spouse's own pension")
    func perQualifyingSpouseAttributionGatesByOwner() {
        let config = Self.attributionConfig(.perQualifyingSpouse)
        let spousePension = [IncomeSource(name: "Pension", type: .pension,
                                          annualAmount: 40_000, owner: .spouse)]
        // Spouse is 60, below the 65 gate, so the spouse's own pension is taxed
        // even though the primary qualifies.
        #expect(Self.mfjTax(config: config, primaryAge: 70, spouseAge: 60,
                            sources: spousePension) == 4_000)
        // Once the spouse qualifies, it is exempt again. Without this second
        // case the first could pass for a config that exempts nothing.
        #expect(Self.mfjTax(config: config, primaryAge: 70, spouseAge: 66,
                            sources: spousePension) == 0)
    }

    @Test("Per-qualifying-spouse attribution still exempts the qualifying spouse's own pension")
    func perQualifyingSpouseAttributionKeepsTheQualifyingOwnersExemption() {
        let config = Self.attributionConfig(.perQualifyingSpouse)
        let primaryPension = [IncomeSource(name: "Pension", type: .pension,
                                           annualAmount: 40_000, owner: .primary)]
        #expect(Self.mfjTax(config: config, primaryAge: 70, spouseAge: 60,
                            sources: primaryPension) == 0)
    }

    @Test("A joint-owned row qualifies when either spouse qualifies, under both attributions")
    func jointOwnedRowsUseTheMoreGenerousAge() {
        let jointPension = [IncomeSource(name: "Pension", type: .pension,
                                         annualAmount: 40_000, owner: .joint)]
        #expect(Self.mfjTax(config: Self.attributionConfig(.household),
                            primaryAge: 70, spouseAge: 60, sources: jointPension) == 0)
        #expect(Self.mfjTax(config: Self.attributionConfig(.perQualifyingSpouse),
                            primaryAge: 70, spouseAge: 60, sources: jointPension) == 0)
    }

    @Test("Scenario distributions have no owner, so per-spouse attribution gates them on the primary")
    func scenarioDistributionsAreAttributedToThePrimary() {
        let config = Self.attributionConfig(.perQualifyingSpouse)
        // Primary 60 below the gate, spouse 70 above it. Household would exempt;
        // per-spouse attributes the unowned scalar to the primary, so it is taxed.
        #expect(Self.mfjTax(config: config, primaryAge: 60, spouseAge: 70,
                            sources: [], scenarioDistributions: 40_000) == 4_000)
        #expect(Self.mfjTax(config: Self.attributionConfig(.household),
                            primaryAge: 60, spouseAge: 70,
                            sources: [], scenarioDistributions: 40_000) == 0)
    }

    @Test("Every jurisdiction uses household attribution in Phase 3a")
    func noStateUsesPerSpouseAttributionYet() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        for state in USState.allCases {
            let config = try #require(configs[state])
            #expect(config.retirementExemptions.exemptionAttribution == .household,
                    "\(state.abbreviation) changed attribution in Phase 3a. Iowa and the \
                    per-person statutes adopt it in Phase 5c, each gated by a golden scenario.")
        }
    }
```

`IncomeSource`'s initializer signature must be checked before writing these: confirm `owner:` is an accepted argument with a default, and match the real parameter order. Run `grep -n "init(" -A 20 RetireSmartIRA/IncomeModels.swift` first.

- [ ] **Step 2: Run it, watch it fail to compile**

Expected: `cannot find 'ExemptionAttribution' in scope`. Paste it.

- [ ] **Step 3: Add the type and field**

In `RetireSmartIRA/StateTaxData.swift`, above `struct RetirementIncomeExemptions`:

```swift
/// How a state's retirement exemption is attributed between spouses on a
/// joint return.
enum ExemptionAttribution: String, Codable, Equatable, Sendable {
    /// Either spouse qualifying unlocks the exemption for all of the
    /// household's retirement income. This is what the engine did for every
    /// state before Phase 3a and it remains every state's value through
    /// Phase 3a.
    case household

    /// Each spouse's exemption is gated by that spouse's own age and applies
    /// only to income attributed to that spouse. Iowa's exclusion is written
    /// this way, as are at least seven other per-person statutes (OK, DE, LA,
    /// AR, AL, WI, RI).
    ///
    /// ATTRIBUTION RULES, and the one limitation they carry:
    ///   - A `.pension` or `.rmd` income row is gated by its `owner`'s age.
    ///   - A `.joint`-owned row is gated by the more generous of the two ages,
    ///     which is what `.joint` means elsewhere in this codebase.
    ///   - `scenarioRetirementDistributions` reaches the engine as a single
    ///     scalar with no owner, so it is gated on the PRIMARY's age. A state
    ///     adopting this case must carry a `knownLimitations` sentence saying
    ///     so, because a household whose spouse holds the IRA will be modeled
    ///     conservatively.
    case perQualifyingSpouse
}
```

Inside `RetirementIncomeExemptions`, after `exemptionAppliesPerIndividual`:

```swift
    /// See `ExemptionAttribution`. `.household` reproduces the behavior every
    /// state had before Phase 3a.
    var exemptionAttribution: ExemptionAttribution = .household
```

- [ ] **Step 4: Wire the engine**

In `applyRetirementExemptions`, `effectiveAge` and the `pensionIncome` / `rmdSourceIncome` sums become attribution-aware. Replace the `pensionIncome` and `rmdSourceIncome` computations with owner-filtered versions:

```swift
        /// Whether income owned by `owner` is eligible under the state's
        /// attribution rule. Under `.household` every row is eligible when any
        /// spouse qualifies, which is what `effectiveAge` already encodes.
        func ownerQualifies(_ owner: Owner) -> Bool {
            guard exemptions.exemptionAttribution == .perQualifyingSpouse, enableSpouse else {
                return true
            }
            switch owner {
            case .primary: return ageQualifiesForExemption(primaryAge)
            case .spouse:  return ageQualifiesForExemption(spouseAge)
            case .joint:   return ageQualifiesForExemption(primaryAge)
                                || ageQualifiesForExemption(spouseAge)
            }
        }

        let pensionIncome = incomeSources
            .filter { $0.type == .pension && ownerQualifies($0.owner) }
            .reduce(0) { $0 + $1.annualAmount }
        let rmdSourceIncome = incomeSources
            .filter { $0.type == .rmd && ownerQualifies($0.owner) }
            .reduce(0) { $0 + $1.annualAmount }
```

and the scalar's gate:

```swift
        // Under `.perQualifyingSpouse` the scalar has no owner to attribute it
        // to, so it is gated on the primary. See ExemptionAttribution.
        let retirementAge: Bool
        switch exemptions.exemptionAttribution {
        case .household:
            retirementAge = primaryAge >= exemptions.distributionMinAge
                || (enableSpouse && spouseAge >= exemptions.distributionMinAge)
        case .perQualifyingSpouse:
            retirementAge = primaryAge >= exemptions.distributionMinAge
        }
```

**Placement.** On `main` @ `e540e9f` the nested `ageQualifiesForExemption` is declared around line 531, `pensionIncome` around 571 and `rmdSourceIncome` around 582, so `ownerQualifies` slots in between with nothing to move. Verify those positions before editing rather than trusting these numbers: earlier tasks in this phase touch the same function and will have shifted them.

`.rmd` rows keep their existing ungated treatment under `.household`, which is every state's setting in this phase. Do not take the opportunity to gate them: the divergence where an ungated `.rmd` row and a 59-gated scalar disagree is a real finding from Phase 2 and it is pinned by the baseline scenario "single 55 rmd rows not scenario distributions". Closing it here would be an unattributed behavior change.

- [ ] **Step 5: Codable**

`ExemptionAttribution` is a `String`-backed enum, so its conformance is synthesized. Add `exemptionAttribution` to `RetirementIncomeExemptions`'s `CodingKeys`, `try c.encode(exemptionAttribution, forKey: .exemptionAttribution)` to `encode(to:)`, and to `init(from:)`:

```swift
            exemptionAttribution: try c.decodeIfPresent(
                ExemptionAttribution.self, forKey: .exemptionAttribution) ?? .household,
```

- [ ] **Step 6: Run the mechanism tests and the baseline, then the full suite**

The baseline scenarios "MFJ 57 with spouse 61" and "MFJ 61 with spouse 56" are the ones that catch an accidental attribution change here. Confirm they pass, then run the full suite tee'd to `/tmp/phase3a-task5.log`, paste both summary lines, confirm the tree.

- [ ] **Step 7: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "feat(state-tax): per-qualifying-spouse attribution mode, every state still household"
```

---

### Task 6: Data-driven Roth conversion exemption

Spec §3.3b. `TaxCalculationEngine.swift:687-695` is a hardcoded `switch state` over PA, IL and MS. Iowa belongs in it and would be the first age-gated member, which a `switch` cannot express.

**Files:**
- Create: `RetireSmartIRA/StateRothConversionExemption.swift`
- Modify: `RetireSmartIRA/StateTaxData.swift` (field, plus PA, IL and MS configs)
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRA/TaxCalculationEngine.swift` (delete the `switch state`)
- Test: `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`

**Interfaces:**
- Produces: `RothConversionExemption` and `RetirementIncomeExemptions.rothConversionExemption: RothConversionExemption?` (default `nil`, meaning conversion income is taxable, which is 48 jurisdictions' behavior).

- [ ] **Step 1: Write the failing test**

```swift
    // MARK: - Roth conversion exemption

    @Test("Pennsylvania still exempts only the net amount deposited into the Roth")
    func pennsylvaniaExemptsNetOfWithholdingViaConfig() {
        func tax(withholding: Double) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: 100_000, forState: .pennsylvania, filingStatus: .single,
                taxableSocialSecurity: 0, incomeSources: [], currentAge: 62,
                enableSpouse: false, spouseBirthYear: 1964, currentYear: 2026,
                scenarioRothConversionAmount: 100_000,
                scenarioRothConversionWithholdingAmount: withholding)
        }
        // PA rate 3.07%. Full conversion exempt when nothing is withheld.
        #expect(tax(withholding: 0) == 0)
        // $22,000 withheld stays PA-taxable: 22,000 x 0.0307 = 675.40.
        #expect(abs(tax(withholding: 22_000) - 675.40) < 0.005)
    }

    @Test("Illinois and Mississippi exempt the gross conversion regardless of withholding")
    func illinoisAndMississippiExemptGrossViaConfig() {
        for state in [USState.illinois, USState.mississippi] {
            let taxed = TaxCalculationEngine.calculateStateTax(
                income: 100_000, forState: state, filingStatus: .single,
                taxableSocialSecurity: 0, incomeSources: [], currentAge: 62,
                enableSpouse: false, spouseBirthYear: 1964, currentYear: 2026,
                scenarioRothConversionAmount: 100_000,
                scenarioRothConversionWithholdingAmount: 22_000)
            #expect(taxed == 0, "\(state.abbreviation) should exempt the gross conversion")
        }
    }

    @Test("A conversion exemption can be age-gated, which the hardcoded switch could not express")
    func rothConversionExemptionCanBeAgeGated() {
        let config = Self.flatTenPercent(exemptions: RetirementIncomeExemptions(
            socialSecurityExempt: true,
            rothConversionExemption: RothConversionExemption(
                minAge: 55, withheldPortionRemainsTaxable: false)))

        func tax(age: Int) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: 100_000, forState: .iowa, filingStatus: .single,
                taxableSocialSecurity: 0, incomeSources: [], currentAge: age,
                enableSpouse: false, spouseBirthYear: 2026 - age, currentYear: 2026,
                scenarioRothConversionAmount: 100_000,
                configOverride: config)
        }
        #expect(tax(age: 54) == 10_000)   // below the gate, fully taxed
        #expect(tax(age: 55) == 0)        // at the gate, exempt
    }

    @Test("Exactly PA, IL and MS carry a conversion exemption in Phase 3a")
    func onlyThreeStatesCarryAConversionExemption() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        let withExemption = USState.allCases.filter {
            configs[$0]?.retirementExemptions.rothConversionExemption != nil
        }
        #expect(Set(withExemption) == Set([.pennsylvania, .illinois, .mississippi]),
                "Phase 3a moves the existing PA/IL/MS rule into config and adds no state. \
                Iowa is Phase 5a. Found: \(withExemption.map(\.abbreviation).sorted())")
        // PA is the only one whose withheld portion stays taxable.
        #expect(configs[.pennsylvania]?.retirementExemptions
            .rothConversionExemption?.withheldPortionRemainsTaxable == true)
        #expect(configs[.illinois]?.retirementExemptions
            .rothConversionExemption?.withheldPortionRemainsTaxable == false)
        // No state is age-gated yet, so a stray default of 59 would be visible.
        for state in withExemption {
            #expect(configs[state]?.retirementExemptions
                .rothConversionExemption?.minAge == 0)
        }
    }
```

- [ ] **Step 2: Run it, watch it fail**

Expected: `cannot find 'RothConversionExemption' in scope`. Paste it.

- [ ] **Step 3: Create the type**

Create `RetireSmartIRA/StateRothConversionExemption.swift`:

```swift
import Foundation

/// A state's treatment of Roth conversion income in the conversion year.
///
/// Before Phase 3a this was a `switch state` over Pennsylvania, Illinois and
/// Mississippi inside `TaxCalculationEngine.applyRetirementExemptions`. Iowa
/// exempts conversion income by name for anyone 55 or older (HF 2317), which a
/// `switch` with no age concept could not express, and which matters more than
/// any other single defect in the 2026-08-02 audit: this app exists to
/// optimize Roth conversions, and for an Iowa user it currently invents state
/// tax on that exact transaction.
///
/// nil, the default, means conversion income is fully taxable. That is the
/// correct treatment for 48 jurisdictions.
struct RothConversionExemption: Codable, Equatable, Sendable {
    /// Minimum age for the exemption. 0 means no age gate, which is Ans 274's
    /// position for Pennsylvania and the practitioner reading for Illinois and
    /// Mississippi: none of the three conditions the exemption on retirement
    /// age. Iowa will be 55.
    let minAge: Int

    /// Pennsylvania DOR Ans 274 holds the exemption applies only where the full
    /// pre-tax balance reaches the Roth, so any amount withheld for federal tax
    /// is a taxable distribution. Illinois and Mississippi publish no
    /// equivalent condition, so they exempt the gross.
    let withheldPortionRemainsTaxable: Bool
}
```

- [ ] **Step 4: Add the field and configure the three states**

In `RetirementIncomeExemptions`, after `agiPhaseout`:

```swift
    /// How the state treats Roth conversion income in the conversion year.
    /// nil (the default) means fully taxable.
    var rothConversionExemption: RothConversionExemption? = nil
```

In `StateTaxData.swift`, `configs[.pennsylvania]`'s `RetirementIncomeExemptions`:

```swift
                // PA DOR Ans 274: a trustee-to-trustee conversion is not a
                // taxable event, but only the portion actually deposited into
                // the Roth qualifies, so federal withholding taken from the
                // conversion stays PA-taxable. Lift-and-shift of the switch
                // this replaces, not a Phase 3a correction.
                rothConversionExemption: RothConversionExemption(
                    minAge: 0, withheldPortionRemainsTaxable: true),
```

and in `configs[.illinois]` and `configs[.mississippi]`:

```swift
                // IL Pub 120 / MS Code 27-7-15(4)(j) per practitioner
                // consensus: the conversion is exempt, with no documented
                // full-balance condition, so withholding does not reduce it.
                rothConversionExemption: RothConversionExemption(
                    minAge: 0, withheldPortionRemainsTaxable: false),
```

- [ ] **Step 5: Replace the `switch state` in the engine**

Delete the entire `switch state { case .pennsylvania: ... case .illinois, .mississippi: ... default: break }` block and its now-stale explanatory comment, and put in its place:

```swift
        // Roth conversion treatment, config-driven since Phase 3a. The rule
        // and the Ans 274 withholding caveat that used to live in a
        // `switch state` here now live on each state's config; see
        // RothConversionExemption for the citations.
        if let conversionRule = exemptions.rothConversionExemption {
            let qualifies = conversionRule.minAge == 0
                || effectiveAge >= conversionRule.minAge
            if qualifies {
                let exemptAmount = conversionRule.withheldPortionRemainsTaxable
                    ? max(0, scenarioRothConversionAmount - scenarioRothConversionWithholdingAmount)
                    : scenarioRothConversionAmount
                adjusted -= exemptAmount
            }
        }
```

`effectiveAge` is already in scope and is `max(primaryAge, spouseAge)` when a spouse is enabled. Since no state is age-gated in Phase 3a the branch is unreachable, and Iowa's Phase 4 golden scenario decides whether that is the right age for a conversion under `.perQualifyingSpouse`.

- [ ] **Step 6: Codable and round-trip**

Add `rothConversionExemption` to `CodingKeys`, `encodeIfPresent` to `encode(to:)`, `decodeIfPresent` to `init(from:)`. Add to `StateTaxCodableRoundTripTests.swift`:

```swift
    @Test("RothConversionExemption round-trips both variants with distinct values")
    func rothConversionExemptionRoundTrips() throws {
        // minAge non-zero in one case and the Bool differing between them, so
        // neither field can be dropped without a test noticing.
        let cases = [
            RothConversionExemption(minAge: 0, withheldPortionRemainsTaxable: true),
            RothConversionExemption(minAge: 55, withheldPortionRemainsTaxable: false)
        ]
        for original in cases {
            let decoded = try JSONDecoder().decode(
                RothConversionExemption.self, from: JSONEncoder().encode(original))
            #expect(decoded == original)
        }
    }
```

- [ ] **Step 7: Run the mechanism tests, the baseline, the PA and conversion suites**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests -only-testing:RetireSmartIRATests/StateRetirementExemptionTests 2>&1 | tail -25
```

The baseline's three conversion scenarios are the inertness proof for this task, and they include the withholding case specifically so a PA regression to gross-exemption is visible.

- [ ] **Step 8: Full suite, then commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "feat(state-tax): move the Roth conversion rule from a switch statement into config"
```

---

### Task 7: Prove the new fields cannot be silently dropped by the encoder

Phase 1 found five separate fields that could have vanished without moving any computed value. Four of them shared one root cause: **asserting on round-tripped values rather than on the encoded representation.** This task applies the control that closed them to the five fields added in Tasks 2 to 6.

**Files:**
- Modify: `RetireSmartIRATests/StateTaxCodableRoundTripTests.swift`

- [ ] **Step 1: Write the failing JSON-shape test**

Read `retirementExemptionsEncodesExpectedJSONShape` and `stateTaxConfigEncodesExpectedJSONShape` first and extend them in the same style rather than adding a parallel mechanism.

```swift
    @Test("Phase 3a's new keys appear in encoded RetirementIncomeExemptions JSON")
    func phase3aKeysSurviveEncoding() throws {
        // Every value differs from its own default, so a dropped encode line
        // cannot be masked by decodeIfPresent falling back to the same value.
        let exemptions = RetirementIncomeExemptions(
            socialSecurityExempt: false,
            distributionMinAge: 55,
            exemptionAttribution: .perQualifyingSpouse,
            agiPhaseout: AGIPhaseout(thresholdSingle: 50_000, thresholdMFJ: 75_000,
                                     shape: .linear(perDollar: 1.0)),
            rothConversionExemption: RothConversionExemption(
                minAge: 55, withheldPortionRemainsTaxable: true))

        let data = try JSONEncoder().encode(exemptions)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["distributionMinAge"] as? Int == 55)
        #expect(object["exemptionAttribution"] as? String == "perQualifyingSpouse")

        let phaseout = try #require(object["agiPhaseout"] as? [String: Any])
        #expect(phaseout["thresholdSingle"] as? Double == 50_000)
        #expect(phaseout["thresholdMFJ"] as? Double == 75_000)
        #expect((phaseout["shape"] as? [String: Any])?["kind"] as? String == "linear")

        let conversion = try #require(object["rothConversionExemption"] as? [String: Any])
        #expect(conversion["minAge"] as? Int == 55)
        #expect(conversion["withheldPortionRemainsTaxable"] as? Bool == true)
    }

    @Test("personalExemption appears in encoded StateTaxConfig JSON when present, and is absent when nil")
    func personalExemptionEncodingIsConditional() throws {
        let withExemption = StateTaxConfig(
            state: .newJersey, taxSystem: .flat(rate: 0.05),
            retirementExemptions: RetirementIncomeExemptions(),
            stateDeduction: .none,
            personalExemption: StatePersonalExemption(
                single: 1_000, marriedFilingJointly: 2_000,
                seniorAdditionalPerFiler: 1_000, seniorAge: 65))
        let present = try #require(try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(withExemption)) as? [String: Any])
        let exemption = try #require(present["personalExemption"] as? [String: Any])
        // All four values distinct, so no two fields can be swapped undetected.
        #expect(exemption["single"] as? Double == 1_000)
        #expect(exemption["marriedFilingJointly"] as? Double == 2_000)
        #expect(exemption["seniorAdditionalPerFiler"] as? Double == 1_000)
        #expect(exemption["seniorAge"] as? Int == 65)

        let without = StateTaxConfig(
            state: .kansas, taxSystem: .flat(rate: 0.05),
            retirementExemptions: RetirementIncomeExemptions(),
            stateDeduction: .none)
        let absent = try #require(try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(without)) as? [String: Any])
        #expect(absent["personalExemption"] == nil,
                "a nil personal exemption must omit the key, not write null, \
                so 50 files stay free of a key they do not need")
    }
```

`single: 1_000` and `seniorAdditionalPerFiler: 1_000` are the same value, so those two specifically cannot be told apart by this test alone. That is acceptable only because a swap between them is caught behaviorally by `personalExemptionSeniorIsPerFiler` in Task 3, which asserts 3,000 for a household where one spouse is 66 and the other 60. State that reasoning in the report rather than leaving it implicit.

- [ ] **Step 2: Run and confirm it passes** (the encode lines were written in Tasks 2 to 6)

If any assertion fails, the corresponding `encode` line is missing. Fix the encoder, not the test.

- [ ] **Step 3: Prove each assertion discriminates, by deleting encode lines**

For each of `distributionMinAge`, `exemptionAttribution`, `agiPhaseout`, `rothConversionExemption` and `personalExemption`: comment out its line in `encode(to:)`, run this suite, confirm a named failure, restore it. Five mutations, five transcripts. Report which you actually ran; do not reconstruct plausible output for any you skipped.

- [ ] **Step 4: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "test(state-tax): JSON-shape assertions for every Phase 3a field"
```

---

### Task 8: Layer C required-vs-optional keys, and regenerate the 51 files

`personalExemption` is the first optional top-level key, so `StateTaxJSONFileKeyCompletenessTests` cannot keep asserting one exact set for all 51 files.

**Files:**
- Modify: `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift:599-641`

- [ ] **Step 1: Write the new assertion**

Replace `expectedTopLevelKeys` and the test body:

```swift
    /// Keys every shipped file must carry.
    private static let requiredTopLevelKeys: Set<String> = [
        "state", "taxSystem", "retirementExemptions", "stateDeduction",
        "estimatedPaymentSchedule", "safeHarborRule", "currentYearSafeHarborRate",
        "hsaContributionsTaxableForState", "traditionalIRAContributionsTaxableForState",
        "otherPreTaxDeductionsTaxableForState", "pretax401kContributionsTaxableForState",
        "capitalLossesClassIsolated", "verification"
    ]

    /// Keys a file MAY carry. `personalExemption` is written only for states
    /// that grant one, which is New Jersey alone in Phase 3a, so requiring it
    /// everywhere would force 50 files to carry a key with no meaning. A key
    /// outside both sets is still a failure: this widens the assertion by
    /// exactly one name, it does not weaken it into an allow-anything check.
    private static let optionalTopLevelKeys: Set<String> = ["personalExemption"]

    @Test("Each bundled JSON file carries every required top-level key and no unknown ones",
          arguments: USState.allCases)
    func topLevelKeysAreCompleteAndKnown(state: USState) throws {
        let url = try StateTaxDataLoader.fileURL(for: state, taxYear: 2026)
        let data = try Data(contentsOf: url)
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let object = raw as? [String: Any] else {
            Issue.record("\(state.abbreviation): top-level JSON at \(url.lastPathComponent) is not an object")
            return
        }

        let actualKeys = Set(object.keys)
        let missing = Self.requiredTopLevelKeys.subtracting(actualKeys).sorted()
        let unknown = actualKeys
            .subtracting(Self.requiredTopLevelKeys)
            .subtracting(Self.optionalTopLevelKeys).sorted()

        #expect(missing.isEmpty,
                "\(state.abbreviation) (\(url.lastPathComponent)) is missing required keys: \(missing)")
        #expect(unknown.isEmpty,
                "\(state.abbreviation) (\(url.lastPathComponent)) carries unknown keys: \(unknown)")
    }

    @Test("Exactly one jurisdiction ships a personalExemption key in Phase 3a")
    func onlyNewJerseyShipsAPersonalExemptionKey() throws {
        var carriers: [String] = []
        for state in USState.allCases {
            let url = try StateTaxDataLoader.fileURL(for: state, taxYear: 2026)
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: url)) as? [String: Any]
            if object?["personalExemption"] != nil { carriers.append(state.abbreviation) }
        }
        #expect(carriers == ["NJ"],
                "Phase 3a ships New Jersey's personal exemption only. Found: \(carriers)")
    }
```

The second test is what keeps the first from having weakened anything: making a key optional would otherwise let a whole state's exemption vanish from the shipped data unnoticed.

- [ ] **Step 2: Run it and confirm exactly one failure**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONFileKeyCompletenessTests 2>&1 | tail -25
```

Expected: `topLevelKeysAreCompleteAndKnown` PASSES for all 51 (no file has an unknown key yet), and `onlyNewJerseyShipsAPersonalExemptionKey` FAILS with `Found: []`, because the files still carry the pre-Phase-3a schema. That failure is the reason the regeneration lives in this same task rather than a later one: splitting them would commit a knowingly-red suite.

Do not weaken the assertion to make it green. Regenerate in Step 3.

**Steps 3 to 6 regenerate the 51 files.** The shipped data should carry the Phase 3a schema at inert values, so Phase 5 becomes a value edit inside an existing key rather than a key addition, and so Phase 6's disclosure view has something to read.

Files touched: `RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-*.json`, all 51, generated and never hand-edited.

- [ ] **Step 3: Regenerate**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && TEST_RUNNER_STATE_TAX_GENERATE=1 xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxDataGeneratorTests ENABLE_APP_SANDBOX=NO 2>&1 | tail -20
```

- [ ] **Step 4: Read the diff before trusting it**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git diff --stat RetireSmartIRA/Resources/StateTaxData/2026/ && git diff RetireSmartIRA/Resources/StateTaxData/2026/statetax-2026-KS.json
```

Expected in Kansas and in 49 others: exactly two added lines, `"distributionMinAge" : 59` and `"exemptionAttribution" : "household"`, inside `retirementExemptions`. Nothing removed, no value changed.

Expected in New Jersey: those two lines plus a `personalExemption` object.
Expected in Pennsylvania, Illinois and Mississippi: those two lines plus a `rothConversionExemption` object.

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git diff --numstat RetireSmartIRA/Resources/StateTaxData/2026/ | awk '$2 != 0 {print "DELETION in " $3}'
```

Expected: no output. **Any deleted line in any file is a defect, not a formatting artifact.** Stop and report if one appears.

- [ ] **Step 5: Prove regeneration is deterministic**

Run Step 3 again and confirm `git status` shows no further change. Phase 1 hit this exact problem: `TaxBracket.id` was a fresh UUID per process and rewrote 285 lines of noise on every regeneration, which was fixed by excluding `id` from its `CodingKeys`. Confirm that fix still holds rather than assuming it.

- [ ] **Step 6: Run the Phase 1 gate, Layer C, and the behavior baseline**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONEquivalenceTests -only-testing:RetireSmartIRATests/StateTaxJSONStructuralEquivalenceTests -only-testing:RetireSmartIRATests/StateTaxJSONFileKeyCompletenessTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests 2>&1 | tail -30
```

Expected: all PASS, including `onlyNewJerseyShipsAPersonalExemptionKey`, which was red at Step 2.

- [ ] **Step 7: Commit, as one commit covering both halves**

The Layer C change and the regeneration ship together so the suite is never red at a commit boundary.

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "test(state-tax): Layer C required-vs-optional keys, and regenerate the 51 files"
```

---

### Task 9: The Phase 3a gate

- [ ] **Step 1: Full macOS suite**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/phase3a-gate.log | tail -50
```

Required: 0 failures. Confirm the tree with `grep -c "worktrees/state-tax-phase3a" /tmp/phase3a-gate.log` before reading any count. Paste both the Swift Testing and the XCTest summary lines.

- [ ] **Step 2: iOS build, and confirm the JSON is bundled**

Phase 1 caught that nobody had verified iOS bundling; a universal binary with an unbundled resource throws on every iPhone launch while every Mac test stays green.

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild build -scheme RetireSmartIRA -destination 'generic/platform=iOS' 2>&1 | tail -20
```

Then locate the built `.app` and count the bundled files:

```bash
find ~/Library/Developer/Xcode/DerivedData -name "RetireSmartIRA.app" -path "*iphoneos*" -newermt '-30 minutes' -exec sh -c 'ls "$1" | grep -c "^statetax-2026-"' _ {} \;
```

Expected: `51`.

- [ ] **Step 3: Confirm the four things this phase promised not to touch**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git diff main --stat -- RetireSmartIRA.xcodeproj/project.pbxproj && git diff main -- RetireSmartIRA/ProjectionEngine.swift | head -5 && git grep -n "—" -- '*.swift' '*.json' | head -5
```

Expected: no pbxproj change, no `ProjectionEngine.swift` change (I2 stays open), no em dash in any Swift or JSON file.

And confirm the pinned cross-path divergence still reads exactly as Phase 2 left it:

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git diff main -- RetireSmartIRATests/GoldenScenarioCrossPathTests.swift
```

Expected: empty.

- [ ] **Step 4: Write the ledger and request the whole-branch review**

Append the phase's outcome to `.claude/memory/roadmap/2026-08-03-state-tax-phase3a-ledger.md`, then use `superpowers:requesting-code-review` for a whole-branch review before merging. The review should hunt specifically for the shape that bit this repo on the V2.3 branch and was hunted for again in Phase 1: a renamed or added coding key orphaning a decoder elsewhere, with every per-task review passing. The candidate here is `RetirementIncomeExemptions`, which is decoded from bundled JSON but is also reachable through `PersistenceManager` if any user-editable path persists a `StateTaxConfig`. Verify that rather than assuming it.

---

## Self-Review

**Spec coverage.** §3.3a state-aware minimum age is Task 2. §3.3b data-driven Roth conversion rule is Task 6. §3.3d AGI phase-out is Task 4. §3.3e per-individual attribution and age gates is Task 5, with the observation that `exemptionAppliesPerIndividual` and `regularExemptionMinAge` already exist as fields, so the gap was attribution rather than the fields themselves. §3.1 `personalExemption` is Task 3. §3.3c per-source exemptions is deliberately deferred to Phase 3b and is called out at the top. §4a's Phase 3 gate, "the Phase 1 equivalence test still passes, suite green," is Task 9, strengthened by Task 1 because the Phase 1 gate alone is structurally blind to this phase's failure mode.

**Type consistency.** `distributionMinAge` (Int), `exemptionAttribution` (`ExemptionAttribution`), `agiPhaseout` (`AGIPhaseout?`), `rothConversionExemption` (`RothConversionExemption?`) all live on `RetirementIncomeExemptions`; `personalExemption` (`StatePersonalExemption?`) lives on `StateTaxConfig`, because it applies after the retirement exclusions rather than as part of them. `AGIPhaseout.reduced(exclusion:totalGrossIncome:isMarried:)` and `StatePersonalExemption.amount(filingStatus:enableSpouse:primaryAge:spouseAge:)` are each named identically in their defining task and every consuming task.

**Known soft spots, stated rather than hidden.**
1. Task 5 chooses a convention for attributing an ownerless scalar. It is unreachable in Phase 3a and Iowa's Phase 4 golden scenario is the first thing that can confirm it.
2. Task 4 uses total gross income as the phase-out basis, matching New Jersey's existing mechanism. Virginia's statute uses a different figure. Nothing depends on the choice yet and the type's doc comment says so.
3. Task 7's `personalExemption` shape test cannot distinguish `single` from `seniorAdditionalPerFiler`, both 1,000. Task 3's behavioral test covers the swap.
