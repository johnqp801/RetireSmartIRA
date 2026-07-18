//
//  WidowStressTestTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("WidowStressTest — single-spouse mortality scenario", .serialized)
struct WidowStressTestTests {

    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    @Test("MFJ scenario: returns non-zero positive delta (widow pays MORE)")
    func mfjReturnsPositiveDelta() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_500_000, roth: 200_000, taxable: 100_000, hsa: 0),
            primaryCurrentAge: 65, spouseCurrentAge: 63,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 3_500, spouseExpectedBenefitAtFRA: 1_500,  // primary is higher earner
            primaryBirthYear: baseYear - 65, spouseBirthYear: baseYear - 63,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 70_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 90
        assumptions.stressTestEnabled = false

        let result = WidowStressTest().run(inputs: inputs, assumptions: assumptions)
        // Widow pays single-filer rates → typically more than MFJ
        #expect(result.delta > 0, "Widow lifetime tax should exceed MFJ baseline; got delta \(result.delta)")
    }

    @Test("Single filer scenario: returns zero delta")
    func singleFilerReturnsZeroDelta() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 500_000, roth: 0, taxable: 0, hsa: 0),
            primaryCurrentAge: 65, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 2_500, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: baseYear - 65, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 50_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 80
        let result = WidowStressTest().run(inputs: inputs, assumptions: assumptions)
        #expect(result.delta == 0)
    }

    @Test("scenario/baseline lifetime tax are NOMINAL in-horizon tax paid, not the objective cost")
    func lifetimeTaxIsNominalNotObjective() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_500_000, roth: 200_000, taxable: 100_000, hsa: 0),
            primaryCurrentAge: 67, spouseCurrentAge: 65,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 3_500, spouseExpectedBenefitAtFRA: 1_500,
            primaryBirthYear: baseYear - 67, spouseBirthYear: baseYear - 65,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 70_000)
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 90
        assumptions.stressTestEnabled = false
        let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))

        let result = WidowStressTest().run(inputs: inputs, assumptions: assumptions, configProvider: provider)

        // Reconstruct the exact scenarios the banner reports and pin their NOMINAL in-horizon tax.
        let engine = OptimizationEngine()
        let baselinePath = engine.optimize(inputs: inputs, assumptions: assumptions, configProvider: provider).recommendedPath
        let widowInputs = WidowStressTest().makeWidowVariant(inputs: inputs)
        let widowPath = engine.optimize(inputs: widowInputs, assumptions: assumptions, configProvider: provider).recommendedPath
        let expectedBaseline = OptimizationEngine.nominalLifetimeTax(baselinePath)
        let expectedScenario = OptimizationEngine.nominalLifetimeTax(widowPath)

        #expect(abs(result.baselineLifetimeTax - expectedBaseline) < 0.01,
                "baseline should be nominal in-horizon tax \(expectedBaseline), got \(result.baselineLifetimeTax)")
        #expect(abs(result.scenarioLifetimeTax - expectedScenario) < 0.01,
                "scenario should be nominal in-horizon tax \(expectedScenario), got \(result.scenarioLifetimeTax)")
    }

    @Test("Widow result baseline + scenario lifetime tax both >= 0")
    func nonNegativeLifetimeTaxes() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 800_000, roth: 100_000, taxable: 50_000, hsa: 0),
            primaryCurrentAge: 65, spouseCurrentAge: 63,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 3_000, spouseExpectedBenefitAtFRA: 1_500,
            primaryBirthYear: baseYear - 65, spouseBirthYear: baseYear - 63,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 65_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 85
        let result = WidowStressTest().run(inputs: inputs, assumptions: assumptions)
        #expect(result.baselineLifetimeTax >= 0)
        #expect(result.scenarioLifetimeTax >= 0)
    }
}
