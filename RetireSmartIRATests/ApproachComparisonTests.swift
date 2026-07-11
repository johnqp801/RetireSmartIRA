//
//  ApproachComparisonTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 2b — three-way approach comparison", .serialized)
@MainActor
struct ApproachComparisonTests {

    @Test("YearRecommendation surfaces taxable Social Security, and it rises with more ordinary income")
    func surfacesTaxableSocialSecurity() {
        // A household collecting SS: a projection with a large Roth conversion pushes provisional
        // income up, so more of the SS becomes taxable than the no-conversion baseline.
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let base = inputs.baseYear
        let noConv = ProjectionEngine().project(inputs: inputs, assumptions: asmp,
                                                actionsPerYear: [base: []])
        let withConv = ProjectionEngine().project(inputs: inputs, assumptions: asmp,
                                                  actionsPerYear: [base: [.rothConversion(amount: 80_000)]])
        #expect(noConv[0].taxableSocialSecurity >= 0)
        #expect(withConv[0].taxableSocialSecurity >= noConv[0].taxableSocialSecurity)
    }
}

extension ApproachComparisonTests {
    static func makeAssumptions(
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

    static func makeInputsWithSocialSecurity(
        currentAge: Int = 67,
        traditional: Double = 900_000,
        roth: Double = 0,
        taxable: Double = 0,
        hsa: Double = 0,
        wageIncome: Double = 0,
        pensionIncome: Double = 0,
        baselineExpenses: Double = 0,
        ssClaimAge: Int = 67,
        expectedBenefitAtFRA: Double = 3_333,  // monthly (~$40k/yr)
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
}

extension ApproachComparisonTests {
    @Test("PlanPathMetrics matches PlanComparison's own derivations on the same path")
    func planPathMetricsAgreeWithPlanComparison() {
        let inputs = ApproachComparisonTests.makeInputsWithSocialSecurity()
        let asmp = ApproachComparisonTests.makeAssumptions()
        let base = inputs.baseYear
        let path = ProjectionEngine().project(inputs: inputs, assumptions: asmp, actionsPerYear: [base: []])

        let pc = PlanComparison(plan: path, doingNothing: path,
                                heirSalary: inputs.heirSalary,
                                heirFilingStatus: inputs.heirFilingStatus,
                                heirDrawdownYears: inputs.heirDrawdownYears)

        #expect(PlanPathMetrics.lifetimeTax(path) == pc.lifetimeTax.plan)
        #expect(PlanPathMetrics.endingTraditional(path) == pc.endingTraditional.plan)
        #expect(PlanPathMetrics.endingRoth(path) == pc.endingRoth.plan)
        #expect(PlanPathMetrics.endingTaxable(path) == pc.endingTaxable.plan)
        #expect(PlanPathMetrics.peakForcedRMD(path) == pc.peakForcedRMD.plan)
        #expect(PlanPathMetrics.heirsKeep(path, heirSalary: inputs.heirSalary,
                                          heirFilingStatus: inputs.heirFilingStatus,
                                          heirDrawdownYears: inputs.heirDrawdownYears) == pc.heirsKeep.plan)
    }
}
