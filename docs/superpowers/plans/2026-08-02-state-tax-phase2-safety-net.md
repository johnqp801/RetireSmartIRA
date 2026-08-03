# State Tax Phase 2: Safety Net and Golden-Scenario Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the machinery that will let Phase 4 assert every jurisdiction's tax against its own published form, and prove that machinery works on a pilot set before 51 states depend on it.

**Architecture:** Golden scenarios are JSON fixtures carrying inputs, an expected state tax derived from the state's published form, and a citation naming the form and lines used. A runner drives each scenario through BOTH the single-year path (`TaxCalculationEngine.calculateStateTax`) and the multi-year path (`ProjectionEngine.project`), asserting each against the expected figure and against each other. Configs also become tax-year-keyed, and extrapolating past the last bundled year becomes an observable fact rather than a silent assumption.

**Tech Stack:** Swift 5.9+, Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), Foundation `JSONDecoder`, Xcode scheme `RetireSmartIRA`.

## Global Constraints

- Platform target: native macOS (NOT Catalyst) + iOS/iPadOS, universal binary, iOS 18 / macOS 15.
- **Explicit `cd` into the worktree in EVERY command.** The shell's working directory silently resets to the main repo on an unrelated branch. This bit five agents and the controller during Phase 1, once causing a stray `rm` in the wrong repo.
- **Run xcodebuild in the FOREGROUND and read your own log.** Subagents receive no completion notification; backgrounding and waiting is an infinite stall. Six agents lost a turn to this in Phase 1.
  `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2 && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:<suite> > .scratch/<name>.log 2>&1; echo "EXIT=$?"`
  Then confirm the tree: `grep -m1 -oE "/Users/johnurban/Projects/RetireSmartIRA[^ ]*\.xcodeproj" .scratch/<name>.log` MUST contain `.worktrees/state-tax-phase2`. Direct `/tmp` writes are denied; use `.scratch/` inside the worktree and delete it before committing.
- **Run only scoped tests.** The controller runs the full suite. Baseline is **1,605 Swift Testing in 271 suites + 503 XCTest, 0 failures**.
- **No em dash characters** in any code, comment, string, or commit message. Hard project rule.
- Swift Testing for new tests, not XCTest.
- Do NOT modify `RetireSmartIRA.xcodeproj`. Both `RetireSmartIRA/` and `RetireSmartIRATests/` are `PBXFileSystemSynchronizedRootGroup`, so new files join their target automatically. If you want to edit `project.pbxproj`, report BLOCKED.
- **Phase 2 corrects NO tax value and changes NO computed number.** Corrections are Phase 5. Any moved number is a defect in this phase.
- Scope searches to `RetireSmartIRA/` and `RetireSmartIRATests/`.
- Golden scenarios must be DETERMINISTIC: always pin `baseYear`, never let a projection depend on the current calendar date.

## Context you need

Phase 1 (merged, 23 commits) moved 51 jurisdictions' configs into bundled JSON named `statetax-2026-<ABBR>.json`, loaded by `StateTaxDataLoader`, with a three-layer gate proving the migration changed nothing.

**Two cross-path divergences are already known and documented** in `.claude/memory/roadmap/2026-08-02-cross-path-state-tax-divergences.md`. Both paths call the same `TaxCalculationEngine.calculateStateTax`; they differ in what they pass:

1. **Backlog I2.** `ProjectionEngine.computeStateTax` (`ProjectionEngine.swift:1622-1634`) omits `postExemptionDeduction`, which defaults to 0. `DataManager` passes it. New Jersey's per-filer personal exemptions vanish in Multi-Year.
2. **Age-gating asymmetry.** `TaxCalculationEngine.swift:582-585` adds `.rmd`-typed `IncomeSource` rows UNGATED but gates `scenarioRetirementDistributions` at 59.5. Multi-year synthesizes `.rmd` rows (`ProjectionEngine.swift:1608-1612`); single-year passes `scenarioRetirementDistributions`. So a 55-year-old with IRA withdrawals gets the state IRA exemption in Multi-Year and is denied it in Scenarios.

**These are NOT to be fixed in Phase 2.** Phase 2 makes them visible and pinned. Fixing them changes computed numbers, which is Phase 5.

## File Structure

**Create:**
- `RetireSmartIRA/StateTaxYearAvailability.swift` — which tax years are bundled, and whether a given year is extrapolated. One job: answer "do we have real law for this year".
- `RetireSmartIRATests/GoldenScenario.swift` — the fixture type and its loader. One job: decode golden fixtures.
- `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift` — runs each scenario through the single-year path.
- `RetireSmartIRATests/GoldenScenarioMultiYearTests.swift` — runs each scenario through the multi-year path.
- `RetireSmartIRATests/GoldenScenarioCrossPathTests.swift` — asserts the two paths agree, with known divergences pinned.
- `RetireSmartIRATests/GoldenScenarios/statetax-2026-<ABBR>.golden.json` — pilot fixtures for PA, IL, MS, CA, NJ.

**Modify:**
- `RetireSmartIRA/StateTaxDataLoader.swift` — add year-keyed `configs(for:)`.
- `RetireSmartIRA/StateTaxData.swift` — add `config(for:taxYear:)`.

---

### Task 1: Year-keyed config access

**Files:**
- Modify: `RetireSmartIRA/StateTaxDataLoader.swift`
- Modify: `RetireSmartIRA/StateTaxData.swift`
- Test: `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`

**Interfaces:**
- Consumes: `StateTaxDataLoader.load(taxYear:)`, already present from Phase 1.
- Produces: `StateTaxDataLoader.configs(for taxYear: Int) -> [USState: StateTaxConfig]` (memoized per year) and `StateTaxData.config(for state: USState, taxYear: Int) -> StateTaxConfig`. Task 5 uses the latter.

Today `StateTaxDataLoader.configs2026` is a single memoized static and `StateTaxData.config(for:)` hardcodes it. Adding 2027 later must be additive.

- [ ] **Step 1: Write the failing test**

Append to `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`, inside `StateTaxJSONLoaderTests`:

```swift
    @Test("Year-keyed access returns the same configs as the 2026 accessor")
    func yearKeyedAccessMatches2026() throws {
        let byYear = StateTaxDataLoader.configs(for: 2026)
        #expect(byYear.count == 51)
        for state in USState.allCases {
            #expect(byYear[state]?.state == state, "\(state.abbreviation) mismatched")
        }
        // The memoized 2026 accessor and the year-keyed one must agree exactly.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for state in USState.allCases {
            let a = try encoder.encode(byYear[state])
            let b = try encoder.encode(StateTaxDataLoader.configs2026[state])
            #expect(a == b, "\(state.abbreviation) differs between accessors")
        }
    }

    @Test("Year-keyed access returns empty for a year with no bundled data")
    func yearKeyedAccessEmptyForUnknownYear() {
        #expect(StateTaxDataLoader.configs(for: 1999).isEmpty)
    }

    @Test("StateTaxData.config(for:taxYear:) resolves every state to itself")
    func stateTaxDataYearKeyedResolvesSelf() {
        for state in USState.allCases {
            #expect(StateTaxData.config(for: state, taxYear: 2026).state == state)
        }
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2 && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONLoaderTests > .scratch/t1.log 2>&1; echo "EXIT=$?"`
Expected: FAIL to compile, "type 'StateTaxDataLoader' has no member 'configs'".

- [ ] **Step 3: Write minimal implementation**

In `RetireSmartIRA/StateTaxDataLoader.swift`, add inside the enum, next to the existing `configs2026`:

```swift
    /// Per-tax-year memoized cache. Adding a future tax year is additive: drop
    /// its `statetax-<year>-<ABBR>.json` files into the bundle and this resolves
    /// them with no code change.
    ///
    /// Returns an EMPTY dictionary rather than throwing when a year has no
    /// bundled data. Callers decide what that means: `StateTaxYearAvailability`
    /// treats it as "law not available for this year", which is a disclosure
    /// concern, not a load failure.
    private static let yearCache = YearCache()

    private final class YearCache: @unchecked Sendable {
        private var storage: [Int: [USState: StateTaxConfig]] = [:]
        private let lock = NSLock()

        func configs(for taxYear: Int) -> [USState: StateTaxConfig] {
            lock.lock()
            defer { lock.unlock() }
            if let cached = storage[taxYear] { return cached }
            let loaded = (try? StateTaxDataLoader.load(taxYear: taxYear)) ?? [:]
            storage[taxYear] = loaded
            return loaded
        }
    }

    /// Configurations for `taxYear`, or an empty dictionary if none are bundled.
    static func configs(for taxYear: Int) -> [USState: StateTaxConfig] {
        yearCache.configs(for: taxYear)
    }
```

In `RetireSmartIRA/StateTaxData.swift`, add immediately after the existing `config(for:)`:

```swift
    /// Returns the configuration for `state` in `taxYear`.
    ///
    /// Falls back to the 2026 table when `taxYear` has no bundled data, because
    /// projections routinely run decades past the last year real law exists for.
    /// That extrapolation is DISCLOSED rather than silent: see
    /// `StateTaxYearAvailability.isExtrapolated(taxYear:)`.
    static func config(for state: USState, taxYear: Int) -> StateTaxConfig {
        if let config = StateTaxDataLoader.configs(for: taxYear)[state] {
            return config
        }
        return config(for: state)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run the Step 2 command again.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2
git add RetireSmartIRA/StateTaxDataLoader.swift RetireSmartIRA/StateTaxData.swift RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift
git commit -m "feat(state-tax): add tax-year-keyed config access"
```

---

### Task 2: Make constant-law extrapolation observable

**Files:**
- Create: `RetireSmartIRA/StateTaxYearAvailability.swift`
- Test: `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`

**Interfaces:**
- Consumes: `StateTaxDataLoader.configs(for:)` from Task 1.
- Produces: `StateTaxYearAvailability.latestBundledTaxYear: Int`, `.isExtrapolated(taxYear:) -> Bool`, `.disclosure(forProjectionYear:) -> String?`. Phase 6 renders the string; Phase 2 only makes the fact available and tested.

The app projects decades forward on one year's rules and says so nowhere. This makes the assumption inspectable.

- [ ] **Step 1: Write the failing test**

Append to `RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift`, inside `StateTaxJSONLoaderTests`:

```swift
    @Test("Latest bundled tax year is 2026")
    func latestBundledYearIs2026() {
        #expect(StateTaxYearAvailability.latestBundledTaxYear == 2026)
    }

    @Test("Years at or before the latest bundled year are not extrapolated")
    func bundledYearsNotExtrapolated() {
        #expect(StateTaxYearAvailability.isExtrapolated(taxYear: 2026) == false)
        #expect(StateTaxYearAvailability.disclosure(forProjectionYear: 2026) == nil)
    }

    @Test("Years past the latest bundled year are disclosed as extrapolated")
    func futureYearsDisclosed() throws {
        #expect(StateTaxYearAvailability.isExtrapolated(taxYear: 2044) == true)
        let text = try #require(StateTaxYearAvailability.disclosure(forProjectionYear: 2044))
        #expect(text.contains("2026"), "the disclosure must name the year whose law is held constant")
        #expect(text.contains("2044"), "the disclosure must name the year being projected")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2 && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxJSONLoaderTests > .scratch/t2.log 2>&1; echo "EXIT=$?"`
Expected: FAIL to compile, "cannot find 'StateTaxYearAvailability' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `RetireSmartIRA/StateTaxYearAvailability.swift`:

```swift
import Foundation

/// Answers whether the app has real state tax law for a given year, or is
/// holding the newest year it has constant.
///
/// A multi-year plan routinely projects thirty years forward while only one
/// year of state law exists in the bundle. That is a defensible modeling
/// choice, but before this type it was an undisclosed one: nothing in the app
/// distinguished a 2026 figure computed from 2026 law from a 2044 figure
/// computed from the same 2026 law.
enum StateTaxYearAvailability {

    /// Candidate years to probe. Bundled data starts at 2026; the upper bound
    /// is deliberately generous so adding a future year needs no code change.
    private static let probeRange = 2020...2100

    /// The newest tax year with bundled configuration.
    static let latestBundledTaxYear: Int = {
        probeRange.last { !StateTaxDataLoader.configs(for: $0).isEmpty } ?? 2026
    }()

    /// True when `taxYear` has no bundled law and the newest available year is
    /// being held constant for it.
    static func isExtrapolated(taxYear: Int) -> Bool {
        taxYear > latestBundledTaxYear
    }

    /// A plain sentence for a projection year, or nil when real law exists.
    /// Phase 6 renders this; nothing consumes it yet.
    static func disclosure(forProjectionYear year: Int) -> String? {
        guard isExtrapolated(taxYear: year) else { return nil }
        return "State tax for \(year) assumes \(latestBundledTaxYear) law held constant. "
            + "Legislatures change rates, brackets and exemptions every year, so figures "
            + "beyond \(latestBundledTaxYear) are a projection of today's law, not a forecast of future law."
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the Step 2 command again.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2
git add RetireSmartIRA/StateTaxYearAvailability.swift RetireSmartIRATests/StateTaxJSONEquivalenceTests.swift
git commit -m "feat(state-tax): make constant-law extrapolation observable"
```

---

### Task 3: Golden scenario fixture format and loader

**Files:**
- Create: `RetireSmartIRATests/GoldenScenario.swift`
- Create: `RetireSmartIRATests/GoldenScenarios/statetax-2026-PA.golden.json`
- Create: `RetireSmartIRATests/GoldenScenarios/statetax-2026-IL.golden.json`
- Create: `RetireSmartIRATests/GoldenScenarios/statetax-2026-MS.golden.json`

**Interfaces:**
- Produces: `struct GoldenScenario: Codable` and `struct GoldenScenarioFile: Codable`, plus `GoldenScenario.load(abbreviation:) throws -> GoldenScenarioFile`. Tasks 4, 5 and 6 consume these.

Each scenario carries its own citation. A fixture without a citation is worthless, because nobody can later tell whether the expected number came from a state form or from the engine it is supposed to be checking.

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/GoldenScenarioLoaderTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenario fixtures")
struct GoldenScenarioLoaderTests {

    /// The Phase 2 pilot. Phase 4 extends this to all 51 jurisdictions.
    static let pilot = ["PA", "IL", "MS"]

    @Test("Every pilot fixture loads and is internally well formed",
          arguments: GoldenScenarioLoaderTests.pilot)
    func pilotFixturesLoad(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        #expect(file.state == abbreviation)
        #expect(file.taxYear == 2026)
        #expect(!file.scenarios.isEmpty, "\(abbreviation) has no scenarios")
        for scenario in file.scenarios {
            #expect(!scenario.name.isEmpty)
            #expect(!scenario.source.isEmpty,
                    "\(abbreviation)/\(scenario.name) has no citation, so its expected value is unverifiable")
            #expect(scenario.expectedStateTax >= 0)
            #expect(scenario.primaryAge > 0)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2 && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioLoaderTests > .scratch/t3.log 2>&1; echo "EXIT=$?"`
Expected: FAIL to compile, "cannot find 'GoldenScenario' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `RetireSmartIRATests/GoldenScenario.swift`:

```swift
import Foundation
@testable import RetireSmartIRA

/// One hand-derived tax case for one jurisdiction.
///
/// `expectedStateTax` MUST be derived from the state's own published form or
/// instructions, never from this app's output. `source` records which form and
/// which lines, so a future reader can re-derive it. A fixture whose expected
/// value came from the engine proves only that the engine agrees with itself.
struct GoldenScenario: Codable {
    let name: String
    /// Form and line numbers used to derive `expectedStateTax`.
    let source: String
    let filingStatus: String        // "single" or "marriedFilingJointly"
    let primaryAge: Int
    let spouseAge: Int?
    let totalIncome: Double
    let taxableSocialSecurity: Double
    let pensionIncome: Double
    let iraWithdrawals: Double
    let rothConversion: Double
    let expectedStateTax: Double

    var resolvedFilingStatus: FilingStatus {
        filingStatus == "marriedFilingJointly" ? .marriedFilingJointly : .single
    }
}

struct GoldenScenarioFile: Codable {
    let state: String
    let taxYear: Int
    let scenarios: [GoldenScenario]
}

extension GoldenScenario {
    enum LoadError: LocalizedError {
        case missing(abbreviation: String)
        var errorDescription: String? {
            switch self {
            case .missing(let abbreviation):
                return "No golden fixture bundled for \(abbreviation)."
            }
        }
    }

    /// Fixtures live in the TEST bundle, not the app bundle: they are
    /// verification data and must never ship to users.
    static func load(abbreviation: String) throws -> GoldenScenarioFile {
        let bundle = Bundle(for: GoldenScenarioMarker.self)
        guard let url = bundle.url(forResource: "statetax-2026-\(abbreviation).golden",
                                   withExtension: "json") else {
            throw LoadError.missing(abbreviation: abbreviation)
        }
        return try JSONDecoder().decode(GoldenScenarioFile.self, from: Data(contentsOf: url))
    }
}

private final class GoldenScenarioMarker {}
```

Create `RetireSmartIRATests/GoldenScenarios/statetax-2026-PA.golden.json`:

```json
{
  "state": "PA",
  "taxYear": 2026,
  "scenarios": [
    {
      "name": "retiree, pension and IRA fully exempt",
      "source": "PA-40 instructions: retirement income from an eligible plan after separation from service is not PA-taxable. Flat rate 3.07% per PA-40 line 12.",
      "filingStatus": "single",
      "primaryAge": 67,
      "spouseAge": null,
      "totalIncome": 90000,
      "taxableSocialSecurity": 0,
      "pensionIncome": 40000,
      "iraWithdrawals": 50000,
      "rothConversion": 0,
      "expectedStateTax": 0
    }
  ]
}
```

Create `RetireSmartIRATests/GoldenScenarios/statetax-2026-IL.golden.json`:

```json
{
  "state": "IL",
  "taxYear": 2026,
  "scenarios": [
    {
      "name": "retiree, all retirement income subtracted",
      "source": "IL-1040 Schedule M: federally taxable retirement income from qualified plans is subtracted. Flat rate 4.95% per IL-1040 line 12.",
      "filingStatus": "single",
      "primaryAge": 67,
      "spouseAge": null,
      "totalIncome": 90000,
      "taxableSocialSecurity": 0,
      "pensionIncome": 40000,
      "iraWithdrawals": 50000,
      "rothConversion": 0,
      "expectedStateTax": 0
    }
  ]
}
```

Create `RetireSmartIRATests/GoldenScenarios/statetax-2026-MS.golden.json`:

```json
{
  "state": "MS",
  "taxYear": 2026,
  "scenarios": [
    {
      "name": "retiree, qualified retirement income exempt",
      "source": "MS Code 27-7-15(4)(j): retirement income from a qualified plan is exempt for taxpayers who have met the plan's retirement requirements.",
      "filingStatus": "single",
      "primaryAge": 67,
      "spouseAge": null,
      "totalIncome": 90000,
      "taxableSocialSecurity": 0,
      "pensionIncome": 40000,
      "iraWithdrawals": 50000,
      "rothConversion": 0,
      "expectedStateTax": 0
    }
  ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the Step 2 command again.
Expected: PASS, 3 cases.

If it fails with `LoadError.missing`, the fixtures did not reach the test bundle. Do NOT edit `project.pbxproj`. Check that the files are under `RetireSmartIRATests/` (a synchronized root) and report BLOCKED if they still do not resolve.

- [ ] **Step 5: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2
git add RetireSmartIRATests/GoldenScenario.swift RetireSmartIRATests/GoldenScenarioLoaderTests.swift RetireSmartIRATests/GoldenScenarios
git commit -m "feat(state-tax): golden scenario fixture format with mandatory citations"
```

---

### Task 4: Single-year golden runner

**Files:**
- Create: `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`

**Interfaces:**
- Consumes: `GoldenScenario`, `GoldenScenarioFile`, `GoldenScenario.load(abbreviation:)` from Task 3.
- Produces: `GoldenScenarioSingleYearTests.singleYearStateTax(_:state:) -> Double`, reused by Task 6.

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/GoldenScenarioSingleYearTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenarios, single-year path")
struct GoldenScenarioSingleYearTests {

    static let pilot = ["PA", "IL", "MS"]

    /// Drives the same entry point the Scenarios screen uses.
    static func singleYearStateTax(_ scenario: GoldenScenario, state: USState) -> Double {
        var sources: [IncomeSource] = []
        if scenario.pensionIncome > 0 {
            sources.append(IncomeSource(name: "Pension", type: .pension,
                                        annualAmount: scenario.pensionIncome))
        }
        let hasSpouse = scenario.spouseAge != nil
        return TaxCalculationEngine.calculateStateTax(
            income: scenario.totalIncome,
            forState: state,
            filingStatus: scenario.resolvedFilingStatus,
            taxableSocialSecurity: scenario.taxableSocialSecurity,
            incomeSources: sources,
            currentAge: scenario.primaryAge,
            enableSpouse: hasSpouse,
            spouseBirthYear: 2026 - (scenario.spouseAge ?? scenario.primaryAge),
            currentYear: 2026,
            scenarioRetirementDistributions: scenario.iraWithdrawals,
            scenarioRothConversionAmount: scenario.rothConversion
        )
    }

    @Test("Single-year path matches each state's own published form",
          arguments: GoldenScenarioSingleYearTests.pilot)
    func singleYearMatchesGolden(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        let state = try #require(USState.allCases.first { $0.abbreviation == abbreviation })
        for scenario in file.scenarios {
            let actual = Self.singleYearStateTax(scenario, state: state)
            #expect(abs(actual - scenario.expectedStateTax) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): engine \(actual), form says \(scenario.expectedStateTax).
                    Source: \(scenario.source)
                    Phase 2 corrects no tax value. If the engine is wrong, record it and leave it for Phase 5.
                    """)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails or passes, and read carefully**

Run: `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2 && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioSingleYearTests > .scratch/t4.log 2>&1; echo "EXIT=$?"`

Expected: PASS for all three. PA, IL and MS fully exempt qualified retirement income, so the expected figure is 0 and the engine should already agree.

**If any FAILS, that is a finding, not a bug to fix here.** Record the state, the engine figure, the form figure and the citation in your report, and do NOT change the config or the engine. Phase 2 corrects nothing.

- [ ] **Step 3: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2
git add RetireSmartIRATests/GoldenScenarioSingleYearTests.swift
git commit -m "feat(state-tax): golden scenario runner for the single-year path"
```

---

### Task 5: Multi-year golden runner

**Files:**
- Create: `RetireSmartIRATests/GoldenScenarioMultiYearTests.swift`

**Interfaces:**
- Consumes: `GoldenScenario` from Task 3.
- Produces: `GoldenScenarioMultiYearTests.multiYearYearOneStateTax(_:abbreviation:) -> Double?`, reused by Task 6.

`ProjectionEngine.project(inputs:assumptions:actionsPerYear:) -> [YearRecommendation]` is the multi-year entry point. `MultiYearStaticInputs.state` is a `String` abbreviation, not a `USState`. `baseYear` MUST be pinned or the projection depends on today's date.

- [ ] **Step 1: Confirm how year-1 state tax is exposed**

`MultiYearStaticInputs` is declared in `RetireSmartIRA/MultiYearStaticInputs.swift`. Its initializer takes 20 required parameters and 19 defaulted ones; the construction below passes exactly the required set plus `baseYear`. **`baseYear` defaults to `Calendar.current.component(.year, from: Date())`, so it MUST be pinned or every golden scenario silently depends on today's date.**

You still need one fact this plan does not fix, because it varies by model shape. Find how a `YearRecommendation` exposes its state tax:

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2
grep -rn "state" RetireSmartIRA/PlanningModels.swift | grep -iE "taxbreakdown|struct|let state" | head -10
grep -n "state: stateTax" RetireSmartIRA/ProjectionEngine.swift
```

`ProjectionEngine.swift:896` assigns `state: stateTax` into a breakdown, so follow that type. Use the accessor you find; do not guess a property name.

- [ ] **Step 2: Write the failing test**

Create `RetireSmartIRATests/GoldenScenarioMultiYearTests.swift`, substituting the real year-1 state tax accessor you found in Step 1 where marked:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenarios, multi-year path")
struct GoldenScenarioMultiYearTests {

    static let pilot = ["PA", "IL", "MS"]

    /// Year-1 state tax from the multi-year projection, or nil if the engine
    /// returned no years for this scenario.
    static func multiYearYearOneStateTax(_ scenario: GoldenScenario,
                                         abbreviation: String) -> Double? {
        let baseYear = 2026   // pinned: the initializer otherwise defaults to today's calendar year
        let hasSpouse = scenario.spouseAge != nil

        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: max(scenario.iraWithdrawals * 20, 100_000),
                                              roth: 0, taxable: 0, hsa: 0),
            baseYear: baseYear,
            primaryCurrentAge: scenario.primaryAge,
            spouseCurrentAge: scenario.spouseAge,
            filingStatus: scenario.resolvedFilingStatus,
            state: abbreviation,
            primarySSClaimAge: 70,
            spouseSSClaimAge: hasSpouse ? 70 : nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: hasSpouse ? 0 : nil,
            primaryBirthYear: baseYear - scenario.primaryAge,
            spouseBirthYear: scenario.spouseAge.map { baseYear - $0 },
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: scenario.pensionIncome,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: hasSpouse ? 2 : 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: hasSpouse ? 65 : nil,
            baselineAnnualExpenses: 0
        )

        // Social Security is set to 0 so the projection does not inject income the
        // golden scenario did not specify. Claim age 70 keeps it out of year 1 regardless.
        let assumptions = MultiYearAssumptions()
        // Verified against RetireSmartIRA/MultiYearTypes.swift:24-33. The case is
        // `traditionalWithdrawal(amount:)` with NO owner parameter.
        var yearOneActions: [LeverAction] = []
        if scenario.iraWithdrawals > 0 {
            yearOneActions.append(.traditionalWithdrawal(amount: scenario.iraWithdrawals))
        }
        if scenario.rothConversion > 0 {
            yearOneActions.append(.rothConversion(amount: scenario.rothConversion))
        }
        let actions: [Int: [LeverAction]] = [baseYear: yearOneActions]

        let engine = ProjectionEngine()
        let path = engine.project(inputs: inputs, assumptions: assumptions, actionsPerYear: actions)
        guard let yearOne = path.first else { return nil }
        return yearOne.taxBreakdown.state   // <- replace with the real accessor from Step 1
    }

    @Test("Multi-year year-1 matches each state's own published form",
          arguments: GoldenScenarioMultiYearTests.pilot)
    func multiYearMatchesGolden(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            let actual = try #require(Self.multiYearYearOneStateTax(scenario,
                                                                   abbreviation: abbreviation))
            #expect(abs(actual - scenario.expectedStateTax) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): multi-year \(actual), form says \(scenario.expectedStateTax).
                    Source: \(scenario.source)
                    Phase 2 corrects no tax value. Record any mismatch and leave it for Phase 5.
                    """)
        }
    }
}
```

**The `fatalError` above is deliberate scaffolding you MUST replace in this step**, using the real initializer from Step 1. Do not commit a `fatalError`.

- [ ] **Step 3: Run and read carefully**

Run: `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2 && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioMultiYearTests > .scratch/t5.log 2>&1; echo "EXIT=$?"`

A mismatch here is a finding to report, not a number to change. Multi-year drives the projection through growth, RMDs and Social Security, so if you cannot make year 1 correspond to the scenario's inputs, say so plainly rather than tuning the fixture to match the engine. Tuning a fixture to match the code destroys the entire purpose of a golden scenario.

- [ ] **Step 4: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2
git add RetireSmartIRATests/GoldenScenarioMultiYearTests.swift
git commit -m "feat(state-tax): golden scenario runner for the multi-year path"
```

---

### Task 6: Cross-path invariant with pinned known divergences

**Files:**
- Create: `RetireSmartIRATests/GoldenScenarioCrossPathTests.swift`
- Create: `RetireSmartIRATests/GoldenScenarios/statetax-2026-NJ.golden.json`

**Interfaces:**
- Consumes: `GoldenScenarioSingleYearTests.singleYearStateTax(_:state:)` (Task 4) and `GoldenScenarioMultiYearTests.multiYearYearOneStateTax(_:abbreviation:)` (Task 5).

This is Phase 2's deliverable. Its job is to make every disagreement between the two screens visible.

**Its first run is expected to FAIL for New Jersey.** That is the known I2 divergence, and a green run would be the suspicious outcome.

- [ ] **Step 1: Add the New Jersey fixture**

Create `RetireSmartIRATests/GoldenScenarios/statetax-2026-NJ.golden.json`. Derive `expectedStateTax` by hand from the NJ-1040 instructions, showing your arithmetic in your report:

```json
{
  "state": "NJ",
  "taxYear": 2026,
  "scenarios": [
    {
      "name": "age 65 single, pension inside the first phaseout band",
      "source": "NJ-1040 Worksheet D pension/retirement exclusion, single cap $75,000, first band retains 100% at total income of $100,000 or less. Personal exemption $1,000 per filer per NJ-1040 line 13.",
      "filingStatus": "single",
      "primaryAge": 65,
      "spouseAge": null,
      "totalIncome": 95000,
      "taxableSocialSecurity": 0,
      "pensionIncome": 80000,
      "iraWithdrawals": 0,
      "rothConversion": 0,
      "expectedStateTax": 280.0
    }
  ]
}
```

**The $280 above is NOT usable as-is and you must replace it.**

Its provenance is circular: it came from a reviewer who re-implemented this app's own `applyRetirementExemptions` logic in order to check something else. It is therefore engine-derived, not form-derived. Committing it as a golden expected value would assert only that the engine agrees with itself, which is precisely the failure these fixtures exist to prevent.

Derive the figure yourself from New Jersey's published materials, and show the arithmetic in your report:

1. NJ-1040 Worksheet D, pension and retirement exclusion. Single filers, total income of $100,000 or less, retain 100% of the exclusion, capped at $75,000. Apply it to the $80,000 pension.
2. Subtract the personal exemption. NJ-1040 line 13 gives $1,000 per filer.
3. Apply the NJ rate schedule for single filers to what remains.

If your derived figure differs from $280, **use yours** and note the discrepancy. If you cannot confidently derive it from published materials, report BLOCKED rather than guessing: a fixture with an unverifiable expected value is worse than no fixture, because it looks like verification.

- [ ] **Step 2: Write the cross-path test**

Create `RetireSmartIRATests/GoldenScenarioCrossPathTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

/// Asserts the Scenarios screen and the Multi-Year screen agree.
///
/// Two divergences are already known and are pinned as expected failures, so
/// they stay visible and so a NEW divergence is distinguishable from them.
/// Both are fixed in Phase 5, not here, because fixing them moves numbers.
///
/// 1. ProjectionEngine.computeStateTax omits `postExemptionDeduction`
///    (ProjectionEngine.swift:1622-1634), so NJ's per-filer personal exemptions
///    vanish in Multi-Year. Backlog I2.
/// 2. `.rmd` IncomeSource rows are ungated while `scenarioRetirementDistributions`
///    is gated at 59.5 (TaxCalculationEngine.swift:582-585). Multi-year synthesizes
///    `.rmd` rows, so an under-59.5 household gets the IRA exemption in Multi-Year
///    and is denied it in Scenarios.
@Suite("Golden scenarios, cross-path agreement")
struct GoldenScenarioCrossPathTests {

    /// States where the two paths are expected to agree today.
    static let agreeing = ["PA", "IL", "MS"]

    @Test("Both screens report the same state tax",
          arguments: GoldenScenarioCrossPathTests.agreeing)
    func pathsAgree(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        let state = try #require(USState.allCases.first { $0.abbreviation == abbreviation })
        for scenario in file.scenarios {
            let single = GoldenScenarioSingleYearTests.singleYearStateTax(scenario, state: state)
            let multi = try #require(
                GoldenScenarioMultiYearTests.multiYearYearOneStateTax(scenario,
                                                                     abbreviation: abbreviation))
            #expect(abs(single - multi) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): Scenarios \(single), Multi-Year \(multi).
                    Same household, two screens, different tax. If this is a NEW divergence,
                    it is a finding: report the mechanism, do not adjust either number.
                    """)
        }
    }

    @Test("KNOWN DIVERGENCE, backlog I2: New Jersey personal exemptions vanish in Multi-Year")
    func newJerseyPersonalExemptionDivergenceIsStillPresent() throws {
        let file = try GoldenScenario.load(abbreviation: "NJ")
        let scenario = try #require(file.scenarios.first)
        let single = GoldenScenarioSingleYearTests.singleYearStateTax(scenario, state: .newJersey)
        let multi = try #require(
            GoldenScenarioMultiYearTests.multiYearYearOneStateTax(scenario, abbreviation: "NJ"))

        // Pinned as PRESENT, not as correct. When Phase 5 fixes I2 this test
        // fails, which is the intended signal to delete it.
        #expect(abs(single - multi) >= 0.01,
                """
                NJ single-year \(single) and multi-year \(multi) now agree.
                If Phase 5 fixed I2, delete this test. If nobody fixed it, the
                divergence was masked, which is worse: find out how.
                """)
    }
}
```

- [ ] **Step 3: Run and catalogue**

Run: `cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2 && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/GoldenScenarioCrossPathTests > .scratch/t6.log 2>&1; echo "EXIT=$?"`

Record in your report, for every scenario: the single-year figure, the multi-year figure, the difference, and the mechanism if they differ. **A disagreement in PA, IL or MS would be a new, unrecorded divergence and is the most valuable thing this task can produce.**

- [ ] **Step 4: Commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase2
git add RetireSmartIRATests/GoldenScenarioCrossPathTests.swift RetireSmartIRATests/GoldenScenarios/statetax-2026-NJ.golden.json
git commit -m "feat(state-tax): cross-path invariant with known divergences pinned"
```

---

## Phase 2 Exit Criteria

- [ ] `StateTaxDataLoader.configs(for:)` resolves 2026 and returns empty for unbundled years.
- [ ] `StateTaxYearAvailability` reports 2026 as the latest bundled year and discloses extrapolation beyond it.
- [ ] Golden fixtures load from the TEST bundle for PA, IL, MS and NJ, each scenario carrying a citation.
- [ ] Both runners execute, and every mismatch against a state form is catalogued rather than silenced.
- [ ] The cross-path invariant runs, agrees for PA/IL/MS, and pins NJ's I2 divergence as present.
- [ ] Full suite green: 1,605 Swift Testing + 503 XCTest as a floor, plus the new tests. Controller runs this.
- [ ] No computed tax value changed anywhere.

## What Phase 2 Deliberately Does Not Do

It corrects nothing. Iowa still taxes retirement income it exempts by statute, Michigan's exemption is still uncapped, Kansas still has no personal exemption, and both cross-path divergences remain. Every one of those is Phase 5, gated on a golden scenario derived from the state's own form.

It also does not extend beyond the pilot. Phase 4 writes fixtures for all 51 jurisdictions, four cases each (five where an AGI phase-out applies), which is the bulk of the remaining work in this program.
