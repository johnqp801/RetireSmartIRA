import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("Taxable aggressiveness")
struct TaxableAggressivenessTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }
    private func inputs(taxable: [TaxableAccountInput]) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_500_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 64, spouseCurrentAge: nil, filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil, primaryBirthYear: 1962, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 60_000, taxableAccounts: taxable)
    }
    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(horizonEndAge: 90, horizonEndAgeSpouse: nil, cpiRate: 0.02,
            investmentGrowthRate: 0.05, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
    }
    private func totalConverted(_ r: OptimizationEngine.Result) -> Double {
        r.recommendedPath.reduce(0) { acc, yr in acc + yr.actions.reduce(0) { a, act in
            if case let .rothConversion(amount) = act { return a + amount }; return a } }
    }

    @Test("low-basis taxable (big embedded gain) makes the optimizer convert no MORE than high-basis")
    func gainsRestrain() {
        let highBasis = TaxableAccountInput(balance: 400_000, costBasis: 400_000, protectedAmount: 0,
            appreciationRate: 0.05, qualifiedDividendYield: 0.02, ordinaryIncomeYield: 0, taxExemptYield: 0,
            realizedLongTermGainYield: 0, availableForExpenses: true, availableForConversionTaxes: true,
            fundingPriority: nil)
        let lowBasis = TaxableAccountInput(balance: 400_000, costBasis: 40_000, protectedAmount: 0,
            appreciationRate: 0.05, qualifiedDividendYield: 0.02, ordinaryIncomeYield: 0, taxExemptYield: 0,
            realizedLongTermGainYield: 0, availableForExpenses: true, availableForConversionTaxes: true,
            fundingPriority: nil)
        let rHigh = OptimizationEngine().optimize(inputs: inputs(taxable: [highBasis]),
            assumptions: assumptions(), configProvider: provider)
        let rLow = OptimizationEngine().optimize(inputs: inputs(taxable: [lowBasis]),
            assumptions: assumptions(), configProvider: provider)
        // Selling low-basis assets to pay conversion tax realizes gains, so converting is costlier:
        // the low-basis plan must not convert MORE than the high-basis plan.
        #expect(totalConverted(rLow) <= totalConverted(rHigh) + 1.0)
    }
}
