### Task 6: Data-driven Roth conversion exemption

Spec §3.3b. `TaxCalculationEngine.swift:687-695` is a hardcoded `switch state` over PA, IL and MS. Iowa belongs in it and would be the first age-gated member, which a `switch` cannot express.

**Files:**
- Create: `RetireSmartIRA/StateRothConversionExemption.swift`
- Modify: `RetireSmartIRA/StateTaxData.swift` (field, plus PA, IL and MS configs)
- Modify: `RetireSmartIRA/StateTaxCodable.swift`
- Modify: `RetireSmartIRA/TaxCalculationEngine.swift` (delete the `switch state`)
- Test: `RetireSmartIRATests/StateTaxPhase3aMechanismTests.swift`

> **PLAN CORRECTION, 2026-08-03.** Like Task 3, this task gives real states non-default values
> in the legacy Swift table, so it MUST regenerate the 51 JSON files as its final step or the
> Phase 1 Layer B structural gate fails on PA, IL and MS, and their conversion exemptions
> regress on the production path. Layer C needs no change here: `rothConversionExemption` is
> nested inside `retirementExemptions`, not a new top-level key.

**Interfaces:**
- Produces: `RothConversionExemption` and `RetirementIncomeExemptions.rothConversionExemption: RothConversionExemption?` (default `nil`, meaning conversion income is taxable, which is 48 jurisdictions' behavior).

- [ ] **Step 1: Write the failing test**

```swift
    // MARK: - Roth conversion exemption

    @Test("Pennsylvania still exempts only the net amount deposited into the Roth")
    func pennsylvaniaExemptsNetOfWithholdingViaConfig() {
        func tax(withholding: Double) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: 100_000, forState: .pennsylvania, filingStatus: .single,
                taxableSocialSecurity: 0, incomeSources: [], currentAge: 62,
                enableSpouse: false, spouseBirthYear: 1964, currentYear: 2026,
                scenarioRothConversionAmount: 100_000,
                scenarioRothConversionWithholdingAmount: withholding)
        }
        // PA rate 3.07%. Full conversion exempt when nothing is withheld.
        #expect(tax(withholding: 0) == 0)
        // $22,000 withheld stays PA-taxable: 22,000 x 0.0307 = 675.40.
        #expect(abs(tax(withholding: 22_000) - 675.40) < 0.005)
    }

    @Test("Illinois and Mississippi exempt the gross conversion regardless of withholding")
    func illinoisAndMississippiExemptGrossViaConfig() {
        for state in [USState.illinois, USState.mississippi] {
            let taxed = TaxCalculationEngine.calculateStateTax(
                income: 100_000, forState: state, filingStatus: .single,
                taxableSocialSecurity: 0, incomeSources: [], currentAge: 62,
                enableSpouse: false, spouseBirthYear: 1964, currentYear: 2026,
                scenarioRothConversionAmount: 100_000,
                scenarioRothConversionWithholdingAmount: 22_000)
            #expect(taxed == 0, "\(state.abbreviation) should exempt the gross conversion")
        }
    }

    @Test("A conversion exemption can be age-gated, which the hardcoded switch could not express")
    func rothConversionExemptionCanBeAgeGated() {
        let config = Self.flatTenPercent(exemptions: RetirementIncomeExemptions(
            socialSecurityExempt: true,
            rothConversionExemption: RothConversionExemption(
                minAge: 55, withheldPortionRemainsTaxable: false)))

        func tax(age: Int) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: 100_000, forState: .iowa, filingStatus: .single,
                taxableSocialSecurity: 0, incomeSources: [], currentAge: age,
                enableSpouse: false, spouseBirthYear: 2026 - age, currentYear: 2026,
                scenarioRothConversionAmount: 100_000,
                configOverride: config)
        }
        #expect(tax(age: 54) == 10_000)   // below the gate, fully taxed
        #expect(tax(age: 55) == 0)        // at the gate, exempt
    }

    @Test("Exactly PA, IL and MS carry a conversion exemption in Phase 3a")
    func onlyThreeStatesCarryAConversionExemption() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        let withExemption = USState.allCases.filter {
            configs[$0]?.retirementExemptions.rothConversionExemption != nil
        }
        #expect(Set(withExemption) == Set([.pennsylvania, .illinois, .mississippi]),
                "Phase 3a moves the existing PA/IL/MS rule into config and adds no state. \
                Iowa is Phase 5a. Found: \(withExemption.map(\.abbreviation).sorted())")
        // PA is the only one whose withheld portion stays taxable.
        #expect(configs[.pennsylvania]?.retirementExemptions
            .rothConversionExemption?.withheldPortionRemainsTaxable == true)
        #expect(configs[.illinois]?.retirementExemptions
            .rothConversionExemption?.withheldPortionRemainsTaxable == false)
        // No state is age-gated yet, so a stray default of 59 would be visible.
        for state in withExemption {
            #expect(configs[state]?.retirementExemptions
                .rothConversionExemption?.minAge == 0)
        }
    }
```

- [ ] **Step 2: Run it, watch it fail**

Expected: `cannot find 'RothConversionExemption' in scope`. Paste it.

- [ ] **Step 3: Create the type**

Create `RetireSmartIRA/StateRothConversionExemption.swift`:

```swift
import Foundation

/// A state's treatment of Roth conversion income in the conversion year.
///
/// Before Phase 3a this was a `switch state` over Pennsylvania, Illinois and
/// Mississippi inside `TaxCalculationEngine.applyRetirementExemptions`. Iowa
/// exempts conversion income by name for anyone 55 or older (HF 2317), which a
/// `switch` with no age concept could not express, and which matters more than
/// any other single defect in the 2026-08-02 audit: this app exists to
/// optimize Roth conversions, and for an Iowa user it currently invents state
/// tax on that exact transaction.
///
/// nil, the default, means conversion income is fully taxable. That is the
/// correct treatment for 48 jurisdictions.
struct RothConversionExemption: Codable, Equatable, Sendable {
    /// Minimum age for the exemption. 0 means no age gate, which is Ans 274's
    /// position for Pennsylvania and the practitioner reading for Illinois and
    /// Mississippi: none of the three conditions the exemption on retirement
    /// age. Iowa will be 55.
    let minAge: Int

    /// Pennsylvania DOR Ans 274 holds the exemption applies only where the full
    /// pre-tax balance reaches the Roth, so any amount withheld for federal tax
    /// is a taxable distribution. Illinois and Mississippi publish no
    /// equivalent condition, so they exempt the gross.
    let withheldPortionRemainsTaxable: Bool
}
```

- [ ] **Step 4: Add the field and configure the three states**

In `RetirementIncomeExemptions`, after `agiPhaseout`:

```swift
    /// How the state treats Roth conversion income in the conversion year.
    /// nil (the default) means fully taxable.
    var rothConversionExemption: RothConversionExemption? = nil
```

In `StateTaxData.swift`, `configs[.pennsylvania]`'s `RetirementIncomeExemptions`:

```swift
                // PA DOR Ans 274: a trustee-to-trustee conversion is not a
                // taxable event, but only the portion actually deposited into
                // the Roth qualifies, so federal withholding taken from the
                // conversion stays PA-taxable. Lift-and-shift of the switch
                // this replaces, not a Phase 3a correction.
                rothConversionExemption: RothConversionExemption(
                    minAge: 0, withheldPortionRemainsTaxable: true),
```

and in `configs[.illinois]` and `configs[.mississippi]`:

```swift
                // IL Pub 120 / MS Code 27-7-15(4)(j) per practitioner
                // consensus: the conversion is exempt, with no documented
                // full-balance condition, so withholding does not reduce it.
                rothConversionExemption: RothConversionExemption(
                    minAge: 0, withheldPortionRemainsTaxable: false),
```

- [ ] **Step 5: Replace the `switch state` in the engine**

Delete the entire `switch state { case .pennsylvania: ... case .illinois, .mississippi: ... default: break }` block and its now-stale explanatory comment, and put in its place:

```swift
        // Roth conversion treatment, config-driven since Phase 3a. The rule
        // and the Ans 274 withholding caveat that used to live in a
        // `switch state` here now live on each state's config; see
        // RothConversionExemption for the citations.
        if let conversionRule = exemptions.rothConversionExemption {
            let qualifies = conversionRule.minAge == 0
                || effectiveAge >= conversionRule.minAge
            if qualifies {
                let exemptAmount = conversionRule.withheldPortionRemainsTaxable
                    ? max(0, scenarioRothConversionAmount - scenarioRothConversionWithholdingAmount)
                    : scenarioRothConversionAmount
                adjusted -= exemptAmount
            }
        }
```

`effectiveAge` is already in scope and is `max(primaryAge, spouseAge)` when a spouse is enabled. Since no state is age-gated in Phase 3a the branch is unreachable, and Iowa's Phase 4 golden scenario decides whether that is the right age for a conversion under `.perQualifyingSpouse`.

- [ ] **Step 6: Codable and round-trip**

Add `rothConversionExemption` to `CodingKeys`, `encodeIfPresent` to `encode(to:)`, `decodeIfPresent` to `init(from:)`. Add to `StateTaxCodableRoundTripTests.swift`:

```swift
    @Test("RothConversionExemption round-trips both variants with distinct values")
    func rothConversionExemptionRoundTrips() throws {
        // minAge non-zero in one case and the Bool differing between them, so
        // neither field can be dropped without a test noticing.
        let cases = [
            RothConversionExemption(minAge: 0, withheldPortionRemainsTaxable: true),
            RothConversionExemption(minAge: 55, withheldPortionRemainsTaxable: false)
        ]
        for original in cases {
            let decoded = try JSONDecoder().decode(
                RothConversionExemption.self, from: JSONEncoder().encode(original))
            #expect(decoded == original)
        }
    }
```

- [ ] **Step 7: Run the mechanism tests, the baseline, the PA and conversion suites**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && xcodebuild test -scheme RetireSmartIRA -destination 'platform=macOS' -only-testing:RetireSmartIRATests/StateTaxPhase3aMechanismTests -only-testing:RetireSmartIRATests/StateTaxBehaviorBaselineTests -only-testing:RetireSmartIRATests/StateRetirementExemptionTests 2>&1 | tail -25
```

The baseline's three conversion scenarios are the inertness proof for this task, and they include the withholding case specifically so a PA regression to gross-exemption is visible.

- [ ] **Step 8: Full suite, then commit**

```bash
cd /Users/johnurban/Projects/RetireSmartIRA/.worktrees/state-tax-phase3a && git add -A && git commit -m "feat(state-tax): move the Roth conversion rule from a switch statement into config"
```

---


---

## CONTROLLER ADDENDUM, 2026-08-03: a second hardcoded switch the plan does not mention

The plan's Task 6 names only `TaxCalculationEngine.applyRetirementExemptions`'s
`switch state` (around line 746). There is a SECOND one, in the breakdown mirror:

`RetireSmartIRA/DataManager.swift:888-897`

```swift
        let conversionExemptAmt: Double = {
            switch state {
            case .pennsylvania:
                return max(0, scenarioTotalRothConversion - scenarioRothConversionWithholdingAmount)
            case .illinois, .mississippi:
                return scenarioTotalRothConversion
            default:
                return 0
            }
        }()
```

Its own comment says it "Mirrors TaxCalculationEngine.applyRetirementExemptions logic."
Convert it too, reading `config.retirementExemptions.rothConversionExemption` the same way
the engine does, so the two cannot drift.

This is the THIRD time this phase that a mirror in `DataManager` was missed by a brief
written from the engine alone. Task 2 replaced the engine's hardcoded retirement age and
left two hardcoded 59s in this same file; Task 5's review found them. Before you finish,
grep for any OTHER place that hardcodes these three states and report what you find:

```bash
grep -rn "case .pennsylvania\|case .illinois\|case .mississippi\|== .pennsylvania\|== .illinois\|== .mississippi" --include="*.swift" RetireSmartIRA/ | grep -v abbreviation
```

Two UI files also reference Pennsylvania directly:
`RothConversionWithholdingCard.swift:40` and `MultiYearTaxFundingCard.swift:61`, both
gating PA-specific disclosure copy on `state == .pennsylvania`. Do NOT convert those in
this task. They are display copy rather than tax math, and changing them is a scope
decision, not a mechanical one. Report them in your report so the decision is recorded
rather than forgotten.
