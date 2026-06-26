# Multi-Year Plan Tab — Thin MVP (Increment 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new additive "Multi-Year Plan" tab that renders the reconciled multi-year engine's recommended Roth-conversion ladder, a macro summary, and a selectable owner-vs-heirs trade-off frontier — surfacing the engine in the app for the first time.

**Architecture:** A `MultiYearPlanView` holds a `@StateObject MultiYearStrategyManager`, attaches the environment `DataManager` (+ `dataManager.scenario`) on appear, and renders manager state in a single scrolling column. All presentation logic lives in testable value-type structs; the views are thin renderers. Selecting a frontier weight drives the ladder/summary via per-weight paths retained in the frontier result. Scenarios + Tax Summary are untouched.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`@Test`/`@Suite`), Xcode `RetireSmartIRA.xcodeproj`, scheme `RetireSmartIRA`, native macOS + iOS. Build/test via `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-06-25-multi-year-plan-tab-mvp-design.md`

**Conventions:**
- Build app: `xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' -quiet`
- Run a suite: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/<Suite>`
- Full suite: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
- The Xcode project uses file-system-synchronized groups: new `.swift` files under `RetireSmartIRA/` (app) or `RetireSmartIRATests/` (tests) are auto-added to the target — no pbxproj editing.

---

## File Structure

- **Modify** `RetireSmartIRA/HeirFrontier.swift` — `FrontierPoint` gains `recommendedPath: [YearRecommendation]`.
- **Modify** `RetireSmartIRA/HeirFrontierCoordinator.swift` — retain each weight's path.
- **Modify** `RetireSmartIRA/MultiYearStrategyManager.swift` — frontier state + `computeHeirFrontier()` + `selectedHeirWeight`.
- **Create** `RetireSmartIRA/PlanSummary.swift` — testable macro-summary struct.
- **Create** `RetireSmartIRA/LadderRow.swift` — testable per-year display row.
- **Create** `RetireSmartIRA/HeirFrontierViewModel.swift` — testable frontier readout logic.
- **Create** `RetireSmartIRA/HeirFrontierView.swift` — the frontier section (SwiftUI).
- **Create** `RetireSmartIRA/MultiYearPlanSections.swift` — `AssumptionsStripView`, `PlanSummaryView`, `LadderListView` (SwiftUI).
- **Create** `RetireSmartIRA/MultiYearPlanView.swift` — the tab root (SwiftUI).
- **Modify** `RetireSmartIRA/ContentView.swift` — add tag-10 tab in the three tag→view sites.
- **Create** tests under `RetireSmartIRATests/` per task.

---

## Task 1: FrontierPoint carries each weight's recommended path

**Files:**
- Modify: `RetireSmartIRA/HeirFrontier.swift`
- Modify: `RetireSmartIRA/HeirFrontierCoordinator.swift`
- Test: `RetireSmartIRATests/FrontierPathRetentionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Frontier retains per-weight paths", .serialized)
@MainActor
struct FrontierPathRetentionTests {
    @Test("each frontier point carries the optimizer path for its weight")
    func pointsCarryPaths() {
        let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 88, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1938, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0, heirSalary: 150_000, heirFilingStatus: .single, heirDrawdownYears: 10)
        let a = MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
        let r = HeirFrontierCoordinator().computeFrontier(inputs: inputs, assumptions: a, configProvider: provider)
        // Every point has a non-empty path whose terminal trad matches what its heir tax implies.
        for p in r.points {
            #expect(!p.recommendedPath.isEmpty)
        }
        // The λ=0 point's path equals optimize(heirWeight: 0).
        let direct = OptimizationEngine().optimize(inputs: inputs, assumptions: a, configProvider: provider, heirWeight: 0)
        #expect(r.points.first(where: { $0.weight == 0 })?.recommendedPath.count == direct.recommendedPath.count)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/FrontierPathRetentionTests`
Expected: FAIL — `FrontierPoint` has no `recommendedPath` member (compile error).

- [ ] **Step 3: Add the field to FrontierPoint**

In `RetireSmartIRA/HeirFrontier.swift`, add the stored property to `FrontierPoint` (after `pvDiscountFactor`):

```swift
    let recommendedPath: [YearRecommendation]  // the optimizer's plan at this weight (drives the ladder/summary)
```

Add it to the `==` implementation:

```swift
    static func == (lhs: FrontierPoint, rhs: FrontierPoint) -> Bool {
        lhs.weight == rhs.weight
            && lhs.ownerLifetimeTaxToday == rhs.ownerLifetimeTaxToday
            && lhs.heirAfterTaxInheritanceToday == rhs.heirAfterTaxInheritanceToday
            && lhs.heirTaxToday == rhs.heirTaxToday
            && lhs.pvDiscountFactor == rhs.pvDiscountFactor
            && lhs.recommendedPath == rhs.recommendedPath
    }
```

- [ ] **Step 4: Populate it in the coordinator**

In `RetireSmartIRA/HeirFrontierCoordinator.swift`, inside the `.map { w in ... }` closure, pass the path into the `FrontierPoint(...)` it returns:

```swift
            return FrontierPoint(
                weight: w,
                ownerLifetimeTaxToday: inHorizonTax,
                heirAfterTaxInheritanceToday: heirKeeps,
                heirTaxToday: heirTax,
                pvDiscountFactor: pvFactor,
                recommendedPath: result.recommendedPath)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/FrontierPathRetentionTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/HeirFrontier.swift RetireSmartIRA/HeirFrontierCoordinator.swift RetireSmartIRATests/FrontierPathRetentionTests.swift
git commit -m "feat(frontier): retain per-weight recommended path on FrontierPoint"
```

---

## Task 2: Manager frontier state + background compute + selected weight

**Files:**
- Modify: `RetireSmartIRA/MultiYearStrategyManager.swift`
- Test: `RetireSmartIRATests/ManagerHeirFrontierTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Manager heir frontier compute", .serialized)
@MainActor
struct ManagerHeirFrontierTests {
    @Test("computeHeirFrontier populates six points")
    func computesFrontier() async {
        let dm = DataManager(skipPersistence: true)
        let mgr = MultiYearStrategyManager()
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)
        mgr.computeHeirFrontier()
        let deadline = Date().addingTimeInterval(20)
        while mgr.heirFrontier == nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(mgr.heirFrontier?.points.count == 6)
        #expect(mgr.selectedHeirWeight == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/ManagerHeirFrontierTests`
Expected: FAIL — `computeHeirFrontier` / `heirFrontier` / `selectedHeirWeight` undefined.

- [ ] **Step 3: Add the frontier API to the manager**

In `RetireSmartIRA/MultiYearStrategyManager.swift`, add published state near the other `@Published` properties (after `baselineProjection`):

```swift
    @Published private(set) var heirFrontier: HeirFrontierResult?
    @Published private(set) var isComputingFrontier: Bool = false
    @Published var selectedHeirWeight: Double = 0   // 0 = owner-optimal (today's recommendation)
    private var frontierWorkTask: Task<HeirFrontierResult, Never>?
```

Add the compute method (place it near `performCompute`). It mirrors the existing detached-work pattern and is cancellable:

```swift
    /// Compute the owner-vs-heirs trade-off frontier off the main actor and publish it.
    func computeHeirFrontier() {
        guard let dataManager, let scenarioStateManager else { return }
        let assumptions = self.assumptions
        let configProvider = self.configProvider
        let inputs = MultiYearInputAdapter.build(
            from: dataManager, scenarioState: scenarioStateManager,
            assumptions: assumptions, excludeYear1Overrides: false)
        isComputingFrontier = true
        frontierWorkTask?.cancel()
        let work = Task.detached(priority: .userInitiated) {
            HeirFrontierCoordinator().computeFrontier(
                inputs: inputs, assumptions: assumptions, configProvider: configProvider)
        }
        frontierWorkTask = work
        Task { @MainActor [weak self] in
            let result = await work.value
            guard let self, !Task.isCancelled, !work.isCancelled else { return }
            self.heirFrontier = result
            self.isComputingFrontier = false
        }
    }
```

> `dataManager` / `scenarioStateManager` are the manager's existing stored references set in `attach(...)`. Verify their exact names at execution (they are `private weak var dataManager`/`scenarioStateManager`). The `configProvider` property already exists.

Add `frontierWorkTask?.cancel()` to the existing `deinit`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/ManagerHeirFrontierTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/MultiYearStrategyManager.swift RetireSmartIRATests/ManagerHeirFrontierTests.swift
git commit -m "feat(manager): heir frontier state + background compute + selected weight"
```

---

## Task 3: PlanSummary (testable macro-summary struct)

**Files:**
- Create: `RetireSmartIRA/PlanSummary.swift`
- Test: `RetireSmartIRATests/PlanSummaryTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("PlanSummary", .serialized)
struct PlanSummaryTests {
    private func rec(year: Int, fed: Double, conv: Double) -> YearRecommendation {
        YearRecommendation(
            year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: TaxBreakdown(federal: fed, state: 0, irmaa: 0, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: conv > 0 ? [.rothConversion(amount: conv)] : [],
            medicareEnrolledCount: 0)
    }

    @Test("sums lifetime tax and total conversions over the path")
    func sums() {
        let path = [rec(year: 2026, fed: 10_000, conv: 50_000),
                    rec(year: 2027, fed: 12_000, conv: 30_000),
                    rec(year: 2028, fed: 8_000, conv: 0)]
        let s = PlanSummary(path: path)
        #expect(s.lifetimeTax == 30_000)
        #expect(s.totalConversions == 80_000)
        #expect(s.conversionYears == 2)
    }

    @Test("empty path is all zeros")
    func empty() {
        let s = PlanSummary(path: [])
        #expect(s.lifetimeTax == 0 && s.totalConversions == 0 && s.conversionYears == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/PlanSummaryTests`
Expected: FAIL — `PlanSummary` undefined.

- [ ] **Step 3: Create the struct**

Create `RetireSmartIRA/PlanSummary.swift`:

```swift
import Foundation

/// Testable macro-summary of a recommended multi-year path. Pure value type — the view formats it.
struct PlanSummary: Equatable, Sendable {
    let lifetimeTax: Double      // sum of in-horizon federal+state+IRMAA+ACA across the path
    let totalConversions: Double // sum of recommended Roth conversions
    let conversionYears: Int     // count of years with a conversion

    init(path: [YearRecommendation]) {
        self.lifetimeTax = path.reduce(0) { $0 + $1.taxBreakdown.total }
        var total = 0.0, years = 0
        for yr in path {
            let conv = yr.actions.reduce(0.0) { acc, act in
                if case let .rothConversion(amount) = act { return acc + amount }
                return acc
            }
            if conv > 0 { total += conv; years += 1 }
        }
        self.totalConversions = total
        self.conversionYears = years
    }

    /// One-line plain-language headline.
    var headline: String {
        guard totalConversions > 0 else { return "No Roth conversions recommended under these assumptions." }
        return "Convert \(Self.shortDollars(totalConversions)) over \(conversionYears) year\(conversionYears == 1 ? "" : "s")."
    }

    static func shortDollars(_ v: Double) -> String { "$\(Int((v / 1000).rounded()))k" }
}
```

> Confirm `TaxBreakdown.total` exists (it does — used by the optimizer). If absent, sum `federal+state+irmaa+acaPremiumImpact`.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/PlanSummaryTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/PlanSummary.swift RetireSmartIRATests/PlanSummaryTests.swift
git commit -m "feat(ui): PlanSummary macro-summary struct"
```

---

## Task 4: LadderRow (testable per-year display row)

**Files:**
- Create: `RetireSmartIRA/LadderRow.swift`
- Test: `RetireSmartIRATests/LadderRowTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("LadderRow", .serialized)
struct LadderRowTests {
    private func rec(year: Int, agi: Double, conv: Double, irmaaMagi: Double?, acaMagi: Double?) -> YearRecommendation {
        YearRecommendation(
            year: year, agi: agi, acaMagi: acaMagi, irmaaMagi: irmaaMagi, taxableIncome: agi,
            taxBreakdown: TaxBreakdown(federal: 0, state: 0, irmaa: irmaaMagi == nil ? 0 : 1, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: conv > 0 ? [.rothConversion(amount: conv)] : [],
            medicareEnrolledCount: irmaaMagi == nil ? 0 : 1)
    }

    @Test("row exposes year, conversion, agi and an IRMAA flag")
    func basics() {
        let row = LadderRow(rec(year: 2027, agi: 198_000, conv: 80_000, irmaaMagi: 198_000, acaMagi: nil))
        #expect(row.year == 2027)
        #expect(row.conversion == 80_000)
        #expect(row.agi == 198_000)
        #expect(row.hasIRMAASurcharge == true)
    }

    @Test("no conversion and no IRMAA reads clean")
    func clean() {
        let row = LadderRow(rec(year: 2030, agi: 60_000, conv: 0, irmaaMagi: nil, acaMagi: nil))
        #expect(row.conversion == 0)
        #expect(row.hasIRMAASurcharge == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/LadderRowTests`
Expected: FAIL — `LadderRow` undefined.

- [ ] **Step 3: Create the struct**

Create `RetireSmartIRA/LadderRow.swift`:

```swift
import Foundation

/// Testable display model for one year of the recommended ladder.
struct LadderRow: Identifiable, Equatable, Sendable {
    var id: Int { year }
    let year: Int
    let conversion: Double
    let agi: Double
    let hasIRMAASurcharge: Bool

    init(_ rec: YearRecommendation) {
        self.year = rec.year
        self.conversion = rec.actions.reduce(0.0) { acc, act in
            if case let .rothConversion(amount) = act { return acc + amount }
            return acc
        }
        self.agi = rec.agi
        self.hasIRMAASurcharge = rec.taxBreakdown.irmaa > 0
    }

    var conversionLabel: String { conversion > 0 ? "convert \(PlanSummary.shortDollars(conversion))" : "—" }
    var agiLabel: String { "AGI \(PlanSummary.shortDollars(agi))" }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/LadderRowTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/LadderRow.swift RetireSmartIRATests/LadderRowTests.swift
git commit -m "feat(ui): LadderRow per-year display model"
```

---

## Task 5: HeirFrontierViewModel (testable frontier readout)

**Files:**
- Create: `RetireSmartIRA/HeirFrontierViewModel.swift`
- Test: `RetireSmartIRATests/HeirFrontierViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("HeirFrontierViewModel", .serialized)
struct HeirFrontierViewModelTests {
    private func point(_ w: Double, owner: Double, heirs: Double) -> FrontierPoint {
        FrontierPoint(weight: w, ownerLifetimeTaxToday: owner, heirAfterTaxInheritanceToday: heirs,
            heirTaxToday: 0, pvDiscountFactor: 1, recommendedPath: [])
    }

    @Test("delta readout compares the selected point against the baseline")
    func deltaReadout() {
        let baseline = point(0, owner: 142_000, heirs: 610_000)
        let selected = point(0.5, owner: 168_000, heirs: 758_000)
        let vm = HeirFrontierViewModel(baseline: baseline, selected: selected, units: .todaysDollars)
        #expect(vm.ownerTaxDelta == 26_000)
        #expect(vm.heirInheritanceDelta == 148_000)
        #expect(vm.readoutText.contains("$26k"))
        #expect(vm.readoutText.contains("$148k"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/HeirFrontierViewModelTests`
Expected: FAIL — `HeirFrontierViewModel` undefined.

- [ ] **Step 3: Create the view-model**

Create `RetireSmartIRA/HeirFrontierViewModel.swift`:

```swift
import Foundation

/// Testable readout logic for the heir-frontier section (no SwiftUI).
struct HeirFrontierViewModel {
    let baseline: FrontierPoint
    let selected: FrontierPoint
    let units: DisplayUnits

    var ownerTaxDelta: Double {
        selected.ownerLifetimeTax(units: units) - baseline.ownerLifetimeTax(units: units)
    }
    var heirInheritanceDelta: Double {
        selected.heirAfterTaxInheritance(units: units) - baseline.heirAfterTaxInheritance(units: units)
    }
    var readoutText: String {
        let tax = PlanSummary.shortDollars(abs(ownerTaxDelta))
        let heir = PlanSummary.shortDollars(abs(heirInheritanceDelta))
        if selected.weight == baseline.weight {
            return "This is the plan optimized for your own lifetime tax."
        }
        return "Compared with planning only for yourself, this costs you \(tax) more in lifetime tax and leaves your heirs \(heir) more."
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/HeirFrontierViewModelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/HeirFrontierViewModel.swift RetireSmartIRATests/HeirFrontierViewModelTests.swift
git commit -m "feat(ui): HeirFrontierViewModel readout logic"
```

---

## Task 6: HeirFrontierView (frontier section, SwiftUI)

**Files:**
- Create: `RetireSmartIRA/HeirFrontierView.swift`
- Test: `RetireSmartIRATests/HeirFrontierViewConstructTests.swift`

- [ ] **Step 1: Write the failing test (constructs without crashing)**

```swift
import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("HeirFrontierView constructs", .serialized)
@MainActor
struct HeirFrontierViewConstructTests {
    @Test("builds from a frontier result")
    func builds() {
        let p = FrontierPoint(weight: 0, ownerLifetimeTaxToday: 1, heirAfterTaxInheritanceToday: 1,
            heirTaxToday: 0, pvDiscountFactor: 1, recommendedPath: [])
        let result = HeirFrontierResult(points: [p])
        var weight = 0.0
        var units = DisplayUnits.todaysDollars
        let view = HeirFrontierView(result: result,
            selectedWeight: Binding(get: { weight }, set: { weight = $0 }),
            units: Binding(get: { units }, set: { units = $0 }))
        #expect(view.body is (any View))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/HeirFrontierViewConstructTests`
Expected: FAIL — `HeirFrontierView` undefined.

- [ ] **Step 3: Create the view**

Create `RetireSmartIRA/HeirFrontierView.swift`:

```swift
import SwiftUI

struct HeirFrontierView: View {
    let result: HeirFrontierResult
    @Binding var selectedWeight: Double
    @Binding var units: DisplayUnits

    private var selected: FrontierPoint {
        result.points.first(where: { $0.weight == selectedWeight }) ?? result.points[0]
    }
    private var vm: HeirFrontierViewModel? {
        guard let baseline = result.baseline else { return nil }
        return HeirFrontierViewModel(baseline: baseline, selected: selected, units: units)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your taxes vs. what your heirs keep").font(.headline)
                Spacer()
                Picker("", selection: $units) {
                    Text("Today's $").tag(DisplayUnits.todaysDollars)
                    Text("Present value").tag(DisplayUnits.presentValue)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            ForEach(result.points) { p in
                Button {
                    selectedWeight = p.weight
                } label: {
                    HStack {
                        Text("\(Int(p.weight * 100))% to heirs")
                            .fontWeight(p.weight == selectedWeight ? .bold : .regular)
                        Spacer()
                        Text("You: \(PlanSummary.shortDollars(p.ownerLifetimeTax(units: units)))")
                            .foregroundStyle(.secondary)
                        Text("Heirs: \(PlanSummary.shortDollars(p.heirAfterTaxInheritance(units: units)))")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            if let vm {
                Text(vm.readoutText)
                    .font(.callout)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/HeirFrontierViewConstructTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/HeirFrontierView.swift RetireSmartIRATests/HeirFrontierViewConstructTests.swift
git commit -m "feat(ui): HeirFrontierView frontier section with units toggle"
```

---

## Task 7: MVP sections — AssumptionsStrip, PlanSummaryView, LadderListView

**Files:**
- Create: `RetireSmartIRA/MultiYearPlanSections.swift`
- Test: `RetireSmartIRATests/MultiYearPlanSectionsConstructTests.swift`

- [ ] **Step 1: Write the failing test (constructs)**

```swift
import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("MVP sections construct", .serialized)
@MainActor
struct MultiYearPlanSectionsConstructTests {
    @Test("plan summary + ladder build from a path")
    func build() {
        let rec = YearRecommendation(year: 2026, agi: 100_000, acaMagi: nil, irmaaMagi: nil,
            taxableIncome: 85_000, taxBreakdown: TaxBreakdown(federal: 1, state: 0, irmaa: 0, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: [.rothConversion(amount: 40_000)], medicareEnrolledCount: 0)
        let summary = PlanSummaryView(summary: PlanSummary(path: [rec]))
        let ladder = LadderListView(rows: [LadderRow(rec)])
        #expect(summary.body is (any View))
        #expect(ladder.body is (any View))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearPlanSectionsConstructTests`
Expected: FAIL — these views are undefined.

- [ ] **Step 3: Create the sections**

Create `RetireSmartIRA/MultiYearPlanSections.swift`:

```swift
import SwiftUI

/// Editable strip for the inputs with no home elsewhere. Mutates the bound assumptions and
/// triggers a recompute via the closure.
struct AssumptionsStripView: View {
    @Binding var taxableBalance: Double
    @Binding var hsaBalance: Double
    @Binding var horizonEndAge: Int
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assumptions").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                LabeledContent("Taxable balance") {
                    TextField("0", value: $taxableBalance, format: .number).multilineTextAlignment(.trailing)
                }
                LabeledContent("HSA balance") {
                    TextField("0", value: $hsaBalance, format: .number).multilineTextAlignment(.trailing)
                }
            }
            Stepper("Plan through age \(horizonEndAge)", value: $horizonEndAge, in: 70...110)
        }
        .onChange(of: taxableBalance) { _, _ in onCommit() }
        .onChange(of: hsaBalance) { _, _ in onCommit() }
        .onChange(of: horizonEndAge) { _, _ in onCommit() }
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlanSummaryView: View {
    let summary: PlanSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your plan").font(.headline)
            Text("Projected lifetime tax: \(PlanSummary.shortDollars(summary.lifetimeTax))")
            Text(summary.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LadderListView: View {
    let rows: [LadderRow]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recommended ladder").font(.headline)
            ForEach(rows) { row in
                HStack {
                    Text(String(row.year)).monospacedDigit()
                    Text(row.conversionLabel)
                    Spacer()
                    Text(row.agiLabel).foregroundStyle(.secondary)
                    if row.hasIRMAASurcharge {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                .font(.callout)
            }
        }
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearPlanSectionsConstructTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/MultiYearPlanSections.swift RetireSmartIRATests/MultiYearPlanSectionsConstructTests.swift
git commit -m "feat(ui): assumptions strip, plan summary, ladder list sections"
```

---

## Task 8: MultiYearPlanView (the tab root)

**Files:**
- Create: `RetireSmartIRA/MultiYearPlanView.swift`
- Test: `RetireSmartIRATests/MultiYearPlanViewConstructTests.swift`

- [ ] **Step 1: Write the failing test (constructs with a DataManager in the environment)**

```swift
import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("MultiYearPlanView constructs", .serialized)
@MainActor
struct MultiYearPlanViewConstructTests {
    @Test("builds")
    func builds() {
        let view = MultiYearPlanView().environment(DataManager(skipPersistence: true))
        #expect(view is (any View))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearPlanViewConstructTests`
Expected: FAIL — `MultiYearPlanView` undefined.

- [ ] **Step 3: Create the tab root**

Create `RetireSmartIRA/MultiYearPlanView.swift`:

```swift
import SwiftUI

struct MultiYearPlanView: View {
    @Environment(DataManager.self) private var dataManager
    @StateObject private var manager = MultiYearStrategyManager()
    @State private var attached = false

    // Selected weight's path (drives summary + ladder). Falls back to currentResult.
    private var activePath: [YearRecommendation] {
        if let p = manager.heirFrontier?.points.first(where: { $0.weight == manager.selectedHeirWeight })?.recommendedPath, !p.isEmpty {
            return p
        }
        return manager.currentResult?.recommendedPath ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Multi-Year Plan").font(.largeTitle.bold())

                AssumptionsStripView(
                    taxableBalance: Binding(get: { manager.assumptions.currentTaxableBalance },
                                            set: { manager.assumptions.currentTaxableBalance = $0 }),
                    hsaBalance: Binding(get: { manager.assumptions.currentHSABalance },
                                        set: { manager.assumptions.currentHSABalance = $0 }),
                    horizonEndAge: Binding(get: { manager.assumptions.horizonEndAge },
                                           set: { manager.assumptions.horizonEndAge = $0 }),
                    onCommit: { recomputeAll() })

                if manager.isComputing && manager.currentResult == nil {
                    ProgressView("Computing your plan…").frame(maxWidth: .infinity).padding()
                } else if activePath.isEmpty {
                    ContentUnavailableView("Set your assumptions to see your plan",
                        systemImage: "calendar.badge.clock")
                } else {
                    PlanSummaryView(summary: PlanSummary(path: activePath))
                    LadderListView(rows: activePath.map(LadderRow.init))
                    if let frontier = manager.heirFrontier {
                        HeirFrontierView(result: frontier,
                            selectedWeight: Binding(get: { manager.selectedHeirWeight },
                                                    set: { manager.selectedHeirWeight = $0 }),
                            units: $units)
                    } else if manager.isComputingFrontier {
                        ProgressView("Computing heir trade-off…")
                    }
                }
            }
            .padding()
        }
        .task {
            guard !attached else { return }
            attached = true
            manager.attach(dataManager: dataManager, scenarioStateManager: dataManager.scenario)
            recomputeAll()
        }
    }

    @State private var units: DisplayUnits = .todaysDollars

    private func recomputeAll() {
        manager.recompute(reason: .assumptionsChanged)
        manager.computeHeirFrontier()
    }
}
```

> Verify at execution: `manager.attach` parameter labels, `dataManager.scenario` accessor, and that `currentTaxableBalance`/`currentHSABalance`/`horizonEndAge` are mutable on `manager.assumptions` (they are `var`).

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearPlanViewConstructTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/MultiYearPlanView.swift RetireSmartIRATests/MultiYearPlanViewConstructTests.swift
git commit -m "feat(ui): MultiYearPlanView tab root wiring engine -> sections"
```

---

## Task 9: Wire the tab into ContentView (3 sites) + product-principle guard

**Files:**
- Modify: `RetireSmartIRA/ContentView.swift`
- Test: `RetireSmartIRATests/MultiYearTabWiringTests.swift`

- [ ] **Step 1: Add the tab to the three tag→view sites**

In `RetireSmartIRA/ContentView.swift`:

(a) macOS sidebar "Analysis" section — add after the Tax Summary label (tag 6):
```swift
                    Label("Multi-Year Plan", systemImage: "chart.line.uptrend.xyaxis")
                        .tag(10)
```
(b) macOS detail `switch selectedTab` — add a case:
```swift
        case 10: MultiYearPlanView()
```
(c) iPad sidebar "Analysis" section — add the same Label (tag 10).
(d) iPad detail `switch sidebarSelection` — add `case 10: MultiYearPlanView()`.
(e) iOS compact `tabBody` TabView — add a tab matching the existing pattern there:
```swift
                MultiYearPlanView()
                    .tabItem { Label("Plan", systemImage: "chart.line.uptrend.xyaxis") }
                    .tag(10)
```

> Re-verify the exact surrounding syntax at execution — match the file's existing Label/tabItem style at each site. Do NOT alter the Scenarios (tag 5) or Tax Summary (tag 6) entries.

- [ ] **Step 2: Write the product-principle guard test**

```swift
import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("Multi-year tab is additive", .serialized)
@MainActor
struct MultiYearTabWiringTests {
    // The single-year views still exist and construct unchanged (augment, not supplant).
    @Test("Scenarios and Tax Summary views still build")
    func singleYearIntact() {
        let dm = DataManager(skipPersistence: true)
        #expect(TaxPlanningView().environment(dm) is (any View))   // tag 5 (Scenarios)
        #expect(DashboardView().environment(dm) is (any View))     // tag 6 (Tax Summary)
        #expect(MultiYearPlanView().environment(dm) is (any View)) // tag 10 (new)
    }
}
```

- [ ] **Step 3: Build + run the guard test**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/MultiYearTabWiringTests`
Expected: PASS (and the app compiles with the new tab in all three sites).

- [ ] **Step 4: Run the FULL suite**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
Expected: PASS — all prior tests + the new ones. Investigate any regression; do not weaken assertions.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/ContentView.swift RetireSmartIRATests/MultiYearTabWiringTests.swift
git commit -m "feat(ui): add additive Multi-Year Plan tab to ContentView (all 3 sites)"
```

---

## Task 10: Run the app and verify end-to-end

**Files:** none (manual/agent verification — the integration payoff).

- [ ] **Step 1: Launch the macOS app**

Use the `run` skill (or `xcodebuild build` then launch the product). Open the **Multi-Year Plan** tab.

- [ ] **Step 2: Verify the integration**

Confirm, with a screenshot: assumptions strip is editable; on edit the plan recomputes (loading → result); the recommended ladder renders real years/conversions; the heir frontier shows six weights and the today's-$/PV toggle; selecting a weight updates the ladder + summary. Confirm Scenarios and Tax Summary tabs still work and are unchanged.

- [ ] **Step 3: Record the result**

Note any integration issues found (this is the whole point of the thin MVP). File follow-ups for anything cosmetic; fix anything functional before declaring increment 1 done.

---

## Self-Review Notes (for the implementer)

- **Signatures to re-verify at execution:** `MultiYearStrategyManager.attach(dataManager:scenarioStateManager:)`, the manager's `dataManager`/`scenarioStateManager`/`configProvider` stored-property names, `dataManager.scenario`, `TaxBreakdown.total`, and the three ContentView tag→view sites.
- **No "optimal" claims without "under these assumptions"** in any user-facing copy (PlanSummary.headline and the frontier readout already follow this).
- **Augment, not supplant:** never edit the Scenarios (tag 5) or Tax Summary (tag 6) entries — only add tag 10.
