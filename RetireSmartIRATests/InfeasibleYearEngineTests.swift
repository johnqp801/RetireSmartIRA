//
//  InfeasibleYearEngineTests.swift
//  RetireSmartIRATests
//
//  V2.3: when assets cannot fund the converged tax requirement, the engine must stop
//  presenting the plan as valid. Before this, `underfunded` was recorded and the
//  projection simply continued with part of the tax bill unpaid.
//
//  The gate is deliberately NOT `underfunded > 0`. The gross-up fixed point runs at
//  most 3 iterations and stops at a $1.00 tolerance, so comfortably funded years carry
//  a small convergence residue. Genuine insolvency is "the gross-up was clamped by
//  available traditional assets", which these tests exercise from both sides.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Infeasible-year marking", .serialized)
@MainActor
struct InfeasibleYearEngineTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func makeInputs(trad: Double, taxable: Double, state: String) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: taxable, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 66, spouseCurrentAge: nil,
            filingStatus: .single, state: state,
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1960, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
    }

    /// Inputs carrying a FIRST-CLASS taxable account. `AccountSnapshot(taxable:)` alone puts the
    /// engine in legacy mode, where the synthesized bucket's basis tracks its balance and
    /// `saleGain` is identically zero. Supplying the account explicitly with `costBasis < balance`
    /// is the only way to exercise the realized-gain tax-funding path.
    private func makeInputs(trad: Double, brokerage: TaxableAccountInput,
                            pension: Double = 0, state: String) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 66, spouseCurrentAge: nil,
            filingStatus: .single, state: state,
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1960, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: pension, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            taxableAccounts: [brokerage]
        )
    }

    /// A large appreciated brokerage account: zero basis, so every sale realizes a gain.
    private func appreciatedBrokerage(balance: Double) -> TaxableAccountInput {
        TaxableAccountInput(
            balance: balance, costBasis: 0, protectedAmount: 0, appreciationRate: 0,
            qualifiedDividendYield: 0, ordinaryIncomeYield: 0, taxExemptYield: 0,
            realizedLongTermGainYield: 0, availableForExpenses: true,
            availableForConversionTaxes: true, fundingPriority: nil)
    }

    private func makeAssumptions(horizonEndAge: Int) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(
            horizonEndAge: horizonEndAge, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0, baselineAnnualExpenses: 0)
        a.rothTaxFundingMode = .fundedFromAccounts
        return a
    }

    /// Tiny balances against a large forced conversion: the tax cannot be funded.
    ///
    /// The conversion consumes the entire traditional balance, so nothing is left to
    /// gross up from and the fixed point clamps at `availableTrad`.
    private func starvedRun() -> [YearRecommendation] {
        // `actionsPerYear` decides WHICH years project, so later years must be listed
        // (with empty action arrays) for the propagation assertions to have anything
        // to inspect.
        ProjectionEngine(configProvider: provider).project(
            inputs: makeInputs(trad: 60_000, taxable: 0, state: "CA"),
            assumptions: makeAssumptions(horizonEndAge: 70),
            actionsPerYear: [
                2026: [.rothConversion(amount: 60_000)],
                2027: [], 2028: [], 2029: []
            ])
    }

    @Test("In the starved scenario, every underfunded year is marked infeasible")
    func shortfallMarksInfeasible() {
        // Scoped to `starvedRun` ONLY. "Underfunded implies infeasible" is deliberately NOT an
        // engine-wide invariant: `grossUpResidueIsNotInfeasible` and the brokerage-funded tests
        // below assert its negation on solvent scenarios, where an underfunded balance is mere
        // convergence residue. What makes the implication hold here is the scenario itself, which
        // exhausts BOTH funding sources (zero taxable, and a conversion that eats all of
        // traditional), so any shortfall it reports is real insolvency.
        let years = starvedRun()
        let bad = years.filter { ($0.underfunded ?? 0) > 1.0 }
        #expect(bad.isEmpty == false, "test setup should produce a shortfall")
        for y in bad {
            #expect(y.isInfeasible == true)
            #expect(y.isFullyFunded == false)
        }
    }

    @Test("The starved scenario really does exhaust traditional assets")
    func starvedScenarioActuallyExhaustsAssets() {
        // Guards the test itself: if the balances ever stop producing genuine insolvency,
        // the assertions above would pass vacuously.
        let years = starvedRun()
        let first = years.first!
        #expect(first.isInfeasible == true, "year 1 must be the genuine insolvency")
        #expect((first.underfunded ?? 0) > 1.0, "an unfunded balance must remain")
        // Insolvency means nothing is left in traditional: the conversion took it all and
        // the gross-up had nothing to clamp onto.
        #expect(first.endOfYearBalances.traditional < 1.0,
                "the gross-up must have been clamped by exhausted traditional assets")
        #expect(first.dependsOnInfeasibleYear == false,
                "the first failure depends on no earlier failure")
    }

    @Test("The requested conversion is NOT reduced")
    func conversionNotReduced() {
        let years = starvedRun()
        guard let first = years.first(where: { $0.isInfeasible }) else {
            Issue.record("scenario produced no infeasible year")
            return
        }
        // V2.3 preserves the request for diagnosis. Auto-reduction would require solving
        // conversion and funding jointly, which is out of scope.
        #expect(first.executedRothConversion > 0)
    }

    @Test("Years after an infeasible year are marked unreliable")
    func laterYearsMarkedUnreliable() {
        let years = starvedRun()
        guard let idx = years.firstIndex(where: { $0.isInfeasible }) else {
            Issue.record("scenario produced no infeasible year")
            return
        }
        #expect(idx + 1 < years.count, "there must be later years to inspect")
        for later in years[(idx + 1)...] {
            #expect(later.dependsOnInfeasibleYear == true)
            #expect(later.isFullyFunded == false)
        }
    }

    @Test("A fundable plan marks nothing infeasible")
    func fundablePlanIsClean() {
        let years = ProjectionEngine(configProvider: provider).project(
            inputs: makeInputs(trad: 400_000, taxable: 400_000, state: "FL"),
            assumptions: makeAssumptions(horizonEndAge: 70),
            actionsPerYear: [
                2026: [.rothConversion(amount: 20_000)],
                2027: [], 2028: [], 2029: []
            ])
        #expect(years.isEmpty == false)
        #expect(years.allSatisfy { $0.isFullyFunded })
    }

    @Test("A funded gross-up year is NOT infeasible despite convergence residue")
    func grossUpResidueIsNotInfeasible() {
        // Ample traditional, zero taxable: this forces a large gross-up that converges
        // with headroom to spare. The 3-iteration fixed point leaves a small residual
        // `underfunded` that must NOT read as insolvency.
        let years = ProjectionEngine(configProvider: provider).project(
            inputs: makeInputs(trad: 2_000_000, taxable: 0, state: "CA"),
            assumptions: makeAssumptions(horizonEndAge: 68),
            actionsPerYear: [2026: [.rothConversion(amount: 300_000)], 2027: []])
        let first = years.first!
        #expect(first.taxFundingWithdrawal > 0, "scenario must actually force a gross-up")
        // The residue is what makes this test meaningful: without it, a `> 0` gate would
        // pass here too and the test would prove nothing.
        #expect((first.underfunded ?? 0) > 1.0,
                "scenario must actually leave convergence residue for the gate to survive")
        #expect(first.endOfYearBalances.traditional > 1_000_000,
                "assets must NOT have been exhausted; there is ample headroom")
        #expect(first.isInfeasible == false,
                "convergence residue is not insolvency; assets were never exhausted")
        #expect(years.allSatisfy { $0.dependsOnInfeasibleYear == false })
    }

    @Test("A near-miss year with thin headroom is still not infeasible")
    func thinHeadroomIsNotInfeasible() {
        // 80k traditional against a 60k conversion leaves only 20k to gross up from, and
        // the gross-up consumes about 7.4k of it. Residue remains but roughly 12.6k of
        // traditional survives, so the fixed point was never clamped. Guards against the
        // gate being retightened into a "balance looks low" heuristic.
        let years = ProjectionEngine(configProvider: provider).project(
            inputs: makeInputs(trad: 80_000, taxable: 0, state: "CA"),
            assumptions: makeAssumptions(horizonEndAge: 70),
            actionsPerYear: [2026: [.rothConversion(amount: 60_000)], 2027: [], 2028: []])
        let first = years.first!
        #expect(first.taxFundingWithdrawal > 0, "scenario must force a gross-up")
        #expect(first.endOfYearBalances.traditional > 1.0, "headroom must remain")
        #expect(first.isInfeasible == false)
        #expect(years.allSatisfy { $0.isFullyFunded })
    }

    /// The flagship V2.3 workflow: convert what is left of the IRA and pay the tax from a large
    /// appreciated brokerage account. The conversion consumes the whole traditional balance, so
    /// `availableTrad` reaches zero, but the household is nowhere near insolvent: millions of
    /// liquid taxable dollars remain. Only an exhausted traditional balance AND an exhausted
    /// taxable balance is genuine insolvency.
    ///
    /// This account is first-class with `costBasis: 0`, so bucket sales realize real gains and the
    /// gain-on-gain sliver that Phase 1 intentionally leaves unfunded shows up as residue.
    @Test("Converting the whole IRA and paying from an appreciated brokerage is NOT infeasible")
    func brokerageFundedFullConversionIsNotInfeasible() {
        let years = ProjectionEngine(configProvider: provider).project(
            inputs: makeInputs(trad: 200_000,
                               brokerage: appreciatedBrokerage(balance: 2_000_000),
                               state: "CA"),
            assumptions: makeAssumptions(horizonEndAge: 70),
            actionsPerYear: [
                2026: [.rothConversion(amount: 200_000)],
                2027: [], 2028: [], 2029: []
            ])
        let first = years.first!
        #expect(first.executedRothConversion > 0, "scenario must actually convert")
        // The setup guard: traditional really is drained, so the `availableTrad` half of the gate
        // is satisfied and only the taxable half can save the year.
        #expect(first.endOfYearBalances.traditional < 1.0,
                "the conversion must consume the entire traditional balance")
        #expect(first.endOfYearBalances.taxable > 1_000_000,
                "the household must still hold ample liquid taxable assets")
        #expect(first.isInfeasible == false,
                "a household with millions in taxable assets is not insolvent")
        #expect(years.allSatisfy { $0.dependsOnInfeasibleYear == false },
                "no later year may inherit an unreliability flag from a solvent year")
    }

    /// No traditional balance at all, a large appreciated brokerage account, and a pension big
    /// enough to generate a real tax bill. `availableTrad` is zero from the first year onward, so
    /// every year satisfies the traditional half of the gate on its own.
    @Test("A household with no traditional assets but ample taxable is NOT infeasible")
    func noTraditionalWithAmpleTaxableIsNotInfeasible() {
        let years = ProjectionEngine(configProvider: provider).project(
            inputs: makeInputs(trad: 0,
                               brokerage: appreciatedBrokerage(balance: 2_000_000),
                               pension: 150_000, state: "CA"),
            assumptions: makeAssumptions(horizonEndAge: 70),
            actionsPerYear: [2026: [], 2027: [], 2028: [], 2029: []])
        #expect(years.isEmpty == false)
        #expect(years.first!.endOfYearBalances.taxable > 1_000_000,
                "the household must still hold ample liquid taxable assets")
        #expect(years.allSatisfy { $0.isInfeasible == false },
                "no year is insolvent while millions of taxable dollars remain")
        #expect(years.allSatisfy { $0.dependsOnInfeasibleYear == false })
    }
}
