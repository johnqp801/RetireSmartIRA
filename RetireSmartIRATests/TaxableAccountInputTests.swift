import Testing
@testable import RetireSmartIRA

@Suite("TaxableAccountInput")
struct TaxableAccountInputTests {
    @Test("MultiYearStaticInputs defaults taxableAccounts to empty and carries them when set")
    func carries() {
        let acct = TaxableAccountInput(
            balance: 100_000, costBasis: 60_000, protectedAmount: 0,
            appreciationRate: 0.05, qualifiedDividendYield: 0.01, ordinaryIncomeYield: 0.005,
            taxExemptYield: 0, realizedLongTermGainYield: 0,
            availableForExpenses: true, availableForConversionTaxes: true, fundingPriority: nil)
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 65, spouseCurrentAge: nil, filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil, primaryBirthYear: 1961, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0,
            taxableAccounts: [acct])
        #expect(inputs.taxableAccounts == [acct])

        let none = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 65, spouseCurrentAge: nil, filingStatus: .single, state: "FL",
            primarySSClaimAge: 70, spouseSSClaimAge: nil, primaryExpectedBenefitAtFRA: 0,
            spouseExpectedBenefitAtFRA: nil, primaryBirthYear: 1961, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0, primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1, primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil, baselineAnnualExpenses: 0)
        #expect(none.taxableAccounts.isEmpty)
    }
}
