//
//  OptimizerPerformanceRegressionTests.swift
//  RetireSmartIRATests
//
//  Spec success criterion #5: 30-year horizon optimization should run
//  in <3 seconds isolated on M1 base hardware (1.5-2s typical observed).
//  This test uses a 5s budget to accommodate parallel test-suite
//  contention while still catching genuine algorithmic regressions
//  (>3x slowdown). Suite is .serialized so the perf measurement is
//  not corrupted by other compute-heavy tests starting concurrently.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Optimizer performance regression", .serialized)
struct OptimizerPerformanceRegressionTests {

    @Test("30-year horizon optimizer completes within 5s")
    func thirtyYearHorizonUnderBudget() {
        // Full-feature scenario: couple age 60, traditional/Roth/taxable/HSA
        // balances, SS at 67, Medicare at 65, ACA pre-65.
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                traditional: 1_500_000,
                roth: 300_000,
                taxable: 500_000,
                hsa: 100_000
            ),
            primaryCurrentAge: 60,
            spouseCurrentAge: 60,
            filingStatus: .marriedFilingJointly,
            state: "CA",  // CA has state income tax (more compute)
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 2_800, spouseExpectedBenefitAtFRA: 2_200,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 60,
            spouseBirthYear: Calendar.current.component(.year, from: Date()) - 60,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: true, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 80_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 90  // 30-year horizon
        assumptions.stressTestEnabled = false  // exclude stress-test compute (covered by MultiYearPerfTests)

        let start = Date()
        _ = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 5.0,
            "30-year horizon optimization took \(elapsed)s; budget <5s (isolated baseline ~1.5-2s)")
    }
}
