# Multi-Year Cash-Charitable Itemizing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the multi-year `ProjectionEngine` choose standard vs. itemized per year (cash charitable deductible under the real OBBBA rules) so the optimizer rewards bunching a cash gift into a high-conversion year.

**Architecture:** A new dependency-free `MultiYearItemizedDeduction` helper replicates the single-year itemized rules (SALT cap w/ phaseout, medical floor, charitable ceiling + 0.5% floor, §68 overall limitation, §170(p) non-itemizer). `ProjectionEngine` computes state tax earlier, derives cash charitable from the giving plan, computes both deduction totals via the helper, and picks the lower-federal-tax path. Inputs are seeded once from the single-year `DataManager`. `DataManager` is not refactored; a parity test guards drift.

**Tech Stack:** Swift, Swift Testing (`@Test`/`#expect`), Xcode (macOS destination). Pure value types, no SwiftUI/Combine in engine code.

## Global Constraints

- Cash-only in multi-year: no appreciated-property/stock donations (single-year's 30%-AGI bucket is out of scope here).
- No 5-year charitable carryforward; no AMT in the multi-year path. These are documented limitations.
- Carried itemizables held **flat nominal** across the horizon; cash charitable keeps the giving plan's `maintainRealValue`.
- All config values come from `configProvider.config(forYear: year)` (per-year), never a hardcoded constant.
- Federal-only engine tests MUST pin a no-income-tax state (`"TX"`) — the California SALT-as-itemized confound otherwise shifts the itemize/standard crossover (senior-bonus session 2026-07-06, widow-tax session 2026-07-11).
- Run the suite with `-resultBundlePath` + `xcresulttool`; `xcodebuild` stdout undercounts large Swift-Testing suites.
- Anchor/label copy rule unchanged: the app never labels an approach "Recommended."
- Commit with an explicit pathspec.

Test command template (substitute the class/test name):
```bash
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' \
  -only-testing:RetireSmartIRATests/<TestType>/<testName> \
  -resultBundlePath /tmp/rsira-test.xcresult 2>&1 | tail -20
```

---

### Task 1: Expose the year's giving target from `QCDPlanner`

So the engine can derive cash charitable = `target − totalQCD` without recomputing the target.

**Files:**
- Modify: `RetireSmartIRA/QCDPlanner.swift:14-18,44,58`
- Test: `RetireSmartIRATests/QCDPlannerTests.swift` (add a test; create the file only if it does not already exist — check first with `ls RetireSmartIRATests | grep -i qcd`)

**Interfaces:**
- Produces: `QCDPlanner.YearlyQCD` gains `var target: Double` (the year's giving target before QCD/cash split). `cashCharitable` is then `max(0, target - total)` at the call site.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import RetireSmartIRA

@Test func qcdPlannerExposesGivingTarget() {
    let plan = CharitableGivingPlan(intent: .fixedAnnualAmount(10_000),
                                    funding: .fixedQCD(4_000), maintainRealValue: false)
    let r = QCDPlanner.plan(plan,
        primaryRMD: 0, spouseRMD: 0, primaryIRA: 100_000, spouseIRA: 0,
        primaryEligible: true, spouseEligible: false,
        qcdLimit: 100_000, inflationFactor: 1.0)
    #expect(r.target == 10_000)
    #expect(r.total == 4_000)
    #expect(max(0, r.target - r.total) == 6_000)   // cash remainder
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the template with `-only-testing:RetireSmartIRATests/QCDPlannerTests/qcdPlannerExposesGivingTarget`.
Expected: FAIL to compile — `YearlyQCD` has no member `target`.

- [ ] **Step 3: Add `target` to `YearlyQCD` and populate it**

In `QCDPlanner.swift`, add the stored property and thread `target` through all three `return` sites:

```swift
struct YearlyQCD: Equatable, Sendable {
    var primaryQCD: Double
    var spouseQCD: Double
    var target: Double = 0
    var total: Double { primaryQCD + spouseQCD }
}
```

Update the two early returns (`!plan.hasGiving` at :34 and `target <= 0` at :44) to `YearlyQCD(primaryQCD: 0, spouseQCD: 0, target: 0)`, and the final return at :58 to `YearlyQCD(primaryQCD: primaryQCD, spouseQCD: spouseQCD, target: target)`.

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/QCDPlanner.swift RetireSmartIRATests/QCDPlannerTests.swift
git commit -m "feat(multiyear): expose giving target from QCDPlanner for cash-charitable derivation"
```

---

### Task 2: Extract a pure `seniorBonusDeduction` helper in `ProjectionEngine`

The senior bonus is currently computed *inside* `standardDeduction`. The itemized path also needs it (it's available whether you itemize or not). Extract it so both paths use one source. Behavior-preserving.

**Files:**
- Modify: `RetireSmartIRA/ProjectionEngine.swift:1120-1168`
- Test: `RetireSmartIRATests/ProjectionEngineDeductionTests.swift` (new)

**Interfaces:**
- Produces: `private func seniorBonusDeduction(filingStatus:primaryAge:spouseAge:year:federalAGI:) -> Double` on the engine. `standardDeduction(...)` calls it instead of inlining the bonus.

- [ ] **Step 1: Write the failing test** (a free-standing pure check via a tiny test seam)

Add to the new test file. The engine method is `private`; test the observable behavior instead — that `standardDeduction` output is unchanged for a 66-year-old MFJ couple at low AGI (full $12k bonus in 2026) vs. a phased case. Use an existing engine construction helper if the test target already has one (`grep -rn "ProjectionEngine(" RetireSmartIRATests | head`); otherwise assert through a projected result in Task 6. If no seam exists yet, SKIP this step's assertion and rely on Task 6's coverage — do NOT expose the private method just for the test.

- [ ] **Step 2: Extract the method (behavior-preserving)**

Add:

```swift
/// OBBBA Senior Bonus (2025–2028), available on BOTH the standard and itemized paths.
/// Per qualifying senior (65+), phased out by `seniorBonusPhaseoutRate` over the
/// filing-status threshold. Mirrors the block previously inline in `standardDeduction`.
private func seniorBonusDeduction(
    filingStatus: FilingStatus, primaryAge: Int, spouseAge: Int?,
    year: Int, federalAGI: Double
) -> Double {
    let cfg = configProvider.config(forYear: year)
    guard year >= cfg.seniorBonusFirstYear && year <= cfg.seniorBonusLastYear else { return 0 }
    var qualifyingSeniors = 0
    if primaryAge >= 65 { qualifyingSeniors += 1 }
    if filingStatus == .marriedFilingJointly, let s = spouseAge, s >= 65 { qualifyingSeniors += 1 }
    guard qualifyingSeniors > 0 else { return 0 }
    let base = cfg.seniorBonusPerPerson * Double(qualifyingSeniors)
    let threshold = filingStatus == .marriedFilingJointly
        ? cfg.seniorBonusPhaseoutMFJ : cfg.seniorBonusPhaseoutSingle
    let reduction = max(0, (federalAGI - threshold) * cfg.seniorBonusPhaseoutRate)
    return max(0, base - reduction)
}
```

Then in `standardDeduction`, delete the two inline senior-bonus blocks (`:1138-1143` single, `:1153-1164` MFJ) and after the age-65 additions add:

```swift
amount += seniorBonusDeduction(filingStatus: filingStatus, primaryAge: primaryAge,
                               spouseAge: spouseAge, year: year, federalAGI: federalAGI)
```

- [ ] **Step 3: Run the full existing ProjectionEngine test suite to confirm no regression**

Run: `-only-testing:RetireSmartIRATests` scoped to projection tests (`grep -rln "ProjectionEngine" RetireSmartIRATests`). Expected: all previously-green tests still PASS (behavior-preserving).

- [ ] **Step 4: Commit**

```bash
git add RetireSmartIRA/ProjectionEngine.swift RetireSmartIRATests/ProjectionEngineDeductionTests.swift
git commit -m "refactor(multiyear): extract seniorBonusDeduction so itemized path can reuse it"
```

---

### Task 3: Create the `MultiYearItemizedDeduction` pure helper

**Files:**
- Create: `RetireSmartIRA/MultiYearItemizedDeduction.swift`
- Test: `RetireSmartIRATests/MultiYearItemizedDeductionTests.swift` (new)

**Interfaces:**
- Produces:
  - `MultiYearItemizedDeduction.saltCap(year:magi:config:) -> Double`
  - `.deductibleMedical(gross:agi:config:) -> Double`
  - `.deductibleCharitableCash(cash:agi:year:config:) -> Double`
  - `.nonItemizerCashCharitable(cash:filingStatus:year:config:) -> Double`
  - `.itemizedTotal(stateIncomeTax:otherSALT:mortgageAndOther:grossMedical:cashCharitable:seniorBonus:agi:filingStatus:year:config:) -> Double` (effective, after §68)
- Consumes: `TaxYearConfig` fields verified present: `saltExpandedFirstYear`, `saltExpandedLastYear`, `saltBaseYear`, `saltBaseCap`, `saltInflationRate`, `saltPhaseoutBaseThreshold`, `saltPhaseoutRate`, `saltFloor`, `saltDefaultCap`, `medicalAGIFloorRate`, `charitableCashAGICeilingRate`, `itemizedCharitableAGIFloorRate`, `itemizedCharitableAGIFloorFirstYear`, `itemizedOverallLimitationRate`, `itemizedOverallLimitationFirstYear`, `nonItemizerCashCharitableCapSingle`, `nonItemizerCashCharitableCapMFJ`, `nonItemizerCashCharitableFirstYear`, `federalBracketsSingle`, `federalBracketsMFJ`. (Confirm the SALT field names first: `grep -n "salt" RetireSmartIRA/TaxYearConfig.swift` — use the exact names.)

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
@testable import RetireSmartIRA

private var cfg2026: TaxYearConfig { TaxYearConfig.config(forYear: 2026) }  // or the project's accessor; confirm

@Test func medicalFloorAppliedAtSevenPointFivePercent() {
    // gross 20k, AGI 100k -> floor 7.5k -> deductible 12.5k
    #expect(MultiYearItemizedDeduction.deductibleMedical(gross: 20_000, agi: 100_000, config: cfg2026) == 12_500)
    #expect(MultiYearItemizedDeduction.deductibleMedical(gross: 5_000, agi: 100_000, config: cfg2026) == 0)
}

@Test func charitableCashCeilingAndHalfPercentFloor() {
    // AGI 100k: 60% ceiling = 60k; 0.5% floor = 500. cash 10k -> min(10k,60k)-500 = 9_500
    #expect(MultiYearItemizedDeduction.deductibleCharitableCash(cash: 10_000, agi: 100_000, year: 2026, config: cfg2026) == 9_500)
    // cash above 60% ceiling: cash 80k, AGI 100k -> 60k - 500 = 59_500
    #expect(MultiYearItemizedDeduction.deductibleCharitableCash(cash: 80_000, agi: 100_000, year: 2026, config: cfg2026) == 59_500)
}

@Test func nonItemizerCapByFilingStatus() {
    #expect(MultiYearItemizedDeduction.nonItemizerCashCharitable(cash: 5_000, filingStatus: .single, year: 2026, config: cfg2026) == 1_000)
    #expect(MultiYearItemizedDeduction.nonItemizerCashCharitable(cash: 5_000, filingStatus: .marriedFilingJointly, year: 2026, config: cfg2026) == 2_000)
    #expect(MultiYearItemizedDeduction.nonItemizerCashCharitable(cash: 500, filingStatus: .single, year: 2026, config: cfg2026) == 500)
}

@Test func itemizedTotalSumsComponentsBelowSixtyEightThreshold() {
    // Low AGI so §68 does not bite. SALT 12k(state)+0 other, cap high; mortgage 8k; no medical;
    // charitable cash 10k (AGI 100k -> 9_500); senior bonus 0.
    let total = MultiYearItemizedDeduction.itemizedTotal(
        stateIncomeTax: 12_000, otherSALT: 0, mortgageAndOther: 8_000,
        grossMedical: 0, cashCharitable: 10_000, seniorBonus: 0,
        agi: 100_000, filingStatus: .single, year: 2026, config: cfg2026)
    // salt = min(12_000, saltCap) — 2026 expanded cap ~40k, so 12_000. total = 12_000+8_000+9_500 = 29_500
    #expect(total == 29_500)
}
```

- [ ] **Step 2: Run to verify failure** — Expected: FAIL to compile (`MultiYearItemizedDeduction` undefined).

- [ ] **Step 3: Implement the helper**

```swift
import Foundation

/// Pure, dependency-free replica of the single-year itemized-deduction rules, for the
/// multi-year ProjectionEngine. Cash-only charitable (no stock); no carryforward; no AMT.
/// Mirrors DataManager.saltCap / deductibleMedicalExpenses / deductibleCharitableDeductions /
/// itemizedOverallLimitationReduction / nonItemizerCharitableDeduction. Guarded by a parity test.
enum MultiYearItemizedDeduction {

    /// OBBBA SALT cap for the year (expanded base × inflation, MAGI phaseout, floor; else default).
    static func saltCap(year: Int, magi: Double, config cfg: TaxYearConfig) -> Double {
        guard year >= cfg.saltExpandedFirstYear && year <= cfg.saltExpandedLastYear else {
            return cfg.saltDefaultCap
        }
        let mult = pow(1.0 + cfg.saltInflationRate, Double(year - cfg.saltBaseYear))
        let expandedCap = (cfg.saltBaseCap * mult).rounded()
        let threshold = (cfg.saltPhaseoutBaseThreshold * mult).rounded()
        let reduction = max(0, (magi.rounded() - threshold) * cfg.saltPhaseoutRate)
        return max(cfg.saltFloor, expandedCap - reduction)
    }

    static func deductibleMedical(gross: Double, agi: Double, config cfg: TaxYearConfig) -> Double {
        max(0, gross - cfg.medicalAGIFloorRate * max(0, agi))
    }

    /// Cash charitable after the 60%-AGI ceiling then the 0.5%-AGI floor (2026+).
    static func deductibleCharitableCash(cash: Double, agi: Double, year: Int, config cfg: TaxYearConfig) -> Double {
        let a = max(0, agi)
        let ceilinged = min(max(0, cash), cfg.charitableCashAGICeilingRate * a)
        let floor = year >= cfg.itemizedCharitableAGIFloorFirstYear ? cfg.itemizedCharitableAGIFloorRate * a : 0
        return max(0, ceilinged - floor)
    }

    /// OBBBA §170(p) below-the-line cash deduction for standard-deduction takers.
    static func nonItemizerCashCharitable(cash: Double, filingStatus: FilingStatus, year: Int, config cfg: TaxYearConfig) -> Double {
        guard year >= cfg.nonItemizerCashCharitableFirstYear else { return 0 }
        let cap = filingStatus == .marriedFilingJointly ? cfg.nonItemizerCashCharitableCapMFJ : cfg.nonItemizerCashCharitableCapSingle
        return min(max(0, cash), cap)
    }

    /// Effective itemized total (after the §68 overall limitation). seniorBonus is passed in
    /// because it applies on both paths; the caller computes it once.
    static func itemizedTotal(
        stateIncomeTax: Double, otherSALT: Double, mortgageAndOther: Double,
        grossMedical: Double, cashCharitable: Double, seniorBonus: Double,
        agi: Double, filingStatus: FilingStatus, year: Int, config cfg: TaxYearConfig
    ) -> Double {
        let salt = min(max(0, stateIncomeTax) + max(0, otherSALT), saltCap(year: year, magi: agi, config: cfg))
        let medical = deductibleMedical(gross: grossMedical, agi: agi, config: cfg)
        let charitable = deductibleCharitableCash(cash: cashCharitable, agi: agi, year: year, config: cfg)
        let beforeLimit = salt + max(0, mortgageAndOther) + medical + charitable + max(0, seniorBonus)

        guard year >= cfg.itemizedOverallLimitationFirstYear else { return beforeLimit }
        let brackets = filingStatus == .marriedFilingJointly ? cfg.federalBracketsMFJ : cfg.federalBracketsSingle
        let topThreshold = brackets.map(\.threshold).max() ?? 0
        let excess = max(0, agi - topThreshold)   // agi already net of above-the-line, = single-year incomeBeforeItemized
        let reduction = cfg.itemizedOverallLimitationRate * min(beforeLimit, excess)
        return max(0, beforeLimit - reduction)
    }
}
```

Add the file to the Xcode target: `RetireSmartIRA.xcodeproj/project.pbxproj` — follow the pattern of a recent sibling (e.g. how `QCDPlanner.swift` is referenced). If building via `xcodebuild` auto-discovers sources this is a no-op; verify the test compiles.

- [ ] **Step 4: Run tests to verify they pass** — Expected: PASS. If a config-accessor name differs (`TaxYearConfig.config(forYear:)`), fix the test helper to the real accessor found via grep.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/MultiYearItemizedDeduction.swift RetireSmartIRATests/MultiYearItemizedDeductionTests.swift RetireSmartIRA.xcodeproj/project.pbxproj
git commit -m "feat(multiyear): pure itemized-deduction helper (SALT cap, medical, charitable, §68, §170p)"
```

---

### Task 4: Add carried itemizable inputs to `MultiYearStaticInputs`

**Files:**
- Modify: `RetireSmartIRA/MultiYearStaticInputs.swift` (struct fields :115-119, `init` params + assignments, `withClaimAge` :208-252)
- Test: `RetireSmartIRATests/MultiYearStaticInputsTests.swift` (add or create)

**Interfaces:**
- Produces: three new `let` fields on `MultiYearStaticInputs`, all `Double`, all defaulting to `0` in `init`:
  `carriedMortgageAndOtherItemized`, `carriedPropertyAndOtherSALT`, `carriedGrossMedicalExpenses`.

- [ ] **Step 1: Write the failing test**

```swift
@Test func staticInputsDefaultCarriedItemizablesToZero() {
    let s = makeMinimalInputs()   // reuse an existing test factory; grep MultiYearStaticInputs( in tests
    #expect(s.carriedMortgageAndOtherItemized == 0)
    #expect(s.carriedPropertyAndOtherSALT == 0)
    #expect(s.carriedGrossMedicalExpenses == 0)
}
```

- [ ] **Step 2: Run to verify failure** — Expected: FAIL to compile (unknown members).

- [ ] **Step 3: Add the fields**

After the `charitableGivingPlan` field (:119) add:
```swift
    // Itemizable deductions carried from the single-year scenario (flat nominal). SALT here is
    // property + other non-income-tax SALT; the state INCOME tax is computed per year in the engine.
    let carriedMortgageAndOtherItemized: Double
    let carriedPropertyAndOtherSALT: Double
    let carriedGrossMedicalExpenses: Double
```
Add matching `init` params with `= 0` defaults (place them right after `charitableGivingPlan: CharitableGivingPlan = .none,`), the three `self.x = x` assignments, and pass all three through `withClaimAge`'s reconstruction call.

- [ ] **Step 4: Run to verify pass** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/MultiYearStaticInputs.swift RetireSmartIRATests/MultiYearStaticInputsTests.swift
git commit -m "feat(multiyear): carry mortgage/other, property/SALT, and gross medical into static inputs"
```

---

### Task 5: Seed the carried itemizables in `MultiYearInputAdapter`

**Files:**
- Modify: `RetireSmartIRA/MultiYearInputAdapter.swift` (near the giving seed :239-290)
- Test: `RetireSmartIRATests/MultiYearInputAdapterTests.swift` (add or create)

**Interfaces:**
- Consumes single-year `DataManager` values. Confirm exact source names first:
  `grep -n "nonSALTNonMedical\|totalMedicalExpenses\|propertyTax\|deductionItems" RetireSmartIRA/DataManager.swift`.
  Expected sources: `nonSALTNonMedical` sum (mortgage + other; from `deductionItems` excluding property/salt/medical — replicate the filter used in `baseItemizedDeductions:1841-1843`), property+other-SALT (sum of `deductionItems` of type `.propertyTax` and non-income `.saltTax`), and `totalMedicalExpenses` (pre-floor).

- [ ] **Step 1: Write the failing test**

```swift
@Test func adapterSeedsCarriedItemizablesFromSingleYear() {
    let dm = DataManager()
    dm.selectedState = .texas
    // add a mortgage-interest deduction item and a property-tax item and medical via the DM API
    // (grep how tests add deductionItems: `grep -rn "deductionItems" RetireSmartIRATests`)
    // ...set mortgage 8_000, property 6_000, medical 4_000...
    let inputs = MultiYearInputAdapter.build(from: dm)   // confirm actual builder signature
    #expect(inputs.carriedMortgageAndOtherItemized == 8_000)
    #expect(inputs.carriedPropertyAndOtherSALT == 6_000)
    #expect(inputs.carriedGrossMedicalExpenses == 4_000)
}
```

- [ ] **Step 2: Run to verify failure** — Expected: FAIL (fields seeded as 0 / test asserts nonzero).

- [ ] **Step 3: Seed in the adapter**

In the `MultiYearStaticInputs(...)` construction inside `build`, pass:
```swift
    carriedMortgageAndOtherItemized: dataManager.deductionItems
        .filter { $0.type != .propertyTax && $0.type != .saltTax && $0.type != .medicalExpenses }
        .reduce(0) { $0 + $1.annualAmount },
    carriedPropertyAndOtherSALT: dataManager.deductionItems
        .filter { $0.type == .propertyTax || $0.type == .saltTax }
        .reduce(0) { $0 + $1.annualAmount },
    carriedGrossMedicalExpenses: dataManager.totalMedicalExpenses,
```
(Adjust member/enum names to those confirmed by grep. If `.saltTax` here would double-count the auto-estimated state income tax, exclude it — the engine adds per-year state income tax itself; `carriedPropertyAndOtherSALT` must be property + *manually entered non-income* SALT only.)

- [ ] **Step 4: Run to verify pass** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/MultiYearInputAdapter.swift RetireSmartIRATests/MultiYearInputAdapterTests.swift
git commit -m "feat(multiyear): seed carried itemizables from the single-year scenario"
```

---

### Task 6: Wire per-year standard-vs-itemized selection into `ProjectionEngine`

**Files:**
- Modify: `RetireSmartIRA/ProjectionEngine.swift:695-731` (deduction/tax block + state-tax reorder), and the QCD block (:418-445) to capture cash charitable.
- Test: `RetireSmartIRATests/ProjectionEngineItemizingTests.swift` (new)

**Interfaces:**
- Consumes: `MultiYearItemizedDeduction`, `seniorBonusDeduction`, `QCDPlanner.YearlyQCD.target`, the three carried inputs.
- Produces: per-year `taxableIncome`/`federalTax` reflect the lower-tax deduction path. No new public API.

- [ ] **Step 1: Write the failing tests** (behavioral, through a full projection)

```swift
import Testing
@testable import RetireSmartIRA

@Test func bigCashGiftYearItemizesAndLowersTax() {
    // TX (no state income tax), single, AGI high enough that a large cash gift beats the std deduction.
    // Build inputs with a fixedAnnualAmount giving plan of e.g. $60k funded all-cash (funding .fixedQCD(0)
    // or ineligible for QCD), carriedMortgageAndOtherItemized 5_000.
    // Compare lifetime/first-year federal tax WITH the gift vs a control plan with no giving.
    // Expect the gift year's federal tax to be strictly lower than the same year with std-only.
    // (Assert on ProjectionResult year rows — grep the result type: `grep -rn "struct.*ProjectionResult\|YearRecommendation" RetireSmartIRA`.)
}

@Test func smallCashGiftUsesStandardPlus170p() {
    // TX, single, small $500 cash gift, no other itemizables. Household should stay on the standard
    // path but taxable income drops by exactly the §170(p) amount ($500) vs. no gift.
}

@Test func bunchingBeatsSpreading() {
    // Same total giving ($30k over 3 yrs). Plan A: $30k in a single high-conversion year.
    // Plan B: $10k/yr flat. Assert Plan A's 3-year total federal tax <= Plan B's (bunching advantage).
}
```
Fill each test body using the project's existing ProjectionEngine test factories (`grep -rn "ProjectionEngine(" RetireSmartIRATests | head`) and result accessors. Pin `state: "TX"`.

- [ ] **Step 2: Run to verify failure** — Expected: FAIL (engine still standard-only; itemize/§170(p) effects absent).

- [ ] **Step 3: Capture cash charitable in the QCD block**

Where `QCDPlanner.plan(...)` is called (:430), keep the result and compute:
```swift
let givingTarget = q.target
let cashCharitable = max(0, givingTarget - q.total)   // non-QCD remainder, deductible as cash
```
Hoist `cashCharitable` (default 0 when `!hasGiving`) to a `var` visible at the deduction block below.

- [ ] **Step 4: Move state-tax computation above the deduction block and select the path**

Move the `let stateTax = computeStateTax(...)` call (currently :721-731) to *before* the `stdDed` line (:695). Then replace the standard-only computation (:695-718) with:

```swift
let seniorBonus = seniorBonusDeduction(
    filingStatus: inputs.filingStatus, primaryAge: primaryAge,
    spouseAge: spouseAge, year: year, federalAGI: federalAGI)

// Standard path: base standard deduction (already includes seniorBonus) + §170(p) non-itemizer cash.
let stdDed = standardDeduction(filingStatus: inputs.filingStatus, primaryAge: primaryAge,
                               spouseAge: spouseAge, year: year, federalAGI: federalAGI)
let nonItemizerCash = MultiYearItemizedDeduction.nonItemizerCashCharitable(
    cash: cashCharitable, filingStatus: inputs.filingStatus, year: year,
    config: configProvider.config(forYear: year))
let standardDeductionTotal = stdDed + nonItemizerCash

// Itemized path (effective, after §68). state income tax = this year's computed state tax.
let itemizedTotal = MultiYearItemizedDeduction.itemizedTotal(
    stateIncomeTax: stateTax, otherSALT: inputs.carriedPropertyAndOtherSALT,
    mortgageAndOther: inputs.carriedMortgageAndOtherItemized,
    grossMedical: inputs.carriedGrossMedicalExpenses, cashCharitable: cashCharitable,
    seniorBonus: seniorBonus, agi: federalAGI, filingStatus: inputs.filingStatus,
    year: year, config: configProvider.config(forYear: year))

// Choose the path with lower federal tax (compare actual tax, not deduction size — LTCG stacking).
let brackets = configProvider.config(forYear: year).toTaxBrackets()
func federalTax(forDeduction deduction: Double) -> Double {
    let ti = max(0, federalAGI - deduction)
    let pref = min(max(0, totalPreferentialIncome), ti)
    return TaxCalculationEngine.calculateFederalTax(
        income: ti, filingStatus: inputs.filingStatus, brackets: brackets, preferentialIncome: pref)
}
let taxStandard = federalTax(forDeduction: standardDeductionTotal)
let taxItemized = federalTax(forDeduction: itemizedTotal)
let useItemized = taxItemized < taxStandard
let chosenDeduction = useItemized ? itemizedTotal : standardDeductionTotal
let taxableIncome = max(0, federalAGI - chosenDeduction)
let taxablePreferential = min(max(0, totalPreferentialIncome), taxableIncome)
let federalTax = min(taxStandard, taxItemized)
```
Remove the now-relocated `stateTax` block at the old site. If any later code referenced the old `stdDed`-only `taxableIncome`, it now reads the selected value (unchanged variable names `taxableIncome`, `taxablePreferential`, `federalTax`).

- [ ] **Step 5: Run the new tests to verify pass** — Expected: PASS. Iterate on test constants using computed expectations if the crossover point differs.

- [ ] **Step 6: Commit**

```bash
git add RetireSmartIRA/ProjectionEngine.swift RetireSmartIRATests/ProjectionEngineItemizingTests.swift
git commit -m "feat(multiyear): per-year standard-vs-itemized selection with deductible cash charitable"
```

---

### Task 7: Single-year parity test

Guards the multi-year helper against drifting from `DataManager`.

**Files:**
- Test: `RetireSmartIRATests/MultiYearItemizedParityTests.swift` (new)

- [ ] **Step 1: Write the parity test**

```swift
@Test func multiYearItemizedMatchesSingleYearForIdenticalInputs() {
    let dm = DataManager()
    dm.selectedState = .texas           // avoid the CA SALT-itemize confound
    // Set: cash donation 20_000, mortgage 8_000, medical 6_000, property tax 6_000, AGI-driving income
    // via the DM API so single-year computes a known federalAGI. (grep the setters used in
    // existing DataManager tests.)
    let agi = dm.estimatedAGI            // confirm accessor name
    let helperItemized = MultiYearItemizedDeduction.itemizedTotal(
        stateIncomeTax: 0,               // TX: no state income tax
        otherSALT: 6_000,                // property tax
        mortgageAndOther: 8_000,
        grossMedical: 6_000,
        cashCharitable: 20_000,
        seniorBonus: dm.seniorBonusDeductionAmount,   // confirm accessor
        agi: agi, filingStatus: dm.filingStatus, year: dm.currentYear,
        config: TaxYearConfig.config(forYear: dm.currentYear))
    // single-year effective itemized (after §68) = totalItemizedDeductions - itemizedOverallLimitationReduction
    let singleYear = dm.totalItemizedDeductions - dm.itemizedOverallLimitationReduction
    #expect(abs(helperItemized - singleYear) < 0.01)
}
```
Adjust accessor names to the real ones (grep). If single-year includes stock donations, keep `stockDonationEnabled` false so both are cash-only.

- [ ] **Step 2: Run to verify pass** (implementation already exists). Expected: PASS. If it fails, the helper and single-year genuinely disagree — reconcile the helper to `DataManager` (single-year is the reference), do not loosen the tolerance.

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRATests/MultiYearItemizedParityTests.swift
git commit -m "test(multiyear): parity between itemized helper and single-year DataManager"
```

---

### Task 8: MFJ end-to-end integration test (QCD + cash + limit-to-IRMAA)

Also closes a pre-existing 2.1 follow-up.

**Files:**
- Test: `RetireSmartIRATests/MultiYearGivingIntegrationTests.swift` (new)

- [ ] **Step 1: Write the test**

```swift
@Test func mfjGivingWithQCDAndCashUnderLimitToIRMAA() {
    // MFJ, both 72+ (QCD-eligible), TX. Giving plan: fixedAnnualAmount(40_000), funding .qcdFirst.
    // QCD covers part (up to per-person limit + IRA balance), cash covers the remainder and is deducted.
    // Run optimize(approach: .limitToIRMAA(tier, buffer)) and assert:
    //   - QCD reduces taxable RMD (AGI) AND cash remainder appears as an itemized deduction in gift years
    //   - the resulting MAGI stays within the chosen IRMAA tier (approach honored)
    // Use the approach-comparison / optimize entry points (grep: `optimize(approach:`).
}
```
Fill using the real optimize/approach API. Pin `state: "TX"`.

- [ ] **Step 2: Run to verify pass** — Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add RetireSmartIRATests/MultiYearGivingIntegrationTests.swift
git commit -m "test(multiyear): MFJ QCD+cash giving under limit-to-IRMAA end-to-end"
```

---

### Task 9: Update the UI disclosure + full-suite green + rebaseline review

**Files:**
- Modify: `RetireSmartIRA/ConversionApproachSection.swift:220` (giving disclosure copy)

- [ ] **Step 1: Update the disclosure copy**

Replace the line at :220:
```swift
Text("Cash gifts beyond what QCDs cover aren't deducted in this projection (a future update adds full itemized modeling).")
```
with:
```swift
Text("Cash gifts are deducted in the year they're made (standard vs. itemized chosen per year, using itemizable deductions carried from your current-year scenario). Charitable carryforward and AMT aren't modeled in the projection.")
```
Keep the existing `.font`/`.foregroundStyle` modifiers on the line.

- [ ] **Step 2: Run the FULL suite and capture rebaselines**

```bash
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' \
  -resultBundlePath /tmp/rsira-full.xcresult 2>&1 | tail -5
xcrun xcresulttool get test-results summary --path /tmp/rsira-full.xcresult
```
Expected: green EXCEPT optimizer/projection tests whose numbers shift because the deduction now changes optimal conversions.

- [ ] **Step 3: Review each failing (rebaselined) test individually**

For every failure, confirm the NEW number is correct (the deduction legitimately changed the optimum) before updating the expectation. Do NOT blanket-update. A test that changed for a reason unrelated to deductions is a real regression — stop and investigate. Update expectations only for verified-correct shifts.

- [ ] **Step 4: Re-run the full suite to confirm green**

```bash
xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' \
  -resultBundlePath /tmp/rsira-full2.xcresult 2>&1 | tail -5
xcrun xcresulttool get test-results summary --path /tmp/rsira-full2.xcresult
```
Expected: all green. Confirm total count ≥ the prior 1,757 + the new tests.

- [ ] **Step 5: Commit**

```bash
git add RetireSmartIRA/ConversionApproachSection.swift RetireSmartIRATests/
git commit -m "feat(multiyear): surface cash-charitable deduction in giving disclosure; rebaseline optimizer tests"
```

---

## Self-Review

- **Spec coverage:** Inputs (Task 4/5) ✓; per-year standard-vs-itemized with §170(p), 60% ceiling, 0.5% floor, §68, SALT-cap phaseout, medical floor, senior bonus (Task 2/3/6) ✓; cash = target − QCD (Task 1/6) ✓; state-tax reorder (Task 6) ✓; optimizer picks up deduction + rebaselines (Task 9) ✓; parity guard (Task 7) ✓; MFJ end-to-end (Task 8) ✓; UI disclosure (Task 9) ✓; flat-nominal / no-carryforward / no-AMT / cash-only honored via Global Constraints ✓.
- **Placeholders:** Test bodies in Tasks 6/8 are described with exact assertions and pinned state but defer to the project's existing test factories/result accessors (named via grep) rather than inventing signatures — deliberate, since those helpers exist in-repo and inventing names would be wrong. Every production-code step shows complete code.
- **Type consistency:** `carriedMortgageAndOtherItemized` / `carriedPropertyAndOtherSALT` / `carriedGrossMedicalExpenses`, `YearlyQCD.target`, and the `MultiYearItemizedDeduction` signatures are used identically across Tasks 3–8.
- **Follow-up noted:** consolidating `DataManager`'s itemized computed vars onto `MultiYearItemizedDeduction` (single source of truth) is deliberately deferred to avoid churning single-year tests; the parity test (Task 7) guards drift until then.
