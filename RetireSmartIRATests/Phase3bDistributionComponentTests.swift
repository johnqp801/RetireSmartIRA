//
//  Phase3bDistributionComponentTests.swift
//  RetireSmartIRATests
//
//  Task 3: TaxCalculationEngine and its DataManager mirror take an optional
//  `distributionComponents` list alongside the existing
//  `scenarioRetirementDistributions` scalar. This task pools the components
//  into ONE figure and hands it to the EXISTING age-gate and exemption logic
//  unchanged -- see
//  docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
//  section 3.4 and 3.4a, and the plan's departure note on why the scalar
//  parameter is not replaced.
//
//  Task 3 is behavior-inert: no jurisdiction's numbers may move here. The
//  frozen baseline (StateTaxBehaviorBaselineTests) is the gate for that; this
//  suite proves the NEW machinery itself -- component/scalar equivalence, the
//  sum invariant's debug-trap gate and release fallback, that pooling (not
//  per-component capping) is what actually happens, and that a component's
//  `owner` field is carried but inert in this phase.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 3b Task 3: distribution components pool into the existing scalar path")
struct Phase3bDistributionComponentTests {

    // MARK: - Step 1, bullet 1: a single unknown component equals the scalar path exactly

    @Test("A single .unknown component reproduces scalar-only calculateStateTax, across a grid of states and ages")
    func singleUnknownComponentMatchesScalarAcrossStatesAndAges() {
        let distribution = 45_000.0
        let states: [USState] = [.newYork, .pennsylvania, .colorado, .california, .texas, .illinois, .georgia]
        let ages = [40, 55, 59, 60, 65, 70]

        for state in states {
            for age in ages {
                let scalarOnly = TaxCalculationEngine.calculateStateTax(
                    income: distribution, forState: state, filingStatus: .single,
                    taxableSocialSecurity: 0, incomeSources: [],
                    currentAge: age, enableSpouse: false, spouseBirthYear: 2026 - age,
                    currentYear: 2026, scenarioRetirementDistributions: distribution)

                let withComponent = TaxCalculationEngine.calculateStateTax(
                    income: distribution, forState: state, filingStatus: .single,
                    taxableSocialSecurity: 0, incomeSources: [],
                    currentAge: age, enableSpouse: false, spouseBirthYear: 2026 - age,
                    currentYear: 2026, scenarioRetirementDistributions: distribution,
                    distributionComponents: [RetirementDistributionComponent(
                        owner: .primary, structure: .unknown, source: .unknown, amount: distribution)])

                #expect(withComponent == scalarOnly,
                        "\(state.abbreviation) age \(age): component path (\(withComponent)) must equal scalar path (\(scalarOnly))")
            }
        }
    }

    // MARK: - Step 1, bullet 2: the sum invariant (spec 3.4), debug trap and release fallback tested separately

    /// The exact boolean condition `resolvePooledAmount` traps on in debug
    /// and falls back on in release. Tested directly, on its own, because
    /// calling `resolvePooledAmount` (or any calculateStateTax path) with a
    /// violating input would call `assertionFailure`, which aborts the
    /// whole test process by design in a debug build -- the same reason
    /// `StateTaxJSONEquivalenceTests.resolveConfigsFallsBackPerStateToItsOwnLegacyEntry`
    /// exercises `StateTaxDataLoader.resolveConfigs` directly rather than
    /// `configs2026`. This test is that same discipline applied to the sum
    /// invariant: it is the "debug trap" half of the evidence, kept
    /// separate from the "release fallback" half below.
    /// Step 0c (Task 4 review fold-in): `sumInvariantBoundary` below only
    /// proves the tolerance lies somewhere in `[0.005, 0.02)` -- two probe
    /// points bracketing an interval, not the value itself. This asserts the
    /// named constant directly.
    @Test("sumInvariantTolerance is exactly one cent")
    func sumInvariantToleranceIsOneCent() {
        #expect(RetirementDistributionComponent.sumInvariantTolerance == 0.01)
    }

    @Test("sumInvariantHolds: comfortably within one cent passes, comfortably past one cent fails")
    func sumInvariantBoundary() {
        let components = [
            RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 20_000),
            RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 20_000)
        ]
        // Half a cent off (well inside the spec's `<= 0.01` tolerance, with
        // enough margin that Double's binary representation of 40_000.005
        // cannot flip the comparison the way an exact 0.01 literal risks
        // doing -- `abs(40_000.0 - 40_000.01)` is not reliably `<= 0.01` at
        // this magnitude once Double rounding is accounted for, which is
        // exactly what tripped this suite's debug trap for real before this
        // test was widened away from the exact edge).
        #expect(RetirementDistributionComponent.sumInvariantHolds(components: components, scalar: 40_000.005))
        #expect(RetirementDistributionComponent.sumInvariantHolds(components: components, scalar: 39_999.995))
        // Two cents off is comfortably past the boundary -- this is the
        // condition that gates resolvePooledAmount's debug trap.
        #expect(!RetirementDistributionComponent.sumInvariantHolds(components: components, scalar: 40_000.02))
        #expect(!RetirementDistributionComponent.sumInvariantHolds(components: components, scalar: 39_999.98))
    }

    /// The "release fallback" half: `fallbackAmount` is the value
    /// `resolvePooledAmount` returns once `assertionFailure` has compiled
    /// away to a no-op in a release build. Deliberately does not touch
    /// `assertionFailure` or `sumInvariantFallbackFired`, mirroring
    /// `StateTaxDataLoader.resolveConfigs`'s own "without touching the
    /// debug trap" test.
    @Test("fallbackAmount resolves to the scalar, not the wrong pooled total, when the invariant fails")
    func fallbackAmountUsesScalarWhenInvariantFails() {
        let components = [
            RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 20_000),
            RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 20_000)
        ]
        // Off by $500: production's release build must fall back to the
        // caller's scalar, not the (wrong) $40,000 the components sum to.
        #expect(RetirementDistributionComponent.fallbackAmount(components: components, scalar: 40_500) == 40_500)
    }

    @Test("fallbackAmount pools normally when the invariant holds")
    func fallbackAmountPoolsWhenInvariantHolds() {
        let components = [
            RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 20_000),
            RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 20_000)
        ]
        #expect(RetirementDistributionComponent.fallbackAmount(components: components, scalar: 40_000) == 40_000)
    }

    @Test("sumInvariantFallbackFired stays false when nothing has violated the invariant")
    func fallbackFlagStaysFalseInNormalOperation() {
        // Mirrors StateTaxJSONEquivalenceTests.legacyFallbackDidNotFireInNormalOperation:
        // proves the flag reads false after exercising the REAL resolution
        // path (resolvePooledAmount, not the non-trapping helpers above)
        // with valid input. There is no reset -- see the flag's doc
        // comment -- so this suite never deliberately sets it true; doing
        // so would permanently flip it for the remainder of this (parallel)
        // test run, exactly the flakiness `StateTaxDataLoader.legacyFallbackFired`
        // was designed to avoid by never being set from a test either.
        _ = RetirementDistributionComponent.resolvePooledAmount(
            components: [RetirementDistributionComponent(
                owner: .primary, structure: .unknown, source: .unknown, amount: 10_000)],
            scalar: 10_000)
        #expect(RetirementDistributionComponent.sumInvariantFallbackFired == false)
    }

    // MARK: - Pooling, not per-component capping (spec 3.4a) -- and proof the parameter is actually consumed

    /// Exploits the slack the invariant itself allows: components summing
    /// to exactly $10,000 against a scalar of $9,999.995 is half a cent
    /// off, comfortably within the spec's `<= 0.01` tolerance, so this does
    /// not trip the debug trap (the components' own amounts are whole
    /// dollars, so their sum is exact in Double -- only the scalar carries
    /// the fractional offset, avoiding the boundary-precision trap
    /// `sumInvariantBoundary` documents above). If the engine silently
    /// ignored `distributionComponents` and always used the bare scalar,
    /// the computed tax would equal the scalar-only run exactly. A `.full`
    /// exemption makes the pooled sum show up directly in `excludedAmount`'s
    /// eligible income, uncapped by total income (see
    /// `ExemptionLevel.excludedAmount` for `.full`: `return eligibleIncome`).
    @Test("Components genuinely pool: the resolved amount reflects their sum, not the bare scalar")
    func componentsAreActuallySummedNotSilentlyIgnored() {
        let fullIRAExemption = StateTaxConfig(
            state: .iowa, taxSystem: .flat(rate: 1.0),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false, pensionExemption: .none,
                iraWithdrawalExemption: .full),
            stateDeduction: .none)

        // income (15,000) exceeds the distribution (~10,000) so neither
        // case clips to $0 taxable -- the leftover $5,000-ish band is where
        // the half-cent difference must show up.
        let scalarTax = TaxCalculationEngine.calculateStateTax(
            income: 15_000, forState: .iowa, filingStatus: .single,
            taxableSocialSecurity: 0, incomeSources: [],
            currentAge: 65, enableSpouse: false, spouseBirthYear: 1961,
            currentYear: 2026, scenarioRetirementDistributions: 9_999.995,
            configOverride: fullIRAExemption)

        let pooledTax = TaxCalculationEngine.calculateStateTax(
            income: 15_000, forState: .iowa, filingStatus: .single,
            taxableSocialSecurity: 0, incomeSources: [],
            currentAge: 65, enableSpouse: false, spouseBirthYear: 1961,
            currentYear: 2026, scenarioRetirementDistributions: 9_999.995,
            distributionComponents: [
                RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 6_000),
                RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 4_000)
            ],
            configOverride: fullIRAExemption)

        #expect(abs(scalarTax - 5_000.005) < 0.0001, "$15,000 - $9,999.995 exempt, taxed at 100% = $5,000.005")
        #expect(abs(pooledTax - 5_000.0) < 0.0001, "$15,000 - $10,000 (component sum) exempt, taxed at 100% = $5,000.00")
        #expect(pooledTax != scalarTax,
                "components summing to $10,000 must exempt a DIFFERENT amount than the $9,999.995 scalar -- proves the component SUM feeds the calculation, not the bare scalar")
    }

    // MARK: - Task 4 review fold-in (Step 0a): pooling must not become a per-component cap loop

    /// Folded in from Task 3's review before Task 4 touched anything else.
    /// Every one of Task 3's own tests above uses `.full` treatment, where
    /// `excludedAmount` returns its input unchanged -- so per-component and
    /// pooled capping produce IDENTICAL numbers for every case above, and a
    /// reviewer confirmed a mutation applying the cap PER COMPONENT instead
    /// of to the pooled sum still passed all ten of Task 3's tests AND the
    /// 1,020-value frozen baseline. This is the exact historical New York
    /// bug (`StateTaxData.swift`'s `pensionAndIRAShareSingleCap` comment):
    /// the shared cap exists because an earlier version granted $20,000 to
    /// pension and another $20,000 to IRA. `.partial`, not `.full`, is what
    /// makes per-component-vs-pooled numerically distinguishable, because
    /// `.partial`'s cap only binds once the SUM crosses it -- two components
    /// each under the cap individually can still exceed it combined.
    @Test("The shared cap applies ONCE to the pooled component sum, not once per component")
    func capAppliesOncePooledNotPerComponent() {
        let partialIRAExemption = StateTaxConfig(
            state: .iowa, taxSystem: .flat(rate: 0.10),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false, pensionExemption: .none,
                iraWithdrawalExemption: .partial(maxExempt: 20_000)),
            stateDeduction: .none)

        let tax = TaxCalculationEngine.calculateStateTax(
            income: 60_000, forState: .iowa, filingStatus: .single,
            taxableSocialSecurity: 0, incomeSources: [],
            currentAge: 65, enableSpouse: false, spouseBirthYear: 1961,
            currentYear: 2026, scenarioRetirementDistributions: 30_000,
            distributionComponents: [
                RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 15_000),
                RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 15_000)
            ],
            configOverride: partialIRAExemption)

        #expect(tax == 4_000,
                """
                the $20,000 cap must apply ONCE to the $30,000 pooled total \
                (exclusion $20,000, taxable $40,000 @ 10% = $4,000), not once \
                per $15,000 component, which would exempt BOTH in full since \
                neither $15,000 alone crosses the cap ($60,000 - $30,000 = \
                $30,000 @ 10% = $3,000, the wrong answer a per-component loop \
                produces).
                """)
    }

    // MARK: - Capability, not activation: owner does not change the age gate in this phase

    /// `RetirementDistributionComponent` carries `owner` so a LATER phase
    /// can correct per-spouse attribution (spec 3.4). This phase does NOT
    /// activate it: components are pooled into one figure BEFORE the age
    /// gate runs, so the gate never sees which component an amount came
    /// from. This test documents that CAPABILITY -- the type carries
    /// `owner` and `.perQualifyingSpouse` is a real, reachable config value
    /// -- without asserting it changes anything, because it must not yet.
    /// No jurisdiction ships `.perQualifyingSpouse` (see
    /// `ExemptionAttribution`'s doc comment in StateTaxData.swift), so this
    /// is exercised only through `configOverride`, the same seam
    /// `StateTaxPhase3aMechanismTests.scenarioDistributionsAreAttributedToThePrimary`
    /// uses to pin that the pre-3b, ownerless scalar is attributed to the
    /// primary under `.perQualifyingSpouse`. This test is the Task 3
    /// analogue: a component's `owner` must not change that.
    @Test("Capability, inert: a spouse-owned component still gates on the same rule as the scalar, even under a synthetic perQualifyingSpouse config")
    func componentOwnerDoesNotChangeAttributionInThisPhase() {
        let perSpouseConfig = StateTaxConfig(
            state: .iowa, taxSystem: .flat(rate: 0.10),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false, pensionExemption: .full,
                iraWithdrawalExemption: .full, regularExemptionMinAge: 65,
                exemptionAttribution: .perQualifyingSpouse),
            stateDeduction: .none)

        func tax(owner: Owner) -> Double {
            TaxCalculationEngine.calculateStateTax(
                // Primary 60 is below the config's 65 gate; spouse 70 clears
                // it. scenarioDistributionsAreAttributedToThePrimary already
                // pins that the unowned scalar is gated on the primary
                // (taxed, not exempt) in this situation.
                income: 40_000, forState: .iowa, filingStatus: .marriedFilingJointly,
                taxableSocialSecurity: 0, incomeSources: [],
                currentAge: 60, enableSpouse: true, spouseBirthYear: 1956,
                currentYear: 2026, scenarioRetirementDistributions: 40_000,
                distributionComponents: [RetirementDistributionComponent(
                    owner: owner, structure: .unknown, source: .unknown, amount: 40_000)],
                configOverride: perSpouseConfig)
        }

        let primaryOwned = tax(owner: .primary)
        let spouseOwned = tax(owner: .spouse)
        #expect(primaryOwned == 4_000,
                "primary (60) is below the 65 gate: taxed under the same household-scalar rule the scalar path already pins")
        #expect(spouseOwned == primaryOwned,
                "a spouse-owned component must produce the SAME result as a primary-owned one in this phase -- owner attribution is a documented capability, not an activated rule")
    }
}

// MARK: - DataManager mirror

/// Task 3, Step 4: `DataManager.stateTaxBreakdown` hand-duplicates
/// `TaxCalculationEngine.applyRetirementExemptions`. This suite proves the
/// mirror's new `configOverride` test seam is actually honored, and that its
/// `distributionComponents` parameter feeds the SAME pooling logic the
/// engine tests above exercise (the invariant machinery itself,
/// `RetirementDistributionComponent.resolvePooledAmount`, is shared code
/// tested once above -- it is not reimplemented here, so it is not
/// re-tested here).
@MainActor
@Suite("Phase 3b Task 3: the DataManager mirror stays in sync")
struct Phase3bDistributionComponentMirrorTests {

    /// A DataManager aged for retirement-exemption eligibility (default
    /// distributionMinAge is 59), no spouse, no persistence I/O.
    private func makeMirrorScenario(age: Int) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        var dob = DateComponents(); dob.year = 2026 - age; dob.month = 1; dob.day = 1
        dm.profile.birthDate = Calendar.current.date(from: dob)!
        dm.profile.currentYear = 2026
        dm.filingStatus = .single
        return dm
    }

    @Test("A single .unknown component reproduces scalar-only stateTaxBreakdown")
    func mirrorSingleUnknownComponentMatchesScalar() {
        let dm = makeMirrorScenario(age: 65)
        dm.selectedState = .newYork
        dm.yourExtraWithdrawal = 10_000

        let scalarOnly = dm.stateTaxBreakdown(forState: .newYork, filingStatus: .single)
        let withComponent = dm.stateTaxBreakdown(
            forState: .newYork, filingStatus: .single,
            distributionComponents: [RetirementDistributionComponent(
                owner: .primary, structure: .unknown, source: .unknown, amount: 10_000)])

        #expect(withComponent.totalStateTax == scalarOnly.totalStateTax)
        #expect(withComponent.iraExemptAmount == scalarOnly.iraExemptAmount)
    }

    /// Phase 3a's Task 6 review named the absence of a config test seam as
    /// the reason the mirror's age-gate branch was proven by nothing while
    /// the engine's identical branch was proven by a test (the engine has
    /// always had `configOverride`). This is that seam, proven load-bearing
    /// the same way `StateTaxPhase3aMechanismTests` proves the engine's
    /// fields load-bearing: swap in a config that behaves differently from
    /// the real one and confirm the mirror responds.
    @Test("configOverride actually overrides the mirror's default StateTaxData lookup")
    func mirrorConfigOverrideIsHonored() {
        let dm = makeMirrorScenario(age: 65)
        dm.selectedState = .texas
        dm.yourExtraWithdrawal = 10_000

        let realTexas = dm.stateTaxBreakdown(forState: .texas, filingStatus: .single)
        #expect(realTexas.totalStateTax == 0, "Texas has no state income tax under the real bundled config")

        let flatTenPercentNoExemptions = StateTaxConfig(
            state: .texas, taxSystem: .flat(rate: 0.10),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false, pensionExemption: .none, iraWithdrawalExemption: .none),
            stateDeduction: .none)
        let overridden = dm.stateTaxBreakdown(
            forState: .texas, filingStatus: .single, configOverride: flatTenPercentNoExemptions)

        #expect(overridden.totalStateTax == 1_000,
                "configOverride must replace the real Texas config -- without this seam the mirror's own branches can only be exercised through real bundled states, which is the exact gap Phase 3a's Task 6 review flagged")
    }

    /// Same half-cent-slack proof as
    /// `Phase3bDistributionComponentTests.componentsAreActuallySummedNotSilentlyIgnored`,
    /// applied to the mirror. `iraExemptAmount` is `.full`'s eligible income
    /// directly (uncapped by total income), so no buffer income is needed
    /// to avoid clipping.
    @Test("The mirror pools distributionComponents into iraExemptAmount, not the bare scalar")
    func mirrorPoolsComponentsIntoIRAExemptAmount() {
        let dm = makeMirrorScenario(age: 65)
        dm.selectedState = .texas
        // Half a cent below the component sum below (10,000), comfortably
        // within the spec's <= 0.01 tolerance -- see
        // componentsAreActuallySummedNotSilentlyIgnored for why the
        // components carry whole dollars and the scalar carries the
        // fractional offset, avoiding the boundary-precision trap
        // sumInvariantBoundary documents.
        dm.yourExtraWithdrawal = 9_999.995

        let fullIRAExemption = StateTaxConfig(
            state: .texas, taxSystem: .flat(rate: 0.10),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false, pensionExemption: .none, iraWithdrawalExemption: .full),
            stateDeduction: .none)

        let scalarOnly = dm.stateTaxBreakdown(forState: .texas, filingStatus: .single, configOverride: fullIRAExemption)
        #expect(abs(scalarOnly.iraExemptAmount - 9_999.995) < 0.0001)

        let pooled = dm.stateTaxBreakdown(
            forState: .texas, filingStatus: .single, configOverride: fullIRAExemption,
            distributionComponents: [
                RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 6_000),
                RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 4_000)
            ])

        #expect(abs(pooled.iraExemptAmount - 10_000.0) < 0.0001,
                "must reflect the component SUM ($10,000), not the bare $9,999.995 scalar -- proves distributionComponents is actually consumed by the mirror, not accepted and discarded")
        #expect(pooled.iraExemptAmount != scalarOnly.iraExemptAmount)
    }

    /// Task 4 review fold-in (Step 0a), mirror side. Same worked case as
    /// `Phase3bDistributionComponentTests.capAppliesOncePooledNotPerComponent`:
    /// `.partial` is what makes per-component-vs-pooled numerically
    /// distinguishable, unlike every `.full`-based mirror test above.
    /// Reviewer's exact finding: a per-component cap loop makes
    /// `iraExemptAmount` read $30,000 (both $15,000 components pass under
    /// the cap individually) instead of the correct $20,000 (the pooled
    /// $30,000 total capped once).
    @Test("The mirror applies the shared cap ONCE to the pooled component sum, not once per component")
    func mirrorCapAppliesOncePooledNotPerComponent() {
        let dm = makeMirrorScenario(age: 65)
        dm.selectedState = .texas
        dm.yourExtraWithdrawal = 30_000

        let partialIRAExemption = StateTaxConfig(
            state: .texas, taxSystem: .flat(rate: 0.10),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false, pensionExemption: .none,
                iraWithdrawalExemption: .partial(maxExempt: 20_000)),
            stateDeduction: .none)

        let pooled = dm.stateTaxBreakdown(
            forState: .texas, filingStatus: .single, configOverride: partialIRAExemption,
            distributionComponents: [
                RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 15_000),
                RetirementDistributionComponent(owner: .primary, structure: .unknown, source: .unknown, amount: 15_000)
            ])

        #expect(pooled.iraExemptAmount == 20_000,
                """
                the $20,000 cap must apply once to the pooled $30,000 total, \
                not once per $15,000 component -- a per-component loop would \
                exempt both in full (iraExemptAmount == 30,000, since neither \
                $15,000 alone exceeds the cap), which is exactly the \
                historical New York double-$20,000 bug reproduced at the \
                component level.
                """)
    }
}
