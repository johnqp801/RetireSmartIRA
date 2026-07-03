import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Frontier retains per-weight paths", .serialized)
@MainActor
struct FrontierPathRetentionTests {
    @Test("each frontier point carries the optimizer path for its weight")
    func pointsCarryPaths() {
        let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 88, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1938, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0, heirSalary: 150_000, heirFilingStatus: .single, heirDrawdownYears: 10)
        let a = MultiYearAssumptions(horizonEndAge: 95, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
        let r = HeirFrontierCoordinator().computeFrontier(inputs: inputs, assumptions: a, configProvider: provider)
        for p in r.points {
            #expect(!p.recommendedPath.isEmpty)
        }
        let direct = OptimizationEngine().optimize(inputs: inputs, assumptions: a, configProvider: provider, heirWeight: 0)
        #expect(r.points.first(where: { $0.weight == 0 })?.recommendedPath.count == direct.recommendedPath.count)
    }
}
