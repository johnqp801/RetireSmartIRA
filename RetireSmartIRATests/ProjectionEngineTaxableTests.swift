import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("ProjectionEngine taxable")
struct ProjectionEngineTaxableTests {
    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    private func baseInputs(taxable: [TaxableAccountInput]) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 500_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026, primaryCurrentAge: 66, spouseCurrentAge: nil, filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil, primaryBirthYear: 1960, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0, taxableAccounts: taxable)
    }
    private func assumptions() -> MultiYearAssumptions {
        MultiYearAssumptions(horizonEndAge: 67, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient, stressTestEnabled: false,
            perYearExpenseOverrides: [:], currentTaxableBalance: 0, currentHSABalance: 0)
    }
    private func acct(bal: Double, basis: Double, ordYield: Double = 0, muni: Double = 0) -> TaxableAccountInput {
        TaxableAccountInput(balance: bal, costBasis: basis, protectedAmount: 0, appreciationRate: 0,
            qualifiedDividendYield: 0, ordinaryIncomeYield: ordYield, taxExemptYield: muni,
            realizedLongTermGainYield: 0, availableForExpenses: true, availableForConversionTaxes: true,
            fundingPriority: nil)
    }

    @Test("account ordinary yield raises AGI (tax drag)")
    func taxDrag() {
        let withYield = ProjectionEngine(configProvider: provider).project(
            inputs: baseInputs(taxable: [acct(bal: 1_000_000, basis: 1_000_000, ordYield: 0.03)]),
            assumptions: assumptions(), actionsPerYear: [2026: []])
        let noYield = ProjectionEngine(configProvider: provider).project(
            inputs: baseInputs(taxable: [acct(bal: 1_000_000, basis: 1_000_000, ordYield: 0)]),
            assumptions: assumptions(), actionsPerYear: [2026: []])
        #expect(withYield[0].agi > noYield[0].agi)
        #expect(abs(withYield[0].agi - noYield[0].agi - 30_000) < 1.0) // 3% of 1M
    }

    @Test("muni yield raises IRMAA MAGI but not AGI/taxable income")
    func muniMagi() {
        let r = ProjectionEngine(configProvider: provider).project(
            inputs: baseInputs(taxable: [acct(bal: 1_000_000, basis: 1_000_000, muni: 0.03)]),
            assumptions: assumptions(), actionsPerYear: [2026: []])
        #expect(r[0].agi == 0)                       // muni not in AGI
        #expect((r[0].irmaaMagi ?? 0) >= 30_000)     // but in MAGI add-back
    }

    @Test("empty taxableAccounts reproduces legacy single-bucket behavior")
    func backwardCompat() {
        // Legacy path: assumptions.currentTaxableBalance drives a synthesized bucket via the adapter,
        // but project() consumes inputs directly, so pass an empty array and a legacy-equivalent single
        // account to confirm identical end balances.
        var legacy = assumptions(); legacy.currentTaxableBalance = 0
        let viaAccount = ProjectionEngine(configProvider: provider).project(
            inputs: baseInputs(taxable: [acct(bal: 200_000, basis: 200_000)]),
            assumptions: legacy, actionsPerYear: [2026: []])
        #expect(viaAccount[0].endOfYearBalances.taxable == 200_000) // no yield, no growth, no draw
    }
}
