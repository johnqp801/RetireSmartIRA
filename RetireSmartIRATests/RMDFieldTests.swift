import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("YearRecommendation.rmd field")
struct RMDFieldTests {
    private func sampleBreakdown() -> TaxBreakdown { .zero }
    private func sampleSnapshot() -> AccountSnapshot {
        AccountSnapshot(primaryTraditional: 0, spouseTraditional: 0, roth: 0, taxable: 0, hsa: 0)
    }

    @Test("rmd defaults to 0 when omitted (back-compat)")
    func defaultsToZero() {
        let yr = YearRecommendation(
            year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: sampleBreakdown(), endOfYearBalances: sampleSnapshot(), actions: [])
        #expect(yr.rmd == 0)
    }

    @Test("rmd is retained when supplied")
    func retainsValue() {
        let yr = YearRecommendation(
            year: 2026, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: sampleBreakdown(), endOfYearBalances: sampleSnapshot(), actions: [],
            rmd: 40_650)
        #expect(yr.rmd == 40_650)
    }
}

@Suite("ProjectionEngine populates rmd", .serialized)
@MainActor
struct RMDPopulationTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func inputs(age: Int, birthYear: Int, trad: Double) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: trad, roth: 0, taxable: 5_000_000, hsa: 0),
            baseYear: 2026, primaryCurrentAge: age, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: birthYear, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0,
            heirSalary: 75_000, heirFilingStatus: .single, heirDrawdownYears: 10)
    }
    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(horizonEndAge: 80, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 5_000_000, currentHSABalance: 0)
    }
    private func emptyActions(_ inp: MultiYearStaticInputs, _ a: MultiYearAssumptions) -> [Int: [LeverAction]] {
        var m: [Int: [LeverAction]] = [:]
        for y in inp.baseYear...(inp.baseYear + a.horizonEndAge - inp.primaryCurrentAge) { m[y] = [] }
        return m
    }

    @Test("year-1 rmd equals the IRS RMD for an RMD-age owner")
    func rmdPopulatedAtAge() {
        let inp = inputs(age: 75, birthYear: 1951, trad: 1_000_000)   // rmdAge 73 → applies
        let a = assumptions()
        let path = ProjectionEngine(configProvider: provider).project(
            inputs: inp, assumptions: a, actionsPerYear: emptyActions(inp, a))
        let expected = RMDCalculationEngine.calculateRMD(for: 75, balance: 1_000_000)
        #expect(abs((path.first?.rmd ?? -1) - expected) < 1.0)
        #expect(expected > 0)
    }

    @Test("rmd is 0 before RMD age")
    func rmdZeroBeforeAge() {
        let inp = inputs(age: 70, birthYear: 1956, trad: 1_000_000)   // rmdAge 73 → not yet
        let a = assumptions()
        let path = ProjectionEngine(configProvider: provider).project(
            inputs: inp, assumptions: a, actionsPerYear: emptyActions(inp, a))
        #expect(path.first?.rmd == 0)
    }
}
