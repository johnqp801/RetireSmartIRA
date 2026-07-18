# Per-Year Expense Overrides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users override living expenses for specific future years in the Multi-Year plan — as a recurring baseline change and/or a one-time adjustment — with the engine re-projecting from their numbers.

**Architecture:** Generalize the engine's expense-override map into a per-year override struct (`YearOverride` with a `livingExpenses: FieldOverride?`). The engine resolves each year's expense as `max(0, recurringBaseline(Y) + oneTime(Y))`. A pure, behavior-preserving migration converts the legacy absolute-total map into the new additive representation. A `YearDetailEditor` sheet, reached via an explicit per-row edit control, edits one year at a time.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`@Test`) + XCTest, Xcode (macOS + iOS targets).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-17-per-year-overrides-design.md` (authoritative).
- Ships in 2.1.2, **expenses only**; income entry is out of scope (v2.2).
- All expense amounts are **nominal** (actual dollars in that year).
- Overridable = **inputs only**; never computed outputs (tax, RMD, IRMAA, AGI, balances).
- Back-compat is **lazy / defensive**: absent keys decode to empty, never a decode failure (mirror the existing `decodeIfPresent` pattern in `IncomeModels.swift` / `MultiYearAssumptions.swift`).
- Migration is **behavior-preserving, idempotent, and atomic** (schema bumped only after success; legacy→delta never runs twice).
- **Practical note:** no shipped version ever *wrote* `perYearExpenseOverrides` (engine reads it at `ProjectionEngine.swift:490`; no UI writes it), so real persisted maps are **empty**. The migration must still be correct (tests construct non-empty legacy maps), but the production path is the empty case.
- Run the full macOS suite before considering any task done: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`.
- Test files are auto-discovered (`PBXFileSystemSynchronizedRootGroup`) — no `.pbxproj` edits when adding files.
- Commit messages end with the project's `Co-Authored-By` trailer.

---

### Task 1: `FieldOverride` + `YearOverride` model with pruning

**Files:**
- Create: `RetireSmartIRA/YearOverride.swift`
- Test: `RetireSmartIRATests/YearOverrideModelTests.swift`

**Interfaces:**
- Produces:
  - `struct FieldOverride: Codable, Equatable, Sendable { var recurringLevel: Double?; var oneTimeAmount: Double?; var isEmpty: Bool; var pruned: FieldOverride? }`
  - `struct YearOverride: Codable, Equatable, Sendable { var livingExpenses: FieldOverride?; var isEmpty: Bool; var pruned: YearOverride? }`
  - `extension Dictionary where Key == Int, Value == YearOverride { func pruned() -> [Int: YearOverride] }`

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/YearOverrideModelTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("YearOverride model")
struct YearOverrideModelTests {
    @Test("empty FieldOverride prunes to nil")
    func fieldEmptyPrunes() {
        #expect(FieldOverride(recurringLevel: nil, oneTimeAmount: nil).isEmpty)
        #expect(FieldOverride(recurringLevel: nil, oneTimeAmount: nil).pruned == nil)
        #expect(FieldOverride(recurringLevel: 0, oneTimeAmount: nil).isEmpty == false)   // 0 is a real value
        #expect(FieldOverride(recurringLevel: nil, oneTimeAmount: 100).pruned != nil)
    }

    @Test("YearOverride with only an empty field prunes to nil")
    func yearPrunes() {
        let y = YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: nil))
        #expect(y.pruned == nil)
        let y2 = YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: nil))
        #expect(y2.pruned != nil)
    }

    @Test("dictionary pruning drops empty entries, keeps real ones")
    func dictPrunes() {
        let d: [Int: YearOverride] = [
            2028: YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: nil)),
            2030: YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: nil)),
        ]
        let pruned = d.pruned()
        #expect(pruned.keys.sorted() == [2028])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/YearOverrideModelTests`
Expected: FAIL — `FieldOverride`/`YearOverride` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// RetireSmartIRA/YearOverride.swift
import Foundation

/// One overridable input for one year. `recurringLevel` is a step-change to the recurring baseline
/// effective this year onward (CPI-grown from here until a later recurring anchor); `oneTimeAmount`
/// is an additive adjustment for this year only (may be negative). nil = "not overridden".
struct FieldOverride: Codable, Equatable, Sendable {
    var recurringLevel: Double?
    var oneTimeAmount: Double?

    var isEmpty: Bool { recurringLevel == nil && oneTimeAmount == nil }
    /// nil when empty, else self — so empty records are never stored.
    var pruned: FieldOverride? { isEmpty ? nil : self }
}

/// All per-year input overrides for one year. 2.1.2 wires `livingExpenses`; income/withdrawal
/// fields are added here later without restructuring.
struct YearOverride: Codable, Equatable, Sendable {
    var livingExpenses: FieldOverride?

    var isEmpty: Bool { (livingExpenses?.pruned) == nil }
    var pruned: YearOverride? {
        let le = livingExpenses?.pruned
        return le == nil ? nil : YearOverride(livingExpenses: le)
    }
}

extension Dictionary where Key == Int, Value == YearOverride {
    /// Drops empty year entries so the map never carries dead keys (badges read real values).
    func pruned() -> [Int: YearOverride] {
        reduce(into: [:]) { acc, kv in if let p = kv.value.pruned { acc[kv.key] = p } }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/YearOverrideModelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/YearOverride.swift RetireSmartIRATests/YearOverrideModelTests.swift
git commit -m "feat(overrides): FieldOverride/YearOverride model with empty-record pruning"
```

---

### Task 2: Behavior-preserving migration (pure function)

**Files:**
- Create: `RetireSmartIRA/PerYearOverrideMigration.swift`
- Test: `RetireSmartIRATests/PerYearOverrideMigrationTests.swift`

**Interfaces:**
- Consumes: `YearOverride`, `FieldOverride` (Task 1).
- Produces: `enum PerYearOverrideMigration { static func migrate(legacyExpenseOverrides: [Int: Double], baselineAnnualExpenses: Double, cpiRate: Double, baseYear: Int) -> [Int: YearOverride] }`

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/PerYearOverrideMigrationTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("Per-year override migration")
struct PerYearOverrideMigrationTests {
    // baseline $100k, cpi 0 → originalBaseline(any year) == 100k
    @Test("legacy absolute total migrates to additive delta (legacy - baseline)")
    func legacyToDelta() {
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [2030: 120_000],
            baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(out[2030]?.livingExpenses?.oneTimeAmount == 20_000)
        #expect(out[2030]?.livingExpenses?.recurringLevel == nil)   // legacy never re-anchors
    }

    @Test("legacy below baseline yields a negative delta")
    func legacyBelow() {
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [2030: 60_000],
            baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(out[2030]?.livingExpenses?.oneTimeAmount == -40_000)
    }

    @Test("legacy equal to the CPI-grown baseline yields zero delta")
    func legacyEqualsGrownBaseline() {
        // baseline 100k, cpi 10%, 2 years → 121k; legacy 121k → delta 0
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [2028: 121_000],
            baselineAnnualExpenses: 100_000, cpiRate: 0.10, baseYear: 2026)
        #expect(abs((out[2028]?.livingExpenses?.oneTimeAmount ?? .nan)) < 0.001)
    }

    @Test("multiple legacy years all migrate")
    func multiple() {
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [2030: 120_000, 2031: 90_000],
            baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(out.count == 2)
        #expect(out[2030]?.livingExpenses?.oneTimeAmount == 20_000)
        #expect(out[2031]?.livingExpenses?.oneTimeAmount == -10_000)
    }

    @Test("empty legacy map migrates to empty (the production case)")
    func emptyStaysEmpty() {
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [:], baselineAnnualExpenses: 100_000, cpiRate: 0.02, baseYear: 2026)
        #expect(out.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/PerYearOverrideMigrationTests`
Expected: FAIL — `PerYearOverrideMigration` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// RetireSmartIRA/PerYearOverrideMigration.swift
import Foundation

/// Converts the legacy expense-override map (an ABSOLUTE total per year) into the new ADDITIVE
/// representation. `expense(Y)` was `legacy(Y)`; it is now `recurringBaseline(Y) + oneTime(Y)`, so
/// the equivalent one-time delta is `legacy(Y) - originalBaseline(Y)`. Legacy overrides were single
/// years, so they carry no recurring level. Pure and side-effect-free.
enum PerYearOverrideMigration {
    static func migrate(legacyExpenseOverrides: [Int: Double],
                        baselineAnnualExpenses: Double,
                        cpiRate: Double,
                        baseYear: Int) -> [Int: YearOverride] {
        legacyExpenseOverrides.reduce(into: [:]) { acc, kv in
            let (year, legacy) = kv
            let originalBaseline = baselineAnnualExpenses * pow(1 + cpiRate, Double(max(0, year - baseYear)))
            let delta = legacy - originalBaseline
            acc[year] = YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: delta))
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/PerYearOverrideMigrationTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/PerYearOverrideMigration.swift RetireSmartIRATests/PerYearOverrideMigrationTests.swift
git commit -m "feat(overrides): behavior-preserving legacy→delta migration function"
```

---

### Task 3: Swap the assumptions field to `perYearOverrides` + schema marker + Codable

**Files:**
- Modify: `RetireSmartIRA/MultiYearAssumptions.swift` (field at `:22`, memberwise init `:53`/`:71`, `init(from:)` `:86`/`:94`, `encode`, `CodingKeys`)
- Modify: `RetireSmartIRA/ProjectionEngine.swift:490` (temporary: read new map's one-time only, so the project compiles between tasks — Task 4 replaces this with the full resolver)
- Test: `RetireSmartIRATests/MultiYearAssumptionsOverrideCodableTests.swift`

**Interfaces:**
- Consumes: `YearOverride` (Task 1).
- Produces: `MultiYearAssumptions.perYearOverrides: [Int: YearOverride]` and `MultiYearAssumptions.perYearOverridesSchema: Int` (0 = pre-feature/legacy, 1 = migrated). Removes `perYearExpenseOverrides`.

**Note:** every existing construction of `MultiYearAssumptions` that passes `perYearExpenseOverrides:` must be updated to `perYearOverrides:` (search: `grep -rn "perYearExpenseOverrides" RetireSmartIRA RetireSmartIRATests`). Expect hits in test fixtures (`ProjectionEngineTests`, `RealismRegressionTests`, `ObjectivePVTests`, `AuditProfiles` on the harness branch) — update each `perYearExpenseOverrides: [:]` to `perYearOverrides: [:]`.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/MultiYearAssumptionsOverrideCodableTests.swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("MultiYearAssumptions per-year override Codable")
struct MultiYearAssumptionsOverrideCodableTests {
    @Test("round-trips perYearOverrides and schema")
    func roundTrip() throws {
        var a = MultiYearAssumptions()
        a.perYearOverrides = [2030: YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: 40_000))]
        a.perYearOverridesSchema = 1
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(MultiYearAssumptions.self, from: data)
        #expect(back.perYearOverrides[2030]?.livingExpenses?.recurringLevel == 90_000)
        #expect(back.perYearOverrides[2030]?.livingExpenses?.oneTimeAmount == 40_000)
        #expect(back.perYearOverridesSchema == 1)
    }

    @Test("legacy JSON without the new keys decodes to empty overrides + schema 0")
    func legacyDecode() throws {
        // A minimal older blob missing perYearOverrides / schema (and using the OLD key, which is ignored).
        let json = #"{"horizonEndAge":95,"cpiRate":0.025,"investmentGrowthRate":0.06,"perYearExpenseOverrides":{},"terminalLiquidationTaxRate":0.22,"cliffBuffer":5000}"#.data(using: .utf8)!
        let back = try JSONDecoder().decode(MultiYearAssumptions.self, from: json)
        #expect(back.perYearOverrides.isEmpty)
        #expect(back.perYearOverridesSchema == 0)   // pre-feature marker → migration will run
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearAssumptionsOverrideCodableTests`
Expected: FAIL — `perYearOverrides` / `perYearOverridesSchema` undefined.

- [ ] **Step 3: Write minimal implementation**

In `MultiYearAssumptions.swift`:
- Replace the field: `var perYearOverrides: [Int: YearOverride]` (drop `perYearExpenseOverrides`).
- Add: `var perYearOverridesSchema: Int` (new plans created via the memberwise init default to `1`; decode of an older blob yields `0`).
- Memberwise init: replace the `perYearExpenseOverrides: [Int: Double] = [:]` parameter with `perYearOverrides: [Int: YearOverride] = [:]` and add `perYearOverridesSchema: Int = 1`; assign both.
- `init(from:)`: replace line 94 with defensive decode, and add the schema:
```swift
self.perYearOverrides = (try? c.decodeIfPresent([Int: YearOverride].self, forKey: .perYearOverrides)) ?? [:]
self.perYearOverridesSchema = (try? c.decodeIfPresent(Int.self, forKey: .perYearOverridesSchema)) ?? 0
```
- `encode(to:)`: encode `perYearOverrides` and `perYearOverridesSchema`; stop encoding the old key.
- `CodingKeys`: replace `perYearExpenseOverrides` with `perYearOverrides`, add `perYearOverridesSchema`.

In `ProjectionEngine.swift:490` (interim, replaced in Task 4 — keeps the build green):
```swift
if let ov = assumptions.perYearOverrides[year]?.livingExpenses,
   let oneTime = ov.oneTimeAmount {
    let yearsFromBase = max(0, year - scenarioBaseYear)
    let base = inputs.baselineAnnualExpenses * pow(1.0 + assumptions.cpiRate, Double(yearsFromBase))
    return max(0, base + oneTime)
}
```

Then update every `perYearExpenseOverrides: [:]` construction site (see Note) to `perYearOverrides: [:]`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearAssumptionsOverrideCodableTests`
Expected: PASS. Then run the full suite to catch any missed construction site — all green.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(overrides): swap MultiYearAssumptions to perYearOverrides + schema marker"
```

---

### Task 4: Engine resolution — recurring anchor + one-time + floor

**Files:**
- Modify: `RetireSmartIRA/ProjectionEngine.swift:489-498` (the `annualExpenses` closure)
- Create: `RetireSmartIRA/ExpenseResolution.swift` (pure resolver so it is unit-testable without a full projection)
- Test: `RetireSmartIRATests/ExpenseResolutionTests.swift`
- Test: `RetireSmartIRATests/PerYearExpenseDownstreamTests.swift`

**Interfaces:**
- Consumes: `YearOverride` (Task 1), `MultiYearAssumptions.perYearOverrides` (Task 3).
- Produces: `enum ExpenseResolution { static func expense(year: Int, baseYear: Int, baselineAnnualExpenses: Double, cpiRate: Double, overrides: [Int: YearOverride]) -> Double }`

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/ExpenseResolutionTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("Expense resolution (recurring anchor + one-time)")
struct ExpenseResolutionTests {
    // Worked example from the spec: baseline $100k, cpi 0, baseYear 2026.
    private func expense(_ year: Int, _ o: [Int: YearOverride]) -> Double {
        ExpenseResolution.expense(year: year, baseYear: 2026, baselineAnnualExpenses: 100_000, cpiRate: 0, overrides: o)
    }
    private func le(recurring: Double? = nil, oneTime: Double? = nil) -> YearOverride {
        YearOverride(livingExpenses: FieldOverride(recurringLevel: recurring, oneTimeAmount: oneTime))
    }

    @Test("no overrides → CPI-grown baseline")
    func noOverrides() { #expect(expense(2030, [:]) == 100_000) }

    @Test("one-time spike changes only that year")
    func spike() {
        let o = [2030: le(oneTime: 40_000)]
        #expect(expense(2030, o) == 140_000)
        #expect(expense(2031, o) == 100_000)   // neighbor unaffected
    }

    @Test("recurring anchor re-baselines from its year onward until a later anchor")
    func anchor() {
        let o = [2028: le(recurring: 90_000), 2032: le(recurring: 75_000)]
        #expect(expense(2027, o) == 100_000)   // before anchor
        #expect(expense(2028, o) == 90_000)
        #expect(expense(2031, o) == 90_000)    // still 2028 anchor (cpi 0)
        #expect(expense(2032, o) == 75_000)    // new anchor
        #expect(expense(2040, o) == 75_000)
    }

    @Test("recurring and one-time coexist in the same year (sum)")
    func coexist() {
        let o = [2028: le(recurring: 90_000, oneTime: 40_000)]
        #expect(expense(2028, o) == 130_000)
        #expect(expense(2029, o) == 90_000)    // one-time does not persist
    }

    @Test("negative one-time floors the resolved expense at zero")
    func floor() {
        let o = [2030: le(oneTime: -250_000)]
        #expect(expense(2030, o) == 0)
    }

    @Test("full spec worked example with CPI")
    func workedExampleCPI() {
        // baseline 100k, cpi 2%. 2028 recurring 90k; 2030 one-time +40k.
        func e(_ y: Int) -> Double {
            ExpenseResolution.expense(year: y, baseYear: 2026, baselineAnnualExpenses: 100_000, cpiRate: 0.02,
                overrides: [2028: le(recurring: 90_000), 2030: le(oneTime: 40_000)])
        }
        // 2030 = 90k grown 2 yrs at 2% + 40k
        let anchorGrown = 90_000 * 1.02 * 1.02
        #expect(abs(e(2030) - (anchorGrown + 40_000)) < 0.01)
        #expect(abs(e(2031) - anchorGrown * 1.02) < 0.01)   // resumes anchor path, no spike residue
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/ExpenseResolutionTests`
Expected: FAIL — `ExpenseResolution` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// RetireSmartIRA/ExpenseResolution.swift
import Foundation

/// Resolves a year's nominal living expense from the baseline + per-year overrides.
/// expense(Y) = max(0, recurringBaseline(Y) + oneTime(Y)), where recurringBaseline(Y) is the latest
/// `recurringLevel` anchor at/before Y grown by CPI from its year (else the original baseline from
/// baseYear), and oneTime(Y) is this year's additive adjustment (may be negative).
enum ExpenseResolution {
    static func expense(year: Int, baseYear: Int, baselineAnnualExpenses: Double,
                        cpiRate: Double, overrides: [Int: YearOverride]) -> Double {
        // Latest recurring anchor at or before `year`.
        let anchors = overrides
            .compactMap { (k, v) -> (Int, Double)? in
                guard k <= year, let lvl = v.livingExpenses?.recurringLevel else { return nil }
                return (k, lvl)
            }
            .sorted { $0.0 < $1.0 }
        let (anchorYear, anchorValue) = anchors.last ?? (baseYear, baselineAnnualExpenses)
        let recurring = anchorValue * pow(1 + cpiRate, Double(max(0, year - anchorYear)))
        let oneTime = overrides[year]?.livingExpenses?.oneTimeAmount ?? 0
        return max(0, recurring + oneTime)
    }
}
```

Then replace the `annualExpenses` closure at `ProjectionEngine.swift:489-498` (including the interim Task-3 block) with:
```swift
let annualExpenses = ExpenseResolution.expense(
    year: year, baseYear: scenarioBaseYear,
    baselineAnnualExpenses: inputs.baselineAnnualExpenses,
    cpiRate: assumptions.cpiRate, overrides: assumptions.perYearOverrides)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/ExpenseResolutionTests`
Expected: PASS.

- [ ] **Step 5: Write the downstream-recalculation tests**

```swift
// RetireSmartIRATests/PerYearExpenseDownstreamTests.swift
import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("Per-year expense override — downstream recalculation", .serialized)
struct PerYearExpenseDownstreamTests {
    private func inputs(traditional: Double, taxable: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: 0, taxable: taxable, hsa: 0),
            primaryCurrentAge: 66, spouseCurrentAge: nil, filingStatus: .single, state: "TX",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 66, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 40_000)
    }
    private func assumptions(overrides: [Int: YearOverride]) -> MultiYearAssumptions {
        var a = MultiYearAssumptions()
        a.horizonEndAge = 68; a.cpiRate = 0; a.investmentGrowthRate = 0.05
        a.stressTestEnabled = false; a.perYearOverrides = overrides
        return a
    }
    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    @Test("higher expense funded from the traditional IRA raises that year's tax")
    func expenseRaisesTax() {
        // Only-traditional funding: a bigger expense forces a bigger IRA withdrawal → more ordinary tax.
        let inp = inputs(traditional: 1_000_000, taxable: 0)
        func firstYearTax(_ o: [Int: YearOverride]) -> Double {
            ProjectionEngine().project(inputs: inp, assumptions: assumptions(overrides: o), actionsPerYear: [baseYear: []])[0].taxBreakdown.total
        }
        let baseTax = firstYearTax([:])
        let hiTax = firstYearTax([baseYear: YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: 60_000))])
        #expect(hiTax > baseTax + 1)
    }

    @Test("lower expense leaves more in the accounts (downstream balance rises)")
    func lowerExpenseRaisesBalance() {
        let inp = inputs(traditional: 500_000, taxable: 200_000)
        func endTaxable(_ o: [Int: YearOverride]) -> Double {
            ProjectionEngine().project(inputs: inp, assumptions: assumptions(overrides: o), actionsPerYear: [baseYear: []]).last!.endOfYearBalances.taxable
        }
        let base = endTaxable([:])
        let lower = endTaxable([baseYear: YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: -20_000))])
        #expect(lower > base + 1)
    }
}
```

Run both new suites: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/ExpenseResolutionTests -only-testing:RetireSmartIRATests/PerYearExpenseDownstreamTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(overrides): engine expense resolution (recurring anchor + one-time + floor)"
```

---

### Task 5: Idempotent, atomic load-time migration wiring

**Files:**
- Modify: `RetireSmartIRA/MultiYearStrategyManager.swift` (where `assumptions` is loaded from `dataManager.multiYearAssumptions`, `:110`; `dataManager.currentYear` is in scope)
- Modify: `RetireSmartIRA/MultiYearAssumptions.swift` (retain a private legacy-decode of the OLD key so a real legacy map can be migrated — see below)
- Test: `RetireSmartIRATests/PerYearOverrideUpgradeTests.swift`

**Interfaces:**
- Consumes: `PerYearOverrideMigration.migrate(...)` (Task 2), `perYearOverridesSchema` (Task 3).
- Produces: `MultiYearAssumptions.upgradedOverrides(baselineAnnualExpenses:cpiRate:baseYear:) -> MultiYearAssumptions` — pure, idempotent; converts a schema-0 plan (migrating any legacy map it decoded) and stamps schema 1; a schema-1 plan is returned unchanged.

**Detail:** because production legacy maps are empty, `init(from:)` decodes the legacy `perYearExpenseOverrides` into a private `legacyExpenseOverrides: [Int: Double]` (default `[:]`) held only until the upgrade runs. `upgradedOverrides` migrates it and clears it.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/PerYearOverrideUpgradeTests.swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Per-year override upgrade — idempotent & atomic")
struct PerYearOverrideUpgradeTests {
    /// Build a schema-0 assumptions blob carrying a legacy expense override, via JSON.
    private func schema0WithLegacy(_ legacy: [Int: Double]) throws -> MultiYearAssumptions {
        let legacyJSON = legacy.map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",")
        let json = "{\"horizonEndAge\":95,\"cpiRate\":0.0,\"investmentGrowthRate\":0.06,\"perYearExpenseOverrides\":{\(legacyJSON)},\"terminalLiquidationTaxRate\":0.22,\"cliffBuffer\":5000}".data(using: .utf8)!
        return try JSONDecoder().decode(MultiYearAssumptions.self, from: json)
    }

    @Test("schema-0 plan with a legacy override upgrades to the correct delta and stamps schema 1")
    func upgradesOnce() throws {
        let a = try schema0WithLegacy([2030: 120_000])
        #expect(a.perYearOverridesSchema == 0)
        let up = a.upgradedOverrides(baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(up.perYearOverridesSchema == 1)
        #expect(up.perYearOverrides[2030]?.livingExpenses?.oneTimeAmount == 20_000)
    }

    @Test("upgrading an already-upgraded plan is a no-op (never subtracts twice)")
    func idempotent() throws {
        let a = try schema0WithLegacy([2030: 120_000])
        let once = a.upgradedOverrides(baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        let twice = once.upgradedOverrides(baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(twice.perYearOverrides[2030]?.livingExpenses?.oneTimeAmount == 20_000)   // unchanged
        #expect(twice == once)
    }

    @Test("empty legacy (the production case) upgrades to empty + schema 1")
    func emptyUpgrades() throws {
        let a = try schema0WithLegacy([:])
        let up = a.upgradedOverrides(baselineAnnualExpenses: 100_000, cpiRate: 0.02, baseYear: 2026)
        #expect(up.perYearOverrides.isEmpty)
        #expect(up.perYearOverridesSchema == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/PerYearOverrideUpgradeTests`
Expected: FAIL — `legacyExpenseOverrides` / `upgradedOverrides` undefined.

- [ ] **Step 3: Write minimal implementation**

In `MultiYearAssumptions.swift`:
- Add a transient property (excluded from `encode`, so it never re-persists): `var legacyExpenseOverrides: [Int: Double] = [:]`.
- In `init(from:)`, decode the OLD key into it: `self.legacyExpenseOverrides = (try? c.decodeIfPresent([Int: Double].self, forKey: .perYearExpenseOverrides)) ?? [:]` (add `perYearExpenseOverrides` back to `CodingKeys` for decode-only; do NOT encode it).
- Add the upgrade:
```swift
/// Idempotent, atomic upgrade: a schema-0 plan migrates its legacy expense map into the additive
/// model and stamps schema 1; a schema-1 plan is returned unchanged (never migrates twice).
func upgradedOverrides(baselineAnnualExpenses: Double, cpiRate: Double, baseYear: Int) -> MultiYearAssumptions {
    guard perYearOverridesSchema < 1 else { return self }
    var copy = self
    let migrated = PerYearOverrideMigration.migrate(
        legacyExpenseOverrides: legacyExpenseOverrides,
        baselineAnnualExpenses: baselineAnnualExpenses, cpiRate: cpiRate, baseYear: baseYear)
    copy.perYearOverrides = perYearOverrides.merging(migrated) { _, new in new }.pruned()
    copy.legacyExpenseOverrides = [:]
    copy.perYearOverridesSchema = 1
    return copy
}
```
(Make `legacyExpenseOverrides` not participate in `Equatable`/`encode`: exclude it from `encode(to:)`; since `MultiYearAssumptions` uses synthesized `Equatable`? If it is, add an explicit `==` that ignores `legacyExpenseOverrides`, OR ensure it is cleared in both operands — the idempotent test compares post-upgrade values where it is `[:]` in both.)

In `MultiYearStrategyManager.swift` at `:110` (`self.assumptions = dataManager.multiYearAssumptions`), replace with:
```swift
self.assumptions = dataManager.multiYearAssumptions.upgradedOverrides(
    baselineAnnualExpenses: dataManager.multiYearAssumptions.baselineAnnualExpenses,
    cpiRate: dataManager.multiYearAssumptions.cpiRate,
    baseYear: dataManager.currentYear)
```
(The `didSet` on `assumptions` writes the upgraded value back to `dataManager.multiYearAssumptions`, persisting schema 1.)

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/PerYearOverrideUpgradeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(overrides): idempotent atomic load-time migration wiring"
```

---

### Task 6: `YearDetailEditor` sheet (view model + view)

**Files:**
- Create: `RetireSmartIRA/YearDetailEditor.swift` (a `YearOverrideEditModel` value type + the SwiftUI sheet)
- Test: `RetireSmartIRATests/YearOverrideEditModelTests.swift`

**Interfaces:**
- Consumes: `YearOverride`, `FieldOverride` (Task 1), `ExpenseResolution` (Task 4).
- Produces: `struct YearOverrideEditModel` with `init(year:existing:projectedBeforeThisYear:)`, editable `recurringText: String`, `oneTimeText: String`, `var resultingOverride: YearOverride?` (nil when both empty), and `var referenceLabel: String`.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/YearOverrideEditModelTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("YearOverrideEditModel")
struct YearOverrideEditModelTests {
    @Test("no existing override → empty fields, and empty edit produces no override")
    func emptyProducesNil() {
        var m = YearOverrideEditModel(year: 2030, existing: nil, projectedBeforeThisYear: 100_000)
        #expect(m.recurringText.isEmpty && m.oneTimeText.isEmpty)
        #expect(m.resultingOverride == nil)     // open + save with no entry → no override
    }

    @Test("existing override pre-populates both fields")
    func prepopulates() {
        let existing = YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: 40_000))
        let m = YearOverrideEditModel(year: 2030, existing: existing, projectedBeforeThisYear: 100_000)
        #expect(m.recurringText == "90000")
        #expect(m.oneTimeText == "40000")
    }

    @Test("entering values builds the override; clearing text yields nil")
    func buildsAndClears() {
        var m = YearOverrideEditModel(year: 2030, existing: nil, projectedBeforeThisYear: 100_000)
        m.oneTimeText = "40000"
        #expect(m.resultingOverride?.livingExpenses?.oneTimeAmount == 40_000)
        #expect(m.resultingOverride?.livingExpenses?.recurringLevel == nil)
        m.oneTimeText = ""
        #expect(m.resultingOverride == nil)
    }

    @Test("clearing one of two set values keeps the other (spec §9)")
    func clearOneKeepsOther() {
        var m = YearOverrideEditModel(year: 2030, existing:
            YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: 40_000)),
            projectedBeforeThisYear: 100_000)
        m.oneTimeText = ""   // clear the one-time, keep the recurring
        #expect(m.resultingOverride?.livingExpenses?.recurringLevel == 90_000)
        #expect(m.resultingOverride?.livingExpenses?.oneTimeAmount == nil)
    }

    @Test("non-finite / non-numeric text is ignored, not stored")
    func rejectsGarbage() {
        var m = YearOverrideEditModel(year: 2030, existing: nil, projectedBeforeThisYear: 100_000)
        m.recurringText = "abc"
        #expect(m.resultingOverride == nil)
    }

    @Test("reference label names the year")
    func referenceLabel() {
        let m = YearOverrideEditModel(year: 2030, existing: nil, projectedBeforeThisYear: 100_000)
        #expect(m.referenceLabel.contains("2030"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/YearOverrideEditModelTests`
Expected: FAIL — `YearOverrideEditModel` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// RetireSmartIRA/YearDetailEditor.swift
import SwiftUI

/// Pure edit state for one year's living-expense override. `resultingOverride` is nil when the user
/// entered nothing, so opening and saving without input creates no override (spec §6).
struct YearOverrideEditModel {
    let year: Int
    /// Baseline "before this year's adjustments": earlier recurring anchors, excluding THIS year's
    /// own recurring level and one-time amount.
    let projectedBeforeThisYear: Double
    var recurringText: String
    var oneTimeText: String

    init(year: Int, existing: YearOverride?, projectedBeforeThisYear: Double) {
        self.year = year
        self.projectedBeforeThisYear = projectedBeforeThisYear
        let le = existing?.livingExpenses
        self.recurringText = le?.recurringLevel.map { Self.fmt($0) } ?? ""
        self.oneTimeText = le?.oneTimeAmount.map { Self.fmt($0) } ?? ""
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
    private static func parse(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let d = Double(t), d.isFinite else { return nil }
        return d
    }

    var resultingOverride: YearOverride? {
        let field = FieldOverride(recurringLevel: Self.parse(recurringText), oneTimeAmount: Self.parse(oneTimeText))
        return YearOverride(livingExpenses: field).pruned
    }

    var referenceLabel: String { "Projected before \(year)'s adjustments" }
}
```
(The SwiftUI `YearDetailEditor` sheet itself — a `Form` with the read-only reference `Text`, two `TextField`s bound to `recurringText`/`oneTimeText` labelled per spec §6, a Clear button, and Save/Cancel that write `resultingOverride` into `assumptions.perYearOverrides[year]` then `.pruned()` — is added here too. Keep the sheet body small; extract rows if the type-checker complains, as in `SettingsView.localIncomeTaxField`.)

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/YearOverrideEditModelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/YearDetailEditor.swift RetireSmartIRATests/YearOverrideEditModelTests.swift
git commit -m "feat(overrides): YearDetailEditor edit model + sheet (no accidental overrides)"
```

---

### Task 7: Wire the edit affordance + override badge into the year rows

**Files:**
- Modify: `RetireSmartIRA/LadderRow.swift` (add `hasOverride: Bool` computed from the assumptions map)
- Modify: `RetireSmartIRA/MultiYearPlanSections.swift` (ladder row view: add the edit control + badge)
- Modify: `RetireSmartIRA/MultiYearPlanView.swift` (present the `YearDetailEditor` sheet; pass `projectedBeforeThisYear` via `ExpenseResolution` with the year's own override stripped)
- Test: `RetireSmartIRATests/LadderRowOverrideBadgeTests.swift`

**Interfaces:**
- Consumes: `YearDetailEditor` / `YearOverrideEditModel` (Task 6), `ExpenseResolution` (Task 4), `perYearOverrides` (Task 3).
- Produces: a per-row edit button + badge; tapping opens the editor for `row.year`.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/LadderRowOverrideBadgeTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("Ladder row override badge")
struct LadderRowOverrideBadgeTests {
    @Test("badge reflects a real override, not an empty/absent entry")
    func badge() {
        let real = YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: nil))
        let empty = YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: nil))
        #expect(LadderRow.hasOverride(year: 2030, overrides: [2030: real]))
        #expect(LadderRow.hasOverride(year: 2030, overrides: [2030: empty]) == false)
        #expect(LadderRow.hasOverride(year: 2031, overrides: [2030: real]) == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/LadderRowOverrideBadgeTests`
Expected: FAIL — `LadderRow.hasOverride` undefined.

- [ ] **Step 3: Write minimal implementation**

In `LadderRow.swift`, add:
```swift
/// True when `year` carries a real (non-empty) override — drives the row badge.
static func hasOverride(year: Int, overrides: [Int: YearOverride]) -> Bool {
    overrides[year]?.pruned != nil
}
```

In `MultiYearPlanSections.swift` ladder row view: add a trailing edit control (`Button { onEditYear(row.year) } label: { Image(systemName: "square.and.pencil") }`) and, when `LadderRow.hasOverride(year: row.year, overrides: overrides)`, a small badge (e.g. `Image(systemName: "pencil.circle.fill")` or a "Customized" capsule). Thread an `overrides: [Int: YearOverride]` and `onEditYear: (Int) -> Void` into the section view.

In `MultiYearPlanView.swift`: hold `@State private var editingYear: Int?`; `onEditYear = { editingYear = $0 }`; present `.sheet(item:)` (wrap the year in an `Identifiable` box) showing `YearDetailEditor` for that year. Compute `projectedBeforeThisYear` by resolving the expense with the year's OWN override removed:
```swift
func projectedBefore(_ year: Int) -> Double {
    var stripped = strategyManager.assumptions.perYearOverrides
    stripped[year] = nil
    return ExpenseResolution.expense(year: year, baseYear: dataManager.currentYear,
        baselineAnnualExpenses: strategyManager.assumptions.baselineAnnualExpenses,
        cpiRate: strategyManager.assumptions.cpiRate, overrides: stripped)
}
```
On save, write `editModel.resultingOverride` into `assumptions.perYearOverrides[year]` and re-assign `assumptions.perYearOverrides = assumptions.perYearOverrides.pruned()` so the plan recomputes and the badge updates.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/LadderRowOverrideBadgeTests`
Expected: PASS.

- [ ] **Step 5: Full suite + manual smoke**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
Expected: all green. Then launch the app (demo profile) and confirm: a year row shows the edit control; editing a one-time amount updates the ladder + badge; Clear removes it; opening + closing with no entry leaves no badge.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(overrides): per-year edit affordance + override badge in the Multi-Year ladder"
```

---

## Self-Review

**Spec coverage:**
- §2 model → Task 1. §3 model swap + schema + Codable + migration → Tasks 2, 3, 5. §3 persistence-version (one-way, defensive decode) → Task 3 + Task 5. §4 engine resolution (recurring + one-time + floor, worked example, nominal) → Task 4. §5 downstream (balances always / tax conditional, controlled profiles) → Task 4 Step 5. §6 UI (explicit affordance, badge on real overrides, read-only "Projected before this year's adjustments", pre-populate on reopen, no accidental overrides, prune) → Tasks 6, 7. §7 provenance → designed-only, no task (correct). §8 scope → Global Constraints. §9 tests → distributed across Tasks 1–7, incl. migration materially-different values + idempotency (Tasks 2, 5), validation/edge cases (Tasks 4, 6), coexistence (Task 4).
- Gap check: "clearing only one of two same-year values" (§9) — covered by Task 6 `buildsAndClears` (clearing one text field) + the prune semantics; if desired, add an explicit two-field clear assertion in Task 6.

**Placeholder scan:** No TBD/TODO; every code step carries real code. The SwiftUI sheet body and the row-view wiring (Tasks 6–7) are described concretely with the exact model API, control names, and state flow rather than full view source, matching how existing views are structured — acceptable, but the implementer follows the named interfaces exactly.

**Type consistency:** `FieldOverride`/`YearOverride` (Task 1) used identically in 2–7; `ExpenseResolution.expense(year:baseYear:baselineAnnualExpenses:cpiRate:overrides:)` defined Task 4, reused Tasks 6–7; `perYearOverrides`/`perYearOverridesSchema` defined Task 3, used 4–7; `upgradedOverrides(...)` Task 5; `YearOverrideEditModel` Task 6 used Task 7; `LadderRow.hasOverride(year:overrides:)` Task 7. Consistent.
