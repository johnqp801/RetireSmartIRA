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
            perYearOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
        a.taxPaymentSource = src; return a
    }

    @Test("gross-up pulls conversion tax from traditional when taxable is empty") func grossUp() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 0), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        #expect(p[0].endOfYearBalances.primaryTraditional < 600_000)
        #expect(p[0].endOfYearBalances.taxable == 0)
    }
    @Test(".external leaves trad at start minus conversion (legacy)") func external() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 0), assumptions: assumptions(.external),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        #expect(abs(p[0].endOfYearBalances.primaryTraditional - 600_000) < 1.0)
    }
    @Test("ample taxable: gross-up does not fire") func ample() {
        let g = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 1_000_000), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 200_000)]])
        let e = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 1_000_000), assumptions: assumptions(.external),
            actionsPerYear: [2026: [.rothConversion(amount: 200_000)]])
        #expect(abs(g[0].endOfYearBalances.primaryTraditional - e[0].endOfYearBalances.primaryTraditional) < 1.0)
        #expect(g[0].underfunded == nil)
    }
    @Test("gross-up shows up as a traditional withdrawal action") func visibleAction() {
        let p = ProjectionEngine(configProvider: provider).project(
            inputs: inputs(trad: 1_000_000, taxable: 0), assumptions: assumptions(.taxableThenGrossUp),
            actionsPerYear: [2026: [.rothConversion(amount: 400_000)]])
        let withdrawals = p[0].actions.compactMap { act -> Double? in
            if case let .traditionalWithdrawal(a) = act { return a }; return nil }
        #expect(withdrawals.contains { $0 > 0 })
    }
}
