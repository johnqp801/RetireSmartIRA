# Plan-vs-Nothing Explainability Block Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Your plan vs. doing nothing" comparison block to the Multi-Year Plan tab that shows lifetime tax, ending IRA balance, what heirs keep, and peak forced RMD for the recommended plan versus the no-conversion baseline.

**Architecture:** The engine already computes and publishes the no-conversion `baselineProjection`. We surface the forced RMD per year as a new `YearRecommendation.rmd` field, add a pure `PlanComparison` value type that derives four metric-pairs from the two paths (reusing the existing `LegacyPlanningEngine` heir-tax calc), and render it with a dumb `PlanComparisonView` placed between the summary and the ladder.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`@Test`/`@Suite`/`#expect`). Native macOS target. Build/test via `xcodebuild ... -destination 'platform=macOS'`. New `.swift` files under `RetireSmartIRA/` and `RetireSmartIRATests/` auto-join the targets (file-system-synchronized groups; no pbxproj edits).

**Working directory:** `/Users/johnurban/Projects/RetireSmartIRA/.worktrees/2.0-reconcile-engine` (branch `2.0/heir-objective`). `cd` here for every command.

---

## File Structure

- Modify `RetireSmartIRA/YearRecommendation.swift` — add `rmd: Double` (default 0).
- Modify `RetireSmartIRA/ProjectionEngine.swift:688` — populate `rmd` at construction.
- Create `RetireSmartIRA/PlanComparison.swift` — pure value type, four metric pairs + headline.
- Modify `RetireSmartIRA/MultiYearPlanSections.swift` — add `PlanComparisonView`.
- Modify `RetireSmartIRA/MultiYearPlanView.swift` — render the section under the summary.
- Create `RetireSmartIRATests/PlanComparisonTests.swift`.
- Create `RetireSmartIRATests/RMDFieldTests.swift`.

---

## Task 1: Add `rmd` field to YearRecommendation

**Files:**
- Modify: `RetireSmartIRA/YearRecommendation.swift`
- Test: `RetireSmartIRATests/RMDFieldTests.swift` (create)

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/RMDFieldTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("YearRecommendation.rmd field")
struct RMDFieldTests {
    private func sampleBreakdown() -> TaxBreakdown { .zero }
    private func sampleSnapshot() -> AccountSnapshot {
        AccountSnapshot(primaryTraditional: 0, spouseTraditional: 0, roth: 0, taxable: 0, hsa: 0)
    }

    @Test("rmd defaults to 0 when omitted (back-compat)")
    func defaultsToZero() {
        let yr = YearRecommendation(
            year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: sampleBreakdown(), endOfYearBalances: sampleSnapshot(), actions: [])
        #expect(yr.rmd == 0)
    }

    @Test("rmd is retained when supplied")
    func retainsValue() {
        let yr = YearRecommendation(
            year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: sampleBreakdown(), endOfYearBalances: sampleSnapshot(), actions: [],
            rmd: 40_650)
        #expect(yr.rmd == 40_650)
    }
}
```

> NOTE: Labels verified against source: `TaxBreakdown.zero` and `AccountSnapshot(primaryTraditional:spouseTraditional:roth:taxable:hsa:)` are real. Do not change the two `YearRecommendation(...)` calls.

- [ ] **Step 2: Run the test, expect FAIL (extra `rmd:` argument)**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/RMDFieldTests 2>&1 | tail -20`
Expected: compile failure — `extra argument 'rmd' in call`.

- [ ] **Step 3: Add the field**

In `RetireSmartIRA/YearRecommendation.swift`, after the `underfunded` stored property (line 27):

```swift
    /// Forced required minimum distribution for this year (primary + spouse), pre-tax.
    /// 0 before RMD age. Surfaced separately so the UI can show forced income without
    /// digging it out of the bundled `.traditionalWithdrawal` actions.
    let rmd: Double
```

Add the init parameter after `underfunded: Double? = nil` (line 39):

```swift
        underfunded: Double? = nil,
        rmd: Double = 0
```

Add the assignment after `self.underfunded = underfunded` (line 50):

```swift
        self.rmd = rmd
```

- [ ] **Step 4: Run the test, expect PASS**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/RMDFieldTests 2>&1 | tail -10`
Expected: `Test run with 2 tests ... passed`.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/YearRecommendation.swift RetireSmartIRATests/RMDFieldTests.swift
git commit -m "feat(engine): YearRecommendation.rmd field (default 0)"
```

---

## Task 2: Populate `rmd` in ProjectionEngine

**Files:**
- Modify: `RetireSmartIRA/ProjectionEngine.swift:688`
- Test: `RetireSmartIRATests/RMDFieldTests.swift` (extend)

Context: in the per-year loop, `primaryRequiredRMD` and `spouseRequiredRMD` are already computed (lines 161-170) and in scope at the `YearRecommendation(...)` construction (line 688). The sum is the year's forced RMD.

- [ ] **Step 1: Write the failing test (extend RMDFieldTests)**

Append this suite to `RetireSmartIRATests/RMDFieldTests.swift`:

```swift
@Suite("ProjectionEngine populates rmd", .serialized)
@MainActor
struct RMDPopulationTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func inputs(age: Int, birthYear: Int, trad: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: 5_000_000, hsa: 0),
            baseYear: 2026, primaryCurrentAge: age, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: birthYear, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(horizonEndAge: 80, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 5_000_000, currentHSABalance: 0)
    }
    private func emptyActions(_ inp: MultiYearStaticInputs, _ a: MultiYearAssumptions) -> [Int: [LeverAction]] {
        var m: [Int: [LeverAction]] = [:]
        for y in inp.baseYear...(inp.baseYear + a.horizonEndAge - inp.primaryCurrentAge) { m[y] = [] }
        return m
    }

    @Test("year-1 rmd equals the IRS RMD for an RMD-age owner")
    func rmdPopulatedAtAge() {
        let inp = inputs(age: 75, birthYear: 1951, trad: 1_000_000)   // rmdAge 73 → applies
        let a = assumptions()
        let path = ProjectionEngine(configProvider: provider).project(
            inputs: inp, assumptions: a, actionsPerYear: emptyActions(inp, a))
        let expected = RMDCalculationEngine.calculateRMD(for: 75, balance: 1_000_000)
        #expect(abs((path.first?.rmd ?? -1) - expected) < 1.0)
        #expect(expected > 0)
    }

    @Test("rmd is 0 before RMD age")
    func rmdZeroBeforeAge() {
        let inp = inputs(age: 70, birthYear: 1956, trad: 1_000_000)   // rmdAge 73 → not yet
        let a = assumptions()
        let path = ProjectionEngine(configProvider: provider).project(
            inputs: inp, assumptions: a, actionsPerYear: emptyActions(inp, a))
        #expect(path.first?.rmd == 0)
    }
}
```

> NOTE: `MultiYearStaticInputs` here uses the shorter `AccountSnapshot(traditional:roth:taxable:hsa:)` convenience form used throughout `RealismRegressionTests.swift`/`ObjectivePVTests.swift`. If the compiler rejects any label, open `RetireSmartIRA/MultiYearStaticInputs.swift` and `RetireSmartIRA/AccountSnapshot.swift` and match the real labels exactly — keep the values identical.

- [ ] **Step 2: Run, expect FAIL** (`rmd` is still 0 because the engine never sets it)

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/RMDPopulationTests 2>&1 | tail -20`
Expected: `rmdPopulatedAtAge` FAILS (`path.first?.rmd` is 0, expected ~40650).

- [ ] **Step 3: Populate the field**

In `RetireSmartIRA/ProjectionEngine.swift`, in the `YearRecommendation(...)` construction at line 688, add a final argument after `underfunded: underfundedTax > 0 ? underfundedTax : nil` (line 698):

```swift
                underfunded: underfundedTax > 0 ? underfundedTax : nil,
                rmd: primaryRequiredRMD + spouseRequiredRMD
```

- [ ] **Step 4: Run, expect PASS**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/RMDPopulationTests 2>&1 | tail -10`
Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/ProjectionEngine.swift RetireSmartIRATests/RMDFieldTests.swift
git commit -m "feat(engine): populate YearRecommendation.rmd from per-spouse required RMDs"
```

---

## Task 3: `PlanComparison` value type

**Files:**
- Create: `RetireSmartIRA/PlanComparison.swift`
- Test: `RetireSmartIRATests/PlanComparisonTests.swift` (create)

- [ ] **Step 1: Write the failing test**

Create `RetireSmartIRATests/PlanComparisonTests.swift`:

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("PlanComparison")
struct PlanComparisonTests {
    private func breakdown(total: Double) -> TaxBreakdown {
        TaxBreakdown(federal: total, state: 0, irmaa: 0, acaPremiumImpact: 0)
    }
    private func snapshot(trad: Double, roth: Double) -> AccountSnapshot {
        AccountSnapshot(primaryTraditional: trad, spouseTraditional: 0, roth: roth, taxable: 0, hsa: 0)
    }
    private func yr(_ year: Int, tax: Double, trad: Double, roth: Double, rmd: Double) -> YearRecommendation {
        YearRecommendation(
            year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: breakdown(total: tax), endOfYearBalances: snapshot(trad: trad, roth: roth),
            actions: [], rmd: rmd)
    }

    @Test("derives the four metric pairs from plan and baseline")
    func metrics() {
        // plan: pays more tax early, ends with a small trad balance, small RMDs
        let plan = [
            yr(2026, tax: 100_000, trad: 800_000, roth: 100_000, rmd: 10_000),
            yr(2027, tax: 100_000, trad: 400_000, roth: 200_000, rmd: 20_000),
        ]
        // doing nothing: less tax early, ends with a big trad balance, big RMDs
        let nothing = [
            yr(2026, tax: 40_000, trad: 1_500_000, roth: 0, rmd: 30_000),
            yr(2027, tax: 50_000, trad: 1_800_000, roth: 0, rmd: 90_000),
        ]
        let c = PlanComparison(plan: plan, doingNothing: nothing,
                               heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)

        #expect(c.lifetimeTax.plan == 200_000)
        #expect(c.lifetimeTax.doingNothing == 90_000)
        #expect(c.endingTraditional.plan == 400_000)
        #expect(c.endingTraditional.doingNothing == 1_800_000)
        #expect(c.peakForcedRMD.plan == 20_000)
        #expect(c.peakForcedRMD.doingNothing == 90_000)

        // heirsKeep == ending roth + (ending trad - heir tax), using the same engine calc.
        let planHeirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
            balance: 400_000, heirSalary: 75_000, heirFilingStatus: .single, drawdownYears: 10)
        #expect(abs(c.heirsKeep.plan - (200_000 + (400_000 - planHeirTax))) < 1.0)
    }

    @Test("empty paths yield zero pairs")
    func emptyPaths() {
        let c = PlanComparison(plan: [], doingNothing: [],
                               heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
        #expect(c.lifetimeTax.plan == 0)
        #expect(c.endingTraditional.doingNothing == 0)
        #expect(c.peakForcedRMD.plan == 0)
    }
}
```

> NOTE: `TaxBreakdown(federal:state:irmaa:acaPremiumImpact:)` and `LegacyPlanningEngine.heirTaxOnInheritedTraditional(balance:heirSalary:heirFilingStatus:drawdownYears:)` are verified against source (`MultiYearValueTypes.swift`, `HeirFrontierCoordinator.swift:40`).

- [ ] **Step 2: Run, expect FAIL** (`PlanComparison` undefined)

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/PlanComparisonTests 2>&1 | tail -20`
Expected: compile failure — `cannot find 'PlanComparison' in scope`.

- [ ] **Step 3: Implement**

Create `RetireSmartIRA/PlanComparison.swift`:

```swift
import Foundation

/// Testable "your plan vs. doing nothing" comparison for the Multi-Year Plan tab.
/// Pure value type — the view formats it. "doingNothing" is the engine's no-conversion baseline.
struct PlanComparison: Equatable, Sendable {

    /// One metric under both paths. Display orientation (lower-is-better vs higher-is-better)
    /// is the view's concern; this type only carries the two values.
    struct Pair: Equatable, Sendable {
        let plan: Double
        let doingNothing: Double
    }

    let lifetimeTax: Pair        // lower is better
    let endingTraditional: Pair  // lower is better (defused RMD bomb)
    let heirsKeep: Pair          // higher is better
    let peakForcedRMD: Pair      // lower is better

    init(plan: [YearRecommendation],
         doingNothing: [YearRecommendation],
         heirSalary: Double,
         heirFilingStatus: FilingStatus,
         heirDrawdownYears: Int) {

        func lifetimeTax(_ p: [YearRecommendation]) -> Double {
            p.reduce(0) { $0 + $1.taxBreakdown.total }
        }
        func endingTrad(_ p: [YearRecommendation]) -> Double {
            guard let last = p.last else { return 0 }
            return last.endOfYearBalances.primaryTraditional + last.endOfYearBalances.spouseTraditional
        }
        func endingRoth(_ p: [YearRecommendation]) -> Double { p.last?.endOfYearBalances.roth ?? 0 }
        func heirsKeep(_ p: [YearRecommendation]) -> Double {
            let trad = endingTrad(p)
            let heirTax = LegacyPlanningEngine.heirTaxOnInheritedTraditional(
                balance: trad, heirSalary: heirSalary,
                heirFilingStatus: heirFilingStatus, drawdownYears: heirDrawdownYears)
            return endingRoth(p) + (trad - heirTax)
        }
        func peakRMD(_ p: [YearRecommendation]) -> Double { p.map(\.rmd).max() ?? 0 }

        self.lifetimeTax = Pair(plan: lifetimeTax(plan), doingNothing: lifetimeTax(doingNothing))
        self.endingTraditional = Pair(plan: endingTrad(plan), doingNothing: endingTrad(doingNothing))
        self.heirsKeep = Pair(plan: heirsKeep(plan), doingNothing: heirsKeep(doingNothing))
        self.peakForcedRMD = Pair(plan: peakRMD(plan), doingNothing: peakRMD(doingNothing))
    }

    /// Lifetime-tax reduction vs doing nothing (positive = plan saves money).
    var lifetimeTaxSavings: Double { lifetimeTax.doingNothing - lifetimeTax.plan }

    /// One-line plain-language headline. Uses the existing compact-dollar formatter.
    var headline: String {
        guard lifetimeTaxSavings > 1_000 else {
            return "This plan comes out about even with doing nothing here."
        }
        return "This plan saves \(PlanSummary.shortDollars(lifetimeTaxSavings)) in lifetime tax and holds your largest forced RMD to \(PlanSummary.shortDollars(peakForcedRMD.plan))."
    }
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/PlanComparisonTests 2>&1 | tail -10`
Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/PlanComparison.swift RetireSmartIRATests/PlanComparisonTests.swift
git commit -m "feat: PlanComparison value type (plan vs no-conversion baseline)"
```

---

## Task 4: `PlanComparisonView` + wire into the tab

**Files:**
- Modify: `RetireSmartIRA/MultiYearPlanSections.swift`
- Modify: `RetireSmartIRA/MultiYearPlanView.swift`

- [ ] **Step 1: Add the view**

In `RetireSmartIRA/MultiYearPlanSections.swift`, append after `PlanSummaryView` (after line 42):

```swift
struct PlanComparisonView: View {
    let comparison: PlanComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your plan vs. doing nothing").font(.headline)
            Text(comparison.headline).font(.callout).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("")
                    Text("Your plan").font(.caption.bold()).gridColumnAlignment(.trailing)
                    Text("Doing nothing").font(.caption.bold()).gridColumnAlignment(.trailing)
                }
                metricRow("Lifetime tax", comparison.lifetimeTax)
                metricRow("Ending IRA balance", comparison.endingTraditional)
                metricRow("What heirs keep", comparison.heirsKeep)
                metricRow("Peak forced RMD", comparison.peakForcedRMD)
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metricRow(_ label: String, _ pair: PlanComparison.Pair) -> some View {
        GridRow {
            Text(label)
            Text(PlanSummary.shortDollars(pair.plan))
                .monospacedDigit().gridColumnAlignment(.trailing)
            Text(PlanSummary.shortDollars(pair.doingNothing))
                .monospacedDigit().foregroundStyle(.secondary).gridColumnAlignment(.trailing)
        }
    }
}
```

- [ ] **Step 2: Render it in the tab**

In `RetireSmartIRA/MultiYearPlanView.swift`, replace the line `PlanSummaryView(summary: PlanSummary(path: activePath))` (line 37) with:

```swift
                    PlanSummaryView(summary: PlanSummary(path: activePath))
                    if let baseline = manager.baselineProjection, !baseline.isEmpty {
                        PlanComparisonView(comparison: PlanComparison(
                            plan: activePath,
                            doingNothing: baseline,
                            heirSalary: dataManager.legacyHeirEstimatedSalary,
                            heirFilingStatus: dataManager.legacyHeirFilingStatus,
                            heirDrawdownYears: dataManager.legacyDrawdownYears))
                    }
```

> NOTE: Confirm the three DataManager accessors exist with these exact names — they are used in `MultiYearInputAdapter.build` (`dataManager.legacyHeirEstimatedSalary`, `dataManager.legacyHeirFilingStatus`, `dataManager.legacyDrawdownYears`). If any name differs, match the adapter.

- [ ] **Step 3: Build (no unit test for the view; logic is covered in Task 3)**

Run: `xcodebuild -scheme RetireSmartIRA -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRA/MultiYearPlanSections.swift RetireSmartIRA/MultiYearPlanView.swift
git commit -m "feat(ui): plan-vs-doing-nothing comparison block on Multi-Year Plan tab"
```

---

## Task 5: Full suite green + launch the rebuilt app

**Files:** none (verification).

- [ ] **Step 1: Run the full suite**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | grep -E '✘|Test run with' | tail -10`
Expected: all pass (1071 prior + the new tests). No `✘`. If any pre-existing golden moved because `rmd` is now non-zero in a verbatim-equality test, treat it the same way as the realism re-baseline: confirm it is a value shift (not a structural break), update the literal, and note it. RMD is a NEW field, so equality tests that build `YearRecommendation` directly should be unaffected (default 0); only tests that deep-compare engine output paths could move.

- [ ] **Step 2: Rebuild and launch the macOS app for manual confirmation**

```bash
xcodebuild -scheme RetireSmartIRA -destination 'platform=macOS' build 2>&1 | tail -3
APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*Build/Products/Debug/RetireSmartIRA.app" -prune 2>/dev/null | head -1)
osascript -e 'quit app "RetireSmartIRA"' 2>/dev/null; sleep 1; open "$APP"
```

- [ ] **Step 3: Confirm on the Multi-Year Plan tab**

The comparison block appears under "Your plan", above "Recommended ladder", with four rows (Lifetime tax, Ending IRA balance, What heirs keep, Peak forced RMD) showing two columns, and a headline that states the lifetime-tax savings. For the canonical scenario the "doing nothing" ending IRA balance should be visibly larger than the plan's, and the plan's peak forced RMD visibly smaller. (Manual eyeball — no automated assertion.)

---

## Self-Review Notes

- **Spec coverage:** rmd field (Task 1) + population (Task 2); four metrics in `PlanComparison` (Task 3) covering lifetime tax, ending IRA, heirs-keep via the existing engine calc, peak forced RMD; view + placement under summary (Task 4); full green + manual confirm (Task 5). Non-goals (PV toggle, per-year why, charts) intentionally absent.
- **Type consistency:** `PlanComparison.Pair`, `lifetimeTax`/`endingTraditional`/`heirsKeep`/`peakForcedRMD`, `PlanComparison(plan:doingNothing:heirSalary:heirFilingStatus:heirDrawdownYears:)`, and `YearRecommendation.rmd` are used identically across tasks. `PlanSummary.shortDollars` is reused for formatting. `LegacyPlanningEngine.heirTaxOnInheritedTraditional(balance:heirSalary:heirFilingStatus:drawdownYears:)` matches `HeirFrontierCoordinator.swift:40`.
- **Type labels verified against source:** `TaxBreakdown(federal:state:irmaa:acaPremiumImpact:)` with `.zero` and `.total` (`MultiYearValueTypes.swift`); `AccountSnapshot` has both `(primaryTraditional:spouseTraditional:roth:taxable:hsa:)` and the `(traditional:roth:taxable:hsa:)` convenience (`AccountSnapshot.swift`); `LegacyPlanningEngine.heirTaxOnInheritedTraditional(balance:heirSalary:heirFilingStatus:drawdownYears:)` (`HeirFrontierCoordinator.swift:40`); `RMDCalculationEngine.calculateRMD(for:balance:)` (`ProjectionEngine.swift:164`). The test helpers in this plan already use these exact forms.
