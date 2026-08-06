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

