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

