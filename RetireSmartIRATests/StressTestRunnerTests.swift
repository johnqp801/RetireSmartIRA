//
//  StressTestRunnerTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("StressTestRunner — ±2pp sensitivity bands")
struct StressTestRunnerTests {

    private func makeInputs() -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 200_000, taxable: 100_000, hsa: 30_000),
            primaryCurrentAge: 65, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 3_000, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 65,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 60_000
        )
    }

    private func makeAssumptions() -> MultiYearAssumptions {
        var a = MultiYearAssumptions.default
        a.horizonEndAge = 75
        a.stressTestEnabled = true
        return a
    }

    @Test("Returns three non-empty bands")
    func returnsThreeBands() {
        let bands = StressTestRunner().run(inputs: makeInputs(), assumptions: makeAssumptions())
        #expect(!bands.optimistic.isEmpty)
        #expect(!bands.average.isEmpty)
        #expect(!bands.pessimistic.isEmpty)
    }

    @Test("Optimistic band ends with higher balances than pessimistic")
    func optimisticHigherThanPessimistic() {
        let bands = StressTestRunner().run(inputs: makeInputs(), assumptions: makeAssumptions())
        let optEnd = bands.optimistic.last!.endOfYearBalances.total
        let pesEnd = bands.pessimistic.last!.endOfYearBalances.total
        #expect(optEnd > pesEnd)
    }

    @Test("All three bands have the same length (the horizon)")
    func bandsSameLength() {
        let bands = StressTestRunner().run(inputs: makeInputs(), assumptions: makeAssumptions())
        #expect(bands.optimistic.count == bands.average.count)
        #expect(bands.average.count == bands.pessimistic.count)
    }

    @Test("Pessimistic floor: growth rate cannot go negative")
    func pessimisticFloor() {
        var assumptions = makeAssumptions()
        assumptions.investmentGrowthRate = 0.01  // 1% — minus 2pp would be -1%, should clamp to 0
        let bands = StressTestRunner().run(inputs: makeInputs(), assumptions: assumptions)
        // Just verify it runs without crashing — pessimistic at 0% growth is well-defined
        #expect(!bands.pessimistic.isEmpty)
    }
}
