//
//  DecumulationLTCGTests.swift
//  RetireSmartIRATests
//
//  Decumulation step 1 (2.1): qualified dividends + long-term capital gains are taxed at the
//  federal LTCG schedule, not lumped into ordinary income (the documented "Path A" over-tax).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Decumulation: LTCG/qual-div preferential rates", .serialized)
@MainActor
struct DecumulationLTCGTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func inputs(ordinary: Double, preferential: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 66,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "CA",
            primarySSClaimAge: 70,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 2026 - 66,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            primaryOtherOrdinaryIncome: ordinary, spouseOtherOrdinaryIncome: 0,
            primaryPreferentialIncome: preferential, spousePreferentialIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
    }

    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0.0,
            investmentGrowthRate: 0.0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0)
    }

    @Test("$50K of qualified-div/LTCG income is taxed less than $50K of ordinary income")
    func preferentialTaxedLessThanOrdinary() {
        let ord = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(ordinary: 50_000, preferential: 0), assumptions: assumptions(),
            actionsPerYear: [2026: []])
        let pref = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(ordinary: 0, preferential: 50_000), assumptions: assumptions(),
            actionsPerYear: [2026: []])

        // Same AGI (preferential income is still in AGI)…
        #expect(abs(ord[0].agi - pref[0].agi) < 1.0)
        // …but the preferential federal tax is strictly lower (LTCG schedule incl. the 0% bracket).
        #expect(pref[0].taxBreakdown.federal < ord[0].taxBreakdown.federal,
            "preferential fed tax \(pref[0].taxBreakdown.federal) should be < ordinary \(ord[0].taxBreakdown.federal)")
    }

    @Test("Adapter routes qualified dividends + LTCG to the preferential bucket")
    func adapterClassifiesPreferential() {
        let dm = DataManager(skipPersistence: true)
        dm.incomeSources = [
            IncomeSource(name: "QDI", type: .qualifiedDividends, annualAmount: 20_000, owner: .primary),
            IncomeSource(name: "LTCG", type: .capitalGainsLong, annualAmount: 30_000, owner: .primary),
            IncomeSource(name: "Int", type: .interest, annualAmount: 5_000, owner: .primary),
        ]
        let built = MultiYearInputAdapter.build(
            from: dm, scenarioState: dm.scenario, assumptions: MultiYearAssumptions())
        #expect(built.primaryPreferentialIncome == 50_000)   // QDI + LTCG
        #expect(built.primaryOtherOrdinaryIncome == 5_000)   // interest stays ordinary
    }
}
