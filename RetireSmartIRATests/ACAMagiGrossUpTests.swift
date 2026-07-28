//
//  ACAMagiGrossUpTests.swift
//  RetireSmartIRATests
//
//  V2.3: acaMagi was computed pre-gross-up and never updated, unlike irmaaMagi which
//  was corrected by the earlier A3 fix. A gross-up withdrawal raises AGI, so the
//  REPORTED ACA MAGI must move with it.
//
//  Scope note: only the REPORTED value moves. Sizing the tax-funding cascade still
//  uses the pre-gross-up ACA/IRMAA/NIIT figures (`nonFedState`), exactly as the A3
//  fix left IRMAA. See ProjectionEngine's note above `finalIrmaaAcaMagi`.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ACA MAGI includes the gross-up", .serialized)
@MainActor
struct ACAMagiGrossUpTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    /// The only 2026 income in this scenario: no wages, no pension, no SS benefit (all
    /// zeroed below), and no taxable-account interest (starting taxable balance is 0). So
    /// pre-gross-up federal AGI -- and pre-gross-up ACA MAGI, since the addback (non-taxable
    /// SS + tax-exempt interest) is also 0 here -- is exactly this conversion amount.
    private let rothConversionAmount = 80_000.0

    /// Age-60 single filer, ACA enrolled, no taxable assets at all. The conversion tax
    /// therefore cannot be funded from taxable and must come from a grossed-up
    /// traditional withdrawal, which is exactly the condition under test.
    private func runPreMedicare() -> YearRecommendation {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 600_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 60, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1966, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: true, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        var a = MultiYearAssumptions.default
        a.horizonEndAge = 61
        a.investmentGrowthRate = 0
        a.cpiRate = 0
        a.baselineAnnualExpenses = 0
        a.stressTestEnabled = false
        a.rothTaxFundingMode = .fundedFromAccounts   // no taxable, so tax forces a gross-up
        return ProjectionEngine(configProvider: provider).project(
            inputs: inputs, assumptions: a,
            actionsPerYear: [2026: [.rothConversion(amount: rothConversionAmount)]]).first!
    }

    @Test("A gross-up fires in this scenario (guards the test's premise)")
    func grossUpFires() {
        #expect(runPreMedicare().taxFundingWithdrawal > 0)
    }

    @Test("The scenario is genuinely pre-Medicare and ACA-tracked")
    func acaMagiIsTracked() {
        #expect(runPreMedicare().acaMagi != nil)
    }

    @Test("ACA MAGI is at least the reported AGI, which already includes the gross-up")
    func acaMagiIncludesGrossUp() throws {
        let y = runPreMedicare()
        let aca = try #require(y.acaMagi)
        #expect(aca >= y.agi - 1.0,
                "acaMagi must not be computed from a pre-gross-up AGI")
    }

    @Test("ACA MAGI and IRMAA-style MAGI agree on the same AGI basis")
    func acaAgreesWithMagi() throws {
        let y = runPreMedicare()
        let aca = try #require(y.acaMagi)
        // `magi` was already corrected post-gross-up by the A3 fix; acaMagi shares its basis.
        #expect(abs(aca - y.magi) < 1.0)
    }

    @Test("ACA MAGI equals the pre-gross-up base plus the actual gross-up withdrawal")
    func acaMagiPinsGrossUpMagnitude() throws {
        let y = runPreMedicare()
        let aca = try #require(y.acaMagi)
        // Pins the dollar amount, not just the shape: this scenario's pre-gross-up ACA MAGI
        // is exactly `rothConversionAmount` (see its doc comment), so the reported acaMagi
        // must be that base plus whatever gross-up withdrawal the cascade actually took --
        // not merely >= some AGI (acaMagiIncludesGrossUp) or == some other field (acaAgreesWithMagi).
        #expect(abs(aca - (rothConversionAmount + y.taxFundingWithdrawal)) < 1.0,
                "ACA MAGI must equal the pre-gross-up base plus the actual gross-up withdrawal")
    }
}
