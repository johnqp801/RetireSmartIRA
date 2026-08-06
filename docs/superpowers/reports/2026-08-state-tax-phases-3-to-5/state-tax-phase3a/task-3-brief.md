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

**The exactness requirement:** `njPersonalExemptions` grants the spouse's amounts only when `filingStatus == .marriedFilingJointly && enableSpouse`. A filer on MFJ with no spouse configured gets the single amounts. `amount(...)` must reproduce that, which is why it takes `enableSpouse` rather than filing status alone.

**Know which test actually guards this, because it is not the obvious one.** The behavior baseline from Task 1 does NOT cover it. `calculateStateTax` never computes a personal exemption; it receives the finished figure as `postExemptionDeduction`, and the baseline passes that as a literal. So an `amount(...)` that keyed the spouse amounts off filing status alone, returning 4,000 where the old code returned 2,000, would leave all 1,020 baseline values untouched. The real guards are `NJOtherExclusionAndExemptionsTests`, which calls `njPersonalExemptions` directly and will exercise the new path once Step 7 makes it a delegating shim, and the Step 1 tests below. Write those two carefully; the phase gate will not save you here.

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

