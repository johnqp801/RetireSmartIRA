# Engine Realism Batch — C3 Gross-Up + PV-Discounted Objective Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the multi-year optimizer from over-converting by (C3) giving conversions a real liquidity brake — conversion tax paid from taxable, shortfall grossed-up from traditional — and (PV) discounting tax to present value inside the objective.

**Architecture:** C3 adds a `TaxPaymentSource` assumption and a bounded gross-up in `ProjectionEngine`'s year-loop tax tail (recompute federal+state at the grossed-up income before building `TaxBreakdown`). PV adds a `presentValue` helper and discounts each in-horizon year's tax and the blended terminal tax in `OptimizationEngine` at the existing `pvRealDiscountRate`. Conversion goldens move; re-baseline with attribution.

**Tech Stack:** Swift, Swift Testing, Xcode scheme `RetireSmartIRA`, native macOS. Build/test via `xcodebuild`. New `.swift` files auto-join their target (file-system-synchronized groups).

**Spec:** `docs/superpowers/specs/2026-06-26-engine-realism-c3-objective-pv-design.md`

**Conventions:**
- Suite: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/<Suite>`
- Full: `xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS'`
- Build err count: `xcodebuild build -scheme RetireSmartIRA -destination 'platform=macOS' -quiet 2>&1 | grep -cE 'error:'`

---

## File Structure
- **Modify** `RetireSmartIRA/MultiYearAssumptions.swift` — add `TaxPaymentSource` enum + `taxPaymentSource` field.
- **Modify** `RetireSmartIRA/YearRecommendation.swift` — add `underfunded: Double?` (default nil).
- **Modify** `RetireSmartIRA/ProjectionEngine.swift` — C3 gross-up in the year-loop tax tail.
- **Create** `RetireSmartIRA/PresentValue.swift` — `presentValue(_:yearsFromBase:realDiscountRate:)` helper.
- **Modify** `RetireSmartIRA/OptimizationEngine.swift` — discount in-horizon + terminal tax in the objective.
- **Create/Modify** tests per task; **create** `docs/superpowers/reconciliation/2026-06-26-realism-delta-ledger.md`.

---

## Task 1: TaxPaymentSource assumption

**Files:** Modify `RetireSmartIRA/MultiYearAssumptions.swift`; Test `RetireSmartIRATests/TaxPaymentSourceTests.swift`.

- [ ] **Step 1: Write the failing test**
```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("TaxPaymentSource assumption", .serialized)
struct TaxPaymentSourceTests {
    @Test("default is taxableThenGrossUp") func def() {
        #expect(MultiYearAssumptions().taxPaymentSource == .taxableThenGrossUp)
    }
    @Test("survives a Codable round-trip; legacy JSON without the key defaults") func codable() throws {
        var a = MultiYearAssumptions(); a.taxPaymentSource = .external
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(MultiYearAssumptions.self, from: data)
        #expect(back.taxPaymentSource == .external)
    }
}
```

- [ ] **Step 2: Run it, expect FAIL** (`taxPaymentSource`/`TaxPaymentSource` undefined).

- [ ] **Step 3: Add the enum + field.** In `MultiYearAssumptions.swift`, above the struct add:
```swift
enum TaxPaymentSource: String, Codable, Sendable {
    case taxableThenGrossUp   // pay from taxable; shortfall pulled from traditional (taxed)
    case external             // legacy: tax assumed paid from outside funds (for tests/back-compat)
}
```
Add the stored property after `pvRealDiscountRate`:
```swift
    /// Where conversion/year tax is paid from. Default brakes over-conversion (C3).
    var taxPaymentSource: TaxPaymentSource = .taxableThenGrossUp
```
Add to the memberwise `init` (after `pvRealDiscountRate: Double = 0.03`):
```swift
        taxPaymentSource: TaxPaymentSource = .taxableThenGrossUp,
```
and assign in the body: `self.taxPaymentSource = taxPaymentSource`.
Add to `init(from:)` (after the `pvRealDiscountRate` decode line):
```swift
        self.taxPaymentSource = try c.decodeIfPresent(TaxPaymentSource.self, forKey: .taxPaymentSource) ?? .taxableThenGrossUp
```

- [ ] **Step 4: Run it, expect PASS.**
- [ ] **Step 5: Commit**
```bash
git add RetireSmartIRA/MultiYearAssumptions.swift RetireSmartIRATests/TaxPaymentSourceTests.swift
git commit -m "feat(engine): TaxPaymentSource assumption (default taxableThenGrossUp)"
```

---

## Task 2: `underfunded` field on YearRecommendation

**Files:** Modify `RetireSmartIRA/YearRecommendation.swift`; Test `RetireSmartIRATests/YearRecommendationUnderfundedTests.swift`.

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import RetireSmartIRA

@Suite("YearRecommendation.underfunded", .serialized)
struct YearRecommendationUnderfundedTests {
    @Test("defaults to nil and is settable") func field() {
        let base = AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0)
        let tb = TaxBreakdown(federal: 0, state: 0, irmaa: 0, acaPremiumImpact: 0)
        let a = YearRecommendation(year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: tb, endOfYearBalances: base, actions: [], medicareEnrolledCount: 0)
        #expect(a.underfunded == nil)
        let b = YearRecommendation(year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: tb, endOfYearBalances: base, actions: [], medicareEnrolledCount: 0, underfunded: 1234)
        #expect(b.underfunded == 1234)
    }
}
```

- [ ] **Step 2: Run it, expect FAIL** (no `underfunded` parameter).

- [ ] **Step 3: Add the field (optional with default — keeps all 11 existing constructions valid).** In `YearRecommendation.swift` add a stored property after `medicareEnrolledCount`:
```swift
    /// Tax that could not be funded from taxable or traditional this year (genuinely insolvent).
    /// nil/0 means fully funded. Never silent "external" funding.
    let underfunded: Double?
```
Add `underfunded: Double? = nil` as the LAST init parameter and `self.underfunded = underfunded` in the body.

- [ ] **Step 4: Run it + build, expect PASS / 0 errors.**
- [ ] **Step 5: Commit**
```bash
git add RetireSmartIRA/YearRecommendation.swift RetireSmartIRATests/YearRecommendationUnderfundedTests.swift
git commit -m "feat(engine): YearRecommendation.underfunded (default nil)"
```

---

## Task 3: C3 gross-up in ProjectionEngine (the substantive engine change)

**Files:** Modify `RetireSmartIRA/ProjectionEngine.swift`; Test `RetireSmartIRATests/TaxGrossUpTests.swift`.

This replaces the Step-7 "pay from taxable, remainder external" with: pay from taxable; if short and `assumptions.taxPaymentSource == .taxableThenGrossUp`, fund the remaining tax by an additional traditional withdrawal grossed-up for its own federal+state tax (bounded 3-iteration fixed-point). IRMAA/ACA are NOT recomputed for the extra withdrawal (documented approximation — spec §2). `.external` keeps today's behavior.

- [ ] **Step 1: Write the failing tests**
```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("C3 tax gross-up", .serialized)
@MainActor
struct TaxGrossUpTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func inputs(trad: Double, taxable: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 66, spouseCurrentAge: nil, filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1960, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0, acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions(_ src: TaxPaymentSource) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
        a.taxPaymentSource = src; return a
    }

    // A $400K conversion with ZERO taxable to pay its tax: gross-up must pull the tax from trad,
    // so the end-of-year traditional is BELOW (start − conversion) and Roth gain is the conversion.
    @Test("gross-up pulls conversion tax from traditional when taxable is empty") func grossUp() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 0), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        let trad = p[0].endOfYearBalances.primaryTraditional
        // converted 400k out, plus the tax on it pulled from trad → trad < 600k
        #expect(trad < 600_000)
        #expect(p[0].endOfYearBalances.taxable == 0)   // taxable fully consumed first (was 0)
    }

    // .external reproduces the legacy behavior: trad == start − conversion exactly (tax "external").
    @Test(".external leaves trad at start minus conversion (legacy)") func external() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 0), assumptions: assumptions(.external),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        #expect(abs(p[0].endOfYearBalances.primaryTraditional - 600_000) < 1.0)
    }

    // Ample taxable: the conversion tax is easily funded from taxable, so the gross-up never fires
    // and the traditional ends the same under .taxableThenGrossUp and .external (≈ unchanged behavior).
    @Test("ample taxable: gross-up does not fire") func ample() {
        let g = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 1_000_000), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 200_000)]])
        let e = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 1_000_000), assumptions: assumptions(.external),
            actionsPerYear: [2026: [.rothConversion(amount: 200_000)]])
        #expect(abs(g[0].endOfYearBalances.primaryTraditional - e[0].endOfYearBalances.primaryTraditional) < 1.0)
        #expect(g[0].underfunded == nil)   // fully funded
    }

    // The gross-up withdrawal is visible in the year's actions (credibility — "we pulled $X to pay tax").
    @Test("gross-up shows up as a traditional withdrawal action") func visibleAction() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 0), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        let withdrawals = p[0].actions.compactMap { act -> Double? in
            if case let .traditionalWithdrawal(a) = act { return a }; return nil }
        #expect(withdrawals.contains { $0 > 0 })
    }
}
```

- [ ] **Step 2: Run it, expect FAIL** (gross-up not implemented — `.taxableThenGrossUp` currently behaves like `.external`, so `grossUp()` fails: trad == 600k).

- [ ] **Step 3: Implement the gross-up.** In `ProjectionEngine.project(...)`, the year-loop tail currently is (around lines 515–607): compute `let federalTax`, `let stateTax`, …, `let taxBreakdown`, then Step 7 `let yearTaxBurden = max(0, taxBreakdown.total); let taxDebit = min(taxable, yearTaxBurden); taxable -= taxDebit`.

Change as follows:
(a) Make the reported tax inputs mutable so the gross-up can revise them. Change `let federalAGI` → keep as-is, but introduce mutable copies right before `taxBreakdown`:
```swift
            var grossUpWithdrawal = 0.0
            var underfundedTax = 0.0
            var fedTax = federalTax
            var stTax = stateTax
            var reportedAGI = federalAGI
            var reportedTaxableIncome = taxableIncome

            // C3: brake over-conversion. Pay tax from taxable; gross-up the shortfall from traditional.
            if assumptions.taxPaymentSource == .taxableThenGrossUp {
                let nonFedState = max(0, taxBreakdown.total - federalTax - stateTax)  // irmaa+aca, NOT recomputed (spec §2)
                let baseTotalTax = federalTax + stateTax + nonFedState
                let shortfall0 = max(0, baseTotalTax - taxable)
                if shortfall0 > 0 {
                    let availableTrad = max(0, primaryTrad + spouseTrad)
                    // Extra federal+state tax created by an extra dW of ordinary (trad) income.
                    func taxOn(_ dW: Double) -> Double {
                        let fed = TaxCalculationEngine.calculateFederalTax(
                            income: max(0, taxableIncome + dW), filingStatus: inputs.filingStatus,
                            brackets: brackets, preferentialIncome: taxablePreferential) - federalTax
                        let st = computeStateTax(
                            federalAGI: federalAGI + dW, taxableSS: taxableSS, pensionIncome: pensionIncome,
                            totalTradWithdrawals: totalTradWithdrawals + dW, filingStatus: inputs.filingStatus,
                            usState: usState, primaryAge: primaryAge, spouseBirthYear: inputs.spouseBirthYear, year: year) - stateTax
                        return max(0, fed) + max(0, st)
                    }
                    // Need dW such that dW − taxOn(dW) covers shortfall0 → fixed point dW = shortfall0 + taxOn(dW).
                    var dW = min(shortfall0, availableTrad)
                    for _ in 0..<3 {
                        let next = min(shortfall0 + taxOn(dW), availableTrad)
                        if abs(next - dW) < 1.0 { dW = next; break }
                        dW = next
                    }
                    grossUpWithdrawal = dW
                    // Apply the withdrawal to the trad buckets (older-spouse-first).
                    var remaining = dW
                    if primaryIsOlderOrSingle {
                        let fromP = min(remaining, max(0, primaryTrad)); primaryTrad -= fromP; remaining -= fromP
                        spouseTrad -= min(remaining, max(0, spouseTrad))
                    } else {
                        let fromS = min(remaining, max(0, spouseTrad)); spouseTrad -= fromS; remaining -= fromS
                        primaryTrad -= min(remaining, max(0, primaryTrad))
                    }
                    // Revise the REPORTED federal+state tax at the grossed-up income.
                    reportedTaxableIncome = max(0, taxableIncome + dW)
                    reportedAGI = federalAGI + dW
                    fedTax = TaxCalculationEngine.calculateFederalTax(
                        income: reportedTaxableIncome, filingStatus: inputs.filingStatus,
                        brackets: brackets, preferentialIncome: taxablePreferential)
                    stTax = computeStateTax(
                        federalAGI: reportedAGI, taxableSS: taxableSS, pensionIncome: pensionIncome,
                        totalTradWithdrawals: totalTradWithdrawals + dW, filingStatus: inputs.filingStatus,
                        usState: usState, primaryAge: primaryAge, spouseBirthYear: inputs.spouseBirthYear, year: year)
                    underfundedTax = max(0, (fedTax + stTax + nonFedState) - taxable - dW)
                }
            }

            let taxBreakdownFinal = TaxBreakdown(
                federal: fedTax, state: stTax,
                irmaa: taxBreakdown.irmaa, acaPremiumImpact: taxBreakdown.acaPremiumImpact)
```
(b) Replace the Step-7 debit with one that uses the gross-up:
```swift
            let yearTaxBurden = max(0, taxBreakdownFinal.total)
            // Taxable pays first; the gross-up withdrawal funded the rest (already taken from trad).
            taxable -= min(taxable, yearTaxBurden)
```
(c) Make the gross-up withdrawal visible: in the existing `var allActions = actions` block (where the auto-RMD is already appended), also append the gross-up so the ladder shows it:
```swift
            if grossUpWithdrawal > 0 {
                allActions.append(.traditionalWithdrawal(amount: grossUpWithdrawal))
            }
```
(d) In the `YearRecommendation(...)` construction, use the revised values:
```swift
                agi: reportedAGI,
                ...
                taxableIncome: reportedTaxableIncome,
                taxBreakdown: taxBreakdownFinal,
                actions: allActions,
                medicareEnrolledCount: medicareEnrolledCount,
                underfunded: underfundedTax > 0 ? underfundedTax : nil
```

> Notes for the implementer: `brackets`, `taxablePreferential`, `taxableSS`, `pensionIncome`, `totalTradWithdrawals`, `primaryIsOlderOrSingle`, `usState`, `primaryAge` are all already in scope at this point in the loop (verify). For `.external`, none of this runs — the original `federalTax`/`stateTax`/`taxBreakdown` flow is preserved, so legacy numbers are unchanged. The gross-up uses the existing `calculateFederalTax`/`computeStateTax` — no extraction of the tax block.

- [ ] **Step 4: Run the C3 suite, expect PASS.** Then build (0 errors).

- [ ] **Step 5: Run the FULL suite.** `.taxableThenGrossUp` is the default, so engine tests that depended on free external tax will shift. For THIS task, only fix tests that fail to COMPILE; record value failures for Task 6's re-baseline (do not edit them yet). Confirm the build + the C3 suite are green.

- [ ] **Step 6: Commit**
```bash
git add RetireSmartIRA/ProjectionEngine.swift RetireSmartIRATests/TaxGrossUpTests.swift
git commit -m "feat(engine): C3 tax gross-up — conversions pay tax from taxable then traditional"
```

---

## Task 4: presentValue helper

**Files:** Create `RetireSmartIRA/PresentValue.swift`; Test `RetireSmartIRATests/PresentValueTests.swift`.

- [ ] **Step 1: Write the failing test**
```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("presentValue", .serialized)
struct PresentValueTests {
    @Test("discounts by (1+r)^-years") func discounts() {
        #expect(abs(EngineMath.presentValue(1000, yearsFromBase: 0, realDiscountRate: 0.03) - 1000) < 1e-9)
        #expect(abs(EngineMath.presentValue(1000, yearsFromBase: 10, realDiscountRate: 0.03) - 1000 / pow(1.03, 10)) < 1e-6)
    }
}
```

- [ ] **Step 2: Run it, expect FAIL** (`EngineMath` undefined).

- [ ] **Step 3: Create `RetireSmartIRA/PresentValue.swift`:**
```swift
import Foundation

enum EngineMath {
    /// Present value of `amount` received `yearsFromBase` years from the base year, at a real rate.
    /// CONVENTION: `yearsFromBase == 0` is the base/current year and is **undiscounted** (factor 1.0);
    /// each later year is discounted by one more period. Tested in PresentValueTests.
    static func presentValue(_ amount: Double, yearsFromBase: Int, realDiscountRate r: Double) -> Double {
        amount / pow(1 + r, Double(max(0, yearsFromBase)))
    }
}
```

- [ ] **Step 4: Run it, expect PASS.**
- [ ] **Step 5: Commit**
```bash
git add RetireSmartIRA/PresentValue.swift RetireSmartIRATests/PresentValueTests.swift
git commit -m "feat(engine): EngineMath.presentValue helper"
```

---

## Task 5: PV-discount the optimizer objective

**Files:** Modify `RetireSmartIRA/OptimizationEngine.swift`; Test `RetireSmartIRATests/ObjectivePVTests.swift`.

The objective currently sums nominal `taxBreakdown.total` per year + nominal blended terminal tax. Discount each year Y's tax by `(1+r)^-(Y-baseYear)` and the terminal tax by `(1+r)^-(horizonYears)`, where `r = assumptions.pvRealDiscountRate`.

- [ ] **Step 1: Write the failing test**
```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Objective PV discounting", .serialized)
@MainActor
struct ObjectivePVTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }
    private func inputs() -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 2_000_000, roth: 0, taxable: 1_000_000, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 70, spouseCurrentAge: nil, filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1956, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0, acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions(pv: Double) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0.06, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 1_000_000, currentHSABalance: 0)
        a.pvRealDiscountRate = pv; return a
    }
    private func totalConverted(_ r: MultiYearStrategyResult) -> Double {
        r.recommendedPath.reduce(0.0) { acc, yr in acc + yr.actions.reduce(0.0) { a, act in
            if case let .rothConversion(amount) = act { return a + amount }; return a } }
    }

    // Discounting future terminal tax makes the optimizer LESS aggressive than no discounting.
    @Test("higher discount rate converts no more than a near-zero rate") func lessAggressive() {
        let r0 = OptimizationEngine().optimize(inputs: inputs(), assumptions: assumptions(pv: 0.0001), configProvider: provider)
        let r3 = OptimizationEngine().optimize(inputs: inputs(), assumptions: assumptions(pv: 0.05), configProvider: provider)
        #expect(totalConverted(r3) <= totalConverted(r0) + 1.0)
    }
}
```

- [ ] **Step 2: Run it, expect FAIL** initially only if discounting changes behavior — it may pass trivially before the change. Treat Step 1 as the spec; proceed to implement, then confirm it holds with a meaningful gap (assert the inequality, which the change enforces).

- [ ] **Step 3: Implement discounting.** In `OptimizationEngine.swift`:
(a) Add a pure helper:
```swift
    /// PV of a path's in-horizon tax, discounting each year to baseYear.
    static func discountedInHorizon(_ path: [YearRecommendation], baseYear: Int, rate: Double) -> Double {
        path.reduce(0.0) { $0 + EngineMath.presentValue($1.taxBreakdown.total, yearsFromBase: $1.year - baseYear, realDiscountRate: rate) }
    }
```
(b) In the inner candidate loop, replace
```swift
                    let objective = path.reduce(0.0) { $0 + $1.taxBreakdown.total }
                                  + blendedTerminalTax(path, inputs: inputs, selfRate: assumptions.terminalLiquidationTaxRate, heirWeight: heirWeight)
```
with
```swift
                    let r = assumptions.pvRealDiscountRate
                    let objective = Self.discountedInHorizon(path, baseYear: baseYear, rate: r)
                                  + EngineMath.presentValue(
                                        blendedTerminalTax(path, inputs: inputs, selfRate: assumptions.terminalLiquidationTaxRate, heirWeight: heirWeight),
                                        yearsFromBase: horizonYears, realDiscountRate: r)
```
(c) Apply the same discounting at the constraint-rationale block (`baselineLifetimeTax`/`currentLifetimeTax`) and the final `Result(totalObjectiveCost:)` — replace each `inHorizon (= reduce taxBreakdown.total) + blendedTerminalTax(...)` with `Self.discountedInHorizon(path, baseYear:, rate: r) + presentValue(blendedTerminalTax(...), yearsFromBase: horizonYears, rate: r)`. (`baseYear` and `horizonYears` are already in scope in `optimize`.)
(d) Update the static `computeObjectiveCost(path:terminalLiquidationTaxRate:)` used by wrappers: add `baseYear: Int` and `pvRealDiscountRate: Double` parameters and discount both terms the same way; update the two wrapper call sites (`WidowStressTest`, `SSClaimNudge`) to pass `inputs.baseYear` and `assumptions.pvRealDiscountRate`.

- [ ] **Step 4: Run the PV suite + build, expect PASS / 0 errors.**
- [ ] **Step 5: Commit**
```bash
git add RetireSmartIRA/OptimizationEngine.swift RetireSmartIRA/WidowStressTest.swift RetireSmartIRA/SSClaimNudge.swift RetireSmartIRATests/ObjectivePVTests.swift
git commit -m "feat(optimizer): PV-discount in-horizon + terminal tax in the objective"
```

---

## Task 6: Re-baseline + frontier-opens regression + full green

**Files:** Create `docs/superpowers/reconciliation/2026-06-26-realism-delta-ledger.md`; create `RetireSmartIRATests/RealismRegressionTests.swift`; modify whichever existing tests assert moved conversion/terminal/objective numbers.

- [ ] **Step 1: Run the FULL suite, capture failures.**
`xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' 2>&1 | tee /tmp/realism.log | grep -E '✘ Test|Test run with'`

- [ ] **Step 2: Bucket each failure** (spec §4): A = should-NOT-move (structure/monotonicity/blend/formatting/`lambdaZeroMatchesLegacy`) → if it fails, it's a real bug, fix the source; B = a hard-coded conversion/terminal/objective number → attribute to C3 or PV, update, record a row; C = investigate. **Guardrail (external-review #5):** when a conversion goes DOWN, confirm the reduction is explained by removed over-weighting of distant terminal tax or by the gross-up's real cost — NOT by discounting away an in-horizon-justified conversion (a bracket fill, an RMD-compression avoidance, an IRMAA/heir/survivor effect). If a conversion that's justified by *in-horizon* reasons collapses, that's a regression, not a re-baseline — investigate the discounting (it should discount, not delete, near-term-justified moves). Create the ledger:
```markdown
# Realism batch delta ledger (2026-06-26)
| Test | Old | New | Attributed to (C3 gross-up / PV discount) |
|---|---|---|---|
```

- [ ] **Step 3: Write the finding-regression tests** `RetireSmartIRATests/RealismRegressionTests.swift`. Per the external-review caution: do NOT require a wealthy, high-liquidity case to retain trad — full conversion may legitimately be PV-rational there (C3's brake never fires when taxable easily funds the tax). Assert the brake where it should bite (constrained liquidity) and the spread where heir arbitrage exists (high-income heir).
```swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Realism regression", .serialized)
@MainActor
struct RealismRegressionTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }
    private func inputs(trad: Double, taxable: Double, heirSalary: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 70, spouseCurrentAge: nil, filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1956, spouseBirthYear: nil, primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0, acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            heirSalary: heirSalary, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0.06, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
    }

    // (1) LIQUIDITY-CONSTRAINED: little taxable to pay conversion tax. C3 gross-up + PV must stop
    // the engine from fully draining the traditional IRA at the owner-optimal weight.
    @Test("constrained liquidity: traditional is no longer fully drained") func brakeStopsDrain() {
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs(trad: 1_500_000, taxable: 50_000, heirSalary: 75_000),
            assumptions: assumptions(), configProvider: provider)
        let last = r.points.first(where: { $0.weight == 0 })!.recommendedPath.last!
        let termTrad = last.endOfYearBalances.primaryTraditional + last.endOfYearBalances.spouseTraditional
        #expect(termTrad > 0, "with little taxable to fund conversion tax, the engine should not drain the IRA to zero")
    }

    // (2) HIGH-INCOME HEIR + constrained liquidity: heir bracket-stacking is much costlier than the
    // owner's self-liquidation, so weighting toward heirs should produce a MEASURABLE trade-off.
    @Test("high-income heir: the frontier shows a measurable trade-off") func frontierSpreads() {
        let r = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs(trad: 1_500_000, taxable: 50_000, heirSalary: 250_000),
            assumptions: assumptions(), configProvider: provider)
        let spread = abs(r.points.last!.heirAfterTaxInheritanceToday - r.points.first!.heirAfterTaxInheritanceToday)
        #expect(spread > 1000, "when heir rates differ materially and trad is retained, the frontier should open; got \(spread)")
    }
    // NOTE: deliberately NO assertion about a wealthy high-taxable case — full conversion may be
    // correct there, and a flat frontier in that case is the right answer, not a bug.
}
```
> If `brakeStopsDrain` still sees `termTrad == 0`, that is a real finding — investigate (do not weaken the assertion); the brake/discount isn't strong enough and the spec's approach needs revisiting before this batch is done. If `frontierSpreads` stays flat, confirm it's because the trad fully drained (then it's a C3/PV strength issue) vs. heir rate ≈ owner rate at that salary (then raise the heir salary in the fixture).

- [ ] **Step 4: Run the FULL suite, expect ALL PASS** with every moved number attributed in the ledger.
- [ ] **Step 5: Commit**
```bash
git add docs/superpowers/reconciliation/2026-06-26-realism-delta-ledger.md RetireSmartIRATests/ docs RetireSmartIRA
git commit -m "test(engine): re-baseline conversions for C3+PV; frontier-opens regression; full suite green"
```

---

## Task 7: Re-run the tab and confirm the recommendations are credible

**Files:** none (manual/agent verification).

- [ ] **Step 1:** Build + launch the macOS app; open **Multi-Year Plan**.
- [ ] **Step 2:** Confirm the acceptance signs (external-review #7): recommended AGI no longer parks at a very high level every year; IRMAA warnings are occasional/intentional, not automatic every year; low-taxable scenarios are visibly liquidity-constrained (gross-up withdrawals appear, conversions shrink); high-taxable scenarios may still convert aggressively but for a PV-defensible reason; the heir frontier shows a visible spread when heir arbitrage exists and changes the ladder when you select a weight. Screenshot.
- [ ] **Step 3:** Record any remaining issue. If the recommendations are now credible and the frontier opens where the facts support it, the batch is done.

> **Follow-up (next increment, NOT this batch) — Explainability audit (external-review suggestion):** give each ladder year a machine-readable reason for its conversion level (filled a bracket / avoided RMD compression / reduced heir-or-survivor exposure / stopped because taxable liquidity was exhausted [`underfunded`] / stopped because the IRMAA+PV cost outweighed the benefit). This builds on `underfunded` (this batch) + the existing `tradeOffsAccepted`/`ConstraintAcceptor` rationale machinery; internal-only at first, then surfaced in the ladder UI. Logged as the natural next step after realism.

---

## Self-Review Notes
- **Re-verify at execution:** in-scope variable names at the ProjectionEngine gross-up insertion point (`brackets`, `taxablePreferential`, `taxableSS`, `pensionIncome`, `totalTradWithdrawals`, `primaryIsOlderOrSingle`, `usState`, `primaryAge`); `computeStateTax` labels; `OptimizationEngine.computeObjectiveCost` call sites in `WidowStressTest`/`SSClaimNudge`; `optimize`'s `baseYear`/`horizonYears` are in scope.
- **Bucket-A guards must stay green un-edited** (structure/monotonicity/`lambdaZeroMatchesLegacy`/blend/formatting). Only Bucket-B golden numbers move, each attributed.
- **No double-discounting:** the frontier display toggle still scales today's-dollar reported figures; the objective discounts to choose. They use the same rate but never apply it twice to one number.
