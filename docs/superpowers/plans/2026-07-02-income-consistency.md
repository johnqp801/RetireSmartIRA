# Income Consistency + Input-Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the household's income read consistently across tabs (one labeled reconciliation chain instead of four contradictory totals), reconcile the legacy taxable toggle with first-class taxable accounts, add missing-input nudges to Multi-Year, and signal the investment-income supersede.

**Architecture:** A pure `IncomeBreakdown` value type composes existing `DataManager` income figures into a labeled chain (sources → +inherited RMD → taxable → +scenario). Each single-year tab reads its headline from that one model with a precise label and a shared "show how this is computed" expander. No `TaxCalculationEngine`/`ProjectionEngine` change — this is representation + labeling.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing (`@Suite`/`@Test`/`#expect`), Xcode. Native macOS 15 + iOS 18.

**Spec:** `docs/superpowers/specs/2026-07-02-income-consistency-design.md`

## Global Constraints
- Branch `2.0/heir-objective` (worktree `.worktrees/2.0-reconcile-engine`). Full suite must stay green (~1155): `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`. Single suite: `-only-testing:RetireSmartIRATests/<StructName>` (matches the test STRUCT type name, not the `@Suite` display string).
- No em dash characters in any user-facing copy.
- No change to `TaxCalculationEngine` or `ProjectionEngine` math. Displayed numbers must be unchanged; only labels + sourcing change.
- Pure value types carry no SwiftUI/DataManager deps.
- Commit after each task. Trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## Phase 1 — Canonical income model

### Task 1: `IncomeBreakdown` value type

**Files:**
- Create: `RetireSmartIRA/IncomeBreakdown.swift`
- Test: `RetireSmartIRATests/IncomeBreakdownTests.swift`

**Interfaces:**
- Produces: `struct IncomeBreakdown: Equatable, Sendable` with `allSources`, `totalWithRMDs`, `taxableFromSources`, `grossWithScenario: Double`, and `steps: [Step]` where `struct Step: Identifiable, Equatable, Sendable { let id: Int; let label: String; let amount: Double; let isSubtotal: Bool }`. Init: `init(allSources:inheritedRMD:taxExempt:taxableFromSources:scenarioAdditions:grossWithScenario:)`.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/IncomeBreakdownTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("IncomeBreakdown")
struct IncomeBreakdownTests {
    @Test("composes the labeled chain and exposes each tab's canonical value")
    func chain() {
        let b = IncomeBreakdown(
            allSources: 176_054, inheritedRMD: 11_363, taxExempt: 46_927,
            taxableFromSources: 140_490, scenarioAdditions: 84_009, grossWithScenario: 224_499)
        #expect(b.allSources == 176_054)
        #expect(b.totalWithRMDs == 187_417)              // allSources + inheritedRMD
        #expect(b.taxableFromSources == 140_490)
        #expect(b.grossWithScenario == 224_499)
        // Steps: labeled chain with three subtotals, no em dash.
        #expect(b.steps.count == 7)
        #expect(b.steps.filter(\.isSubtotal).map(\.label) == [
            "Total income (sources + RMDs)", "Taxable income from sources", "Gross income (with scenario)"])
        #expect(b.steps.first?.label == "Income from all sources")
        #expect(b.steps.contains { $0.label == "Less tax-exempt interest" && $0.amount == -46_927 })
        #expect(b.steps.allSatisfy { !$0.label.contains("\u{2014}") })
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/IncomeBreakdownTests 2>&1 | tail -15`
Expected: FAIL (type undefined).

- [ ] **Step 3: Implement the model**

```swift
// RetireSmartIRA/IncomeBreakdown.swift
import Foundation

/// Single source of truth for the single-year income "chain" shown on the Income, Tax Summary,
/// Scenarios, and Quarterly tabs. Composes existing DataManager figures so every tab reads the same
/// numbers under precise, self-explanatory labels (fixes the "four different income totals" problem).
struct IncomeBreakdown: Equatable, Sendable {
    struct Step: Identifiable, Equatable, Sendable {
        let id: Int
        let label: String
        let amount: Double
        /// Subtotals render bold with a divider above them.
        let isSubtotal: Bool
    }

    /// Each equals what a tab currently displays as its headline income figure.
    let allSources: Double          // Income tab
    let totalWithRMDs: Double        // Tax Summary
    let taxableFromSources: Double   // Scenarios
    let grossWithScenario: Double    // Quarterly

    let steps: [Step]

    init(allSources: Double, inheritedRMD: Double, taxExempt: Double,
         taxableFromSources: Double, scenarioAdditions: Double, grossWithScenario: Double) {
        self.allSources = allSources
        self.totalWithRMDs = allSources + inheritedRMD
        self.taxableFromSources = taxableFromSources
        self.grossWithScenario = grossWithScenario

        var out: [Step] = []
        func add(_ label: String, _ amount: Double, subtotal: Bool = false) {
            out.append(Step(id: out.count, label: label, amount: amount, isSubtotal: subtotal))
        }
        add("Income from all sources", allSources)
        add("Inherited-IRA RMD", inheritedRMD)
        add("Total income (sources + RMDs)", allSources + inheritedRMD, subtotal: true)
        add("Less tax-exempt interest", -taxExempt)
        add("Taxable income from sources", taxableFromSources, subtotal: true)
        add("Scenario withdrawals / conversions", scenarioAdditions)
        add("Gross income (with scenario)", grossWithScenario, subtotal: true)
        self.steps = out
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/IncomeBreakdownTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/IncomeBreakdown.swift RetireSmartIRATests/IncomeBreakdownTests.swift
git commit -m "feat(income): add IncomeBreakdown chain model"
```

---

### Task 2: `DataManager.incomeBreakdown` factory

**Files:**
- Create: `RetireSmartIRA/DataManager+IncomeBreakdown.swift`
- Test: `RetireSmartIRATests/DataManagerIncomeBreakdownTests.swift`

**Interfaces:**
- Consumes: `IncomeBreakdown` (Task 1); `DataManager.totalAnnualIncome()`, `.inheritedIRARMDTotal`, `.taxExemptInterestTotal`, `.scenarioBaseIncome`, `.scenarioTotalRothConversion`, `.scenarioTotalWithdrawals`, `.scenarioGrossIncome` (all existing).
- Produces: `var DataManager.incomeBreakdown: IncomeBreakdown`.

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/DataManagerIncomeBreakdownTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("DataManager incomeBreakdown")
struct DataManagerIncomeBreakdownTests {
    @Test("breakdown's canonical values match the DataManager figures the tabs use today")
    func matches() {
        let dm = DataManager()
        let b = dm.incomeBreakdown
        #expect(b.allSources == dm.totalAnnualIncome())
        #expect(b.grossWithScenario == dm.scenarioGrossIncome)
        #expect(abs(b.totalWithRMDs - (dm.totalAnnualIncome() + dm.inheritedIRARMDTotal)) < 0.01)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/DataManagerIncomeBreakdownTests 2>&1 | tail -15`
Expected: FAIL (`incomeBreakdown` undefined).

- [ ] **Step 3: Implement**

```swift
// RetireSmartIRA/DataManager+IncomeBreakdown.swift
import Foundation

@MainActor
extension DataManager {
    /// The single-year income chain, composed from the existing figures each tab uses. See
    /// docs/superpowers/specs/2026-07-02-income-consistency-design.md.
    var incomeBreakdown: IncomeBreakdown {
        IncomeBreakdown(
            allSources: totalAnnualIncome(),
            inheritedRMD: inheritedIRARMDTotal,
            taxExempt: taxExemptInterestTotal,
            taxableFromSources: scenarioBaseIncome,
            scenarioAdditions: scenarioTotalRothConversion + scenarioTotalWithdrawals,
            grossWithScenario: scenarioGrossIncome)
    }
}
```

Note: if the compiler reports any of `scenarioBaseIncome` / `scenarioTotalRothConversion` /
`scenarioTotalWithdrawals` as inaccessible, they are the three terms of `scenarioGrossIncome`
(`DataManager.swift:1546`); widen their access to `internal` (not `private`) so this extension can read
them. Do not change their computation.

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/DataManagerIncomeBreakdownTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/DataManager+IncomeBreakdown.swift RetireSmartIRATests/DataManagerIncomeBreakdownTests.swift
git commit -m "feat(income): DataManager.incomeBreakdown factory"
```

---

## Phase 2 — Shared view + precise labels

### Task 3: `IncomeBreakdownView` (reusable expander)

**Files:**
- Create: `RetireSmartIRA/IncomeBreakdownView.swift`
- Test: `RetireSmartIRATests/IncomeBreakdownViewTests.swift`

**Interfaces:**
- Consumes: `IncomeBreakdown` (Task 1).
- Produces: `struct IncomeBreakdownView: View { let breakdown: IncomeBreakdown }` — a `DisclosureGroup("Show how this is computed")` listing each `Step` (subtotals bold, negative amounts shown as such).

- [ ] **Step 1: Write the construct test**

```swift
// RetireSmartIRATests/IncomeBreakdownViewTests.swift
import Testing
import SwiftUI
@testable import RetireSmartIRA

@MainActor
@Suite("IncomeBreakdownView construct")
struct IncomeBreakdownViewTests {
    @Test("builds from a breakdown")
    func build() {
        let b = IncomeBreakdown(allSources: 176_054, inheritedRMD: 11_363, taxExempt: 46_927,
            taxableFromSources: 140_490, scenarioAdditions: 84_009, grossWithScenario: 224_499)
        _ = IncomeBreakdownView(breakdown: b).body
        #expect(b.steps.count == 7)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/IncomeBreakdownViewTests 2>&1 | tail -15`
Expected: FAIL.

- [ ] **Step 3: Implement**

```swift
// RetireSmartIRA/IncomeBreakdownView.swift
import SwiftUI

/// Reusable "show how this is computed" disclosure that renders the income chain. Any single-year
/// tab can drop this under its headline income figure so the reconciliation is one tap away.
struct IncomeBreakdownView: View {
    let breakdown: IncomeBreakdown
    @State private var expanded = false

    var body: some View {
        DisclosureGroup("Show how this is computed", isExpanded: $expanded) {
            VStack(spacing: 4) {
                ForEach(breakdown.steps) { step in
                    if step.isSubtotal { Divider() }
                    HStack {
                        Text(step.label)
                            .fontWeight(step.isSubtotal ? .semibold : .regular)
                        Spacer()
                        Text(step.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .fontWeight(step.isSubtotal ? .semibold : .regular)
                            .monospacedDigit()
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 4)
        }
        .font(.caption)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/IncomeBreakdownViewTests 2>&1 | tail -15`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/IncomeBreakdownView.swift RetireSmartIRATests/IncomeBreakdownViewTests.swift
git commit -m "feat(income): reusable IncomeBreakdownView expander"
```

---

### Task 4: Relabel + wire the four tab headlines

**Files:**
- Modify: `RetireSmartIRA/IncomeSourcesView.swift:23` (label "Total Annual Income")
- Modify: `RetireSmartIRA/DashboardView.swift:359,368` (label "Total Baseline Income")
- Modify: `RetireSmartIRA/TaxPlanningView.swift:701` (label "Income from Sources")
- Modify: `RetireSmartIRA/QuarterlyTaxView.swift:187` (label "Gross Income")

**Interfaces:**
- Consumes: `DataManager.incomeBreakdown` (Task 2), `IncomeBreakdownView` (Task 3).

- [ ] **Step 1: Change the four labels (exact string edits)**

- `IncomeSourcesView.swift:23`: `label: "Total Annual Income",` → `label: "Total income from sources",`
- `DashboardView.swift` (both occurrences at 359 and 368): `Text("Total Baseline Income")` → `Text("Total income (sources + RMDs)")`
- `TaxPlanningView.swift:701`: `Text("Income from Sources")` → `Text("Taxable income from sources")`
- `QuarterlyTaxView.swift:187`: `summaryRow(label: "Gross Income", value: dataManager.scenarioGrossIncome)` → `summaryRow(label: "Gross income (with scenario)", value: dataManager.scenarioGrossIncome)`

- [ ] **Step 2: Add the expander under each headline**

Under each of the four headline blocks above, add:
```swift
IncomeBreakdownView(breakdown: dataManager.incomeBreakdown)
```
(Place it immediately below the value `Text`, inside the same container. In `QuarterlyTaxView` the summary
is a helper table — add the `IncomeBreakdownView` directly after the summary section instead of inside a row.)

- [ ] **Step 3: Verify the displayed numbers are unchanged**

Run: `xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED. The value bindings are untouched (only labels changed and a disclosure added),
so each tab's number is identical to before. If any tab's headline previously used a *view-local* value
that differs from `dataManager.incomeBreakdown.<value>`, keep the tab's own value in the headline and pass
`dataManager.incomeBreakdown` only to the expander (the expander is additive; do not change a headline
number in this task).

- [ ] **Step 4: Full suite**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | grep -E "Test run with|✘" | tail -3`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/IncomeSourcesView.swift RetireSmartIRA/DashboardView.swift RetireSmartIRA/TaxPlanningView.swift RetireSmartIRA/QuarterlyTaxView.swift
git commit -m "feat(income): precise per-tab labels + reconciliation expander"
```

---

## Phase 3 — T2, T1, INC-1

### Task 5: T2 — derive `hasTaxableBrokerage`, remove the toggle

**Files:**
- Modify: `RetireSmartIRA/DataManager.swift:77-80` (`hasTaxableBrokerage`)
- Modify: `RetireSmartIRA/SettingsView.swift:106-118` (remove the toggle)
- Test: `RetireSmartIRATests/HasTaxableBrokerageDerivationTests.swift`

**Interfaces:**
- Consumes: `DataManager.taxableAccounts` (shipped).

- [ ] **Step 1: Write the failing test**

```swift
// RetireSmartIRATests/HasTaxableBrokerageDerivationTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("hasTaxableBrokerage derivation")
struct HasTaxableBrokerageDerivationTests {
    @Test("derives from taxable accounts, not a stored toggle")
    func derives() {
        let dm = DataManager()
        dm.taxableAccounts = []
        #expect(dm.hasTaxableBrokerage == false)
        dm.taxableAccounts = [TaxableAccount(name: "B", balance: 100_000, costBasis: 100_000)]
        #expect(dm.hasTaxableBrokerage == true)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/HasTaxableBrokerageDerivationTests 2>&1 | tail -15`
Expected: FAIL (currently backed by `profile.hasTaxableBrokerage`).

- [ ] **Step 3: Derive the property**

In `DataManager.swift:77-80`, replace the get/set forwarding with a computed derivation:
```swift
    /// Derived from first-class taxable accounts. Gates single-year taxable-account surfaces
    /// (e.g. the LTCG-harvesting card). The old manual toggle was removed from My Profile.
    var hasTaxableBrokerage: Bool { !taxableAccounts.isEmpty }
```

- [ ] **Step 4: Remove the toggle from `SettingsView`**

Delete the toggle block at `SettingsView.swift:106-118` (the `Toggle("I have a taxable brokerage account" …)` and its `.onChange`). If that leaves an empty `Section`, delete the section too. Build to confirm nothing else references the removed binding.

- [ ] **Step 5: Verify**

Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/HasTaxableBrokerageDerivationTests 2>&1 | tail -10`
Then the full suite: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | grep -E "Test run with|✘" | tail -3`
Expected: pass. (If a persistence test asserts the old stored toggle, update it: the value is now derived, not stored.)

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/DataManager.swift RetireSmartIRA/SettingsView.swift RetireSmartIRATests/HasTaxableBrokerageDerivationTests.swift
git commit -m "feat(accounts): derive hasTaxableBrokerage from taxable accounts, drop toggle"
```

---

### Task 6: T1 — missing-input nudges on Multi-Year

**Files:**
- Modify: `RetireSmartIRA/MultiYearPlanView.swift` (add nudges near the existing no-taxable-account warning)

**Interfaces:**
- Consumes: `dataManager.primarySSBenefit`, `dataManager.spouseSSBenefit`, `dataManager.incomeSources`.

- [ ] **Step 1: Add the nudges**

In `MultiYearPlanView.swift`, next to the existing missing-taxable-account warning (search for
`"No taxable account entered"`), add two more conditional notes in the same style:

```swift
                    if (dataManager.primarySSBenefit?.benefitAtFRA ?? 0) == 0
                        && (dataManager.spouseSSBenefit?.benefitAtFRA ?? 0) == 0 {
                        Text("No Social Security entered. This plan assumes $0 in benefits. Add yours on the Social Security tab.")
                            .font(.callout).foregroundStyle(.orange)
                            .padding().background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if dataManager.incomeSources.isEmpty {
                        Text("No income sources entered. If you have pension, wages, or investment income, add it on the Income & Deductions tab.")
                            .font(.callout).foregroundStyle(.orange)
                            .padding().background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
```

- [ ] **Step 2: Build + full suite**

Run: `xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -3` (BUILD SUCCEEDED)
Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | grep -E "Test run with|✘" | tail -3` (all pass)

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRA/MultiYearPlanView.swift
git commit -m "feat(multi-year): nudge when Social Security or income is unentered"
```

---

### Task 7: INC-1 — supersede signal on the Income tab

**Files:**
- Modify: `RetireSmartIRA/IncomeSourcesView.swift` (note above the income-sources list)

**Interfaces:**
- Consumes: `dataManager.taxableAccounts`, `dataManager.incomeSources`.

- [ ] **Step 1: Add the conditional note**

In `IncomeSourcesView.swift`, just above the income-sources `ForEach` (near line 71), add a note that
shows only when taxable accounts exist AND at least one investment-income entry exists:

```swift
                    if !dataManager.taxableAccounts.isEmpty
                        && dataManager.incomeSources.contains(where: { [.dividends, .qualifiedDividends, .interest, .capitalGainsShort, .capitalGainsLong, .taxExemptInterest].contains($0.type) }) {
                        Label("For the Multi-Year plan, investment income is derived from your taxable accounts. These entries are still used by the single-year Tax Summary, Scenarios, and Quarterly views.",
                              systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                    }
```

- [ ] **Step 2: Build + full suite**

Run: `xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tail -3` (BUILD SUCCEEDED)
Run: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | grep -E "Test run with|✘" | tail -3` (all pass)

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRA/IncomeSourcesView.swift
git commit -m "feat(income): signal that account yields supersede manual investment income for Multi-Year"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** T3 model (Task 1), factory (Task 2), shared view (Task 3), labels + wiring (Task 4); T2 (Task 5); T1 (Task 6); INC-1 (Task 7). IA consolidation intentionally absent.
- **Placeholder scan:** no TBD/TODO; each code step shows code; label edits give exact before/after strings and file:line anchors.
- **Type consistency:** `IncomeBreakdown` / `Step` field names and the `incomeBreakdown` factory match across Tasks 1-4; `IncomeBreakdownView(breakdown:)` signature consistent Tasks 3-4.
- **Known risk (called out in Task 4 Step 3):** if a tab's prior headline used a view-local value differing from the model's, keep the local in the headline and use the model only for the expander — never change a displayed number in this plan.
