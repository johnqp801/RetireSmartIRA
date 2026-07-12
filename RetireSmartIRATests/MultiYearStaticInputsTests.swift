//
//  MultiYearStaticInputsTests.swift
//  RetireSmartIRATests
//
//  Tests for MultiYearStaticInputs, AccountSnapshot, and SpouseID value types.
//

import XCTest
@testable import RetireSmartIRA

final class MultiYearStaticInputsTests: XCTestCase {

    private func sampleInputs() -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 500_000, roth: 200_000, taxable: 100_000, hsa: 30_000),
            primaryCurrentAge: 65, spouseCurrentAge: 63,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 3000, spouseExpectedBenefitAtFRA: 2000,
            primaryBirthYear: 1961, spouseBirthYear: 1963,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 80_000
        )
    }

    func test_AccountSnapshot_total_sumsAllBuckets() {
        let snap = AccountSnapshot(traditional: 500_000, roth: 200_000, taxable: 100_000, hsa: 30_000)
        XCTAssertEqual(snap.total, 830_000, accuracy: 0.01)
    }

    func test_AccountSnapshot_zero_isAllZeros() {
        XCTAssertEqual(AccountSnapshot.zero.total, 0)
    }

    func test_withClaimAge_primary_changesPrimaryOnly() {
        let inputs = sampleInputs()
        let modified = inputs.withClaimAge(70, for: .primary)
        XCTAssertEqual(modified.primarySSClaimAge, 70)
        XCTAssertEqual(modified.spouseSSClaimAge, 67)  // unchanged
    }

    func test_withClaimAge_spouse_changesSpouseOnly() {
        let inputs = sampleInputs()
        let modified = inputs.withClaimAge(70, for: .spouse)
        XCTAssertEqual(modified.spouseSSClaimAge, 70)
        XCTAssertEqual(modified.primarySSClaimAge, 67)  // unchanged
    }

    func test_withClaimAge_preservesAllOtherFields() {
        let inputs = sampleInputs()
        let modified = inputs.withClaimAge(68, for: .primary)
        XCTAssertEqual(modified.startingBalances, inputs.startingBalances)
        XCTAssertEqual(modified.primaryCurrentAge, inputs.primaryCurrentAge)
        XCTAssertEqual(modified.filingStatus, inputs.filingStatus)
        XCTAssertEqual(modified.baselineAnnualExpenses, inputs.baselineAnnualExpenses)
    }

    func test_SpouseID_hasPrimaryAndSpouse() {
        XCTAssertEqual(Set(SpouseID.allCases), Set([.primary, .spouse]))
    }

    func test_carriedItemizables_defaultToZero() {
        let inputs = sampleInputs()
        XCTAssertEqual(inputs.carriedMortgageAndOtherItemized, 0)
        XCTAssertEqual(inputs.carriedPropertyAndOtherSALT, 0)
        XCTAssertEqual(inputs.carriedGrossMedicalExpenses, 0)
    }

    func test_withClaimAge_preservesCarriedItemizables() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 500_000, roth: 200_000, taxable: 100_000, hsa: 30_000),
            primaryCurrentAge: 65, spouseCurrentAge: 63,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 3000, spouseExpectedBenefitAtFRA: 2000,
            primaryBirthYear: 1961, spouseBirthYear: 1963,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 80_000,
            carriedMortgageAndOtherItemized: 12_000,
            carriedPropertyAndOtherSALT: 8_000,
            carriedGrossMedicalExpenses: 5_000
        )
        let modified = inputs.withClaimAge(70, for: .primary)
        XCTAssertEqual(modified.carriedMortgageAndOtherItemized, 12_000)
        XCTAssertEqual(modified.carriedPropertyAndOtherSALT, 8_000)
        XCTAssertEqual(modified.carriedGrossMedicalExpenses, 5_000)
    }
}
