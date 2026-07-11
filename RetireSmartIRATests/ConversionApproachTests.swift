//
//  ConversionApproachTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 2a — selectable conversion approaches", .serialized)
@MainActor
struct ConversionApproachTests {

    // MARK: Test fixtures (mirrors ProjectionEngineTests, age 60 so the year is pre-Medicare)

    private static func makeInputs(
        currentAge: Int = 60,
        traditional: Double = 1_000_000,
        roth: Double = 0,
        taxable: Double = 0,
        hsa: Double = 0,
        wageIncome: Double = 0,
        pensionIncome: Double = 0,
        baselineExpenses: Double = 0,
        ssClaimAge: Int = 67,
        expectedBenefitAtFRA: Double = 3_000,  // monthly
        filingStatus: FilingStatus = .single,
        state: String = "CA",
        netInvestmentIncome: Double = 0
    ) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: traditional, roth: roth, taxable: taxable, hsa: hsa),
            primaryCurrentAge: currentAge,
            spouseCurrentAge: nil,
            filingStatus: filingStatus,
            state: state,
            primarySSClaimAge: ssClaimAge,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: expectedBenefitAtFRA,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - currentAge,
            spouseBirthYear: nil,
            primaryWageIncome: wageIncome,
            spouseWageIncome: 0,
            primaryPensionIncome: pensionIncome,
            spousePensionIncome: 0,
            primaryNetInvestmentIncome: netInvestmentIncome,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: baselineExpenses
        )
    }

    private static func makeAssumptions(
        cpi: Double = 0.025,
        growth: Double = 0.06,
        rule: WithdrawalOrderingRule = .taxEfficient
    ) -> MultiYearAssumptions {
        MultiYearAssumptions(
            horizonEndAge: 95,
            horizonEndAgeSpouse: nil,
            cpiRate: cpi,
            investmentGrowthRate: growth,
            withdrawalOrderingRule: rule,
            stressTestEnabled: false,
            perYearExpenseOverrides: [:],
            currentTaxableBalance: 0,
            currentHSABalance: 0
        )
    }

    private static var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    @Test("YearRecommendation exposes taxablePreferential and an always-populated magi")
    func exposesOrdinaryAndMagi() {
        // A conversion-free projection: preferential = 0 when no preferential income; magi is non-nil.
        // Pension income ensures year 1 has nonzero AGI/MAGI even though the household is
        // pre-Medicare (age 60) and hasn't claimed SS yet (claim age 67) or hit RMD age.
        let inputs = ConversionApproachTests.makeInputs(traditional: 1_000_000, pensionIncome: 40_000)
        let years = ProjectionEngine().project(inputs: inputs, assumptions: ConversionApproachTests.makeAssumptions(),
                                               actionsPerYear: [ConversionApproachTests.baseYear: []])
        #expect(years[0].taxablePreferential >= 0)
        #expect(years[0].taxablePreferential <= years[0].taxableIncome)
        #expect(years[0].magi > 0)   // populated even pre-Medicare (unlike irmaaMagi which may be nil)
        #expect(years[0].irmaaMagi == nil)  // age 60 primary, no spouse: pre-IRMAA-window
    }
}
