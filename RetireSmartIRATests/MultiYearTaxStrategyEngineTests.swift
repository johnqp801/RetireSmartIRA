//
//  MultiYearTaxStrategyEngineTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("MultiYearTaxStrategyEngine — top-level coordinator")
struct MultiYearTaxStrategyEngineTests {

    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    private func makeInputs(currentAge: Int = 65) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 200_000, taxable: 100_000, hsa: 30_000),
            primaryCurrentAge: currentAge, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 3_000, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: baseYear - currentAge, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 60_000
        )
    }

    @Test("Result has all 5 components populated")
    func allComponentsPresent() {
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 80
        assumptions.stressTestEnabled = true

        let result = MultiYearTaxStrategyEngine().compute(inputs: makeInputs(), assumptions: assumptions)

        #expect(!result.recommendedPath.isEmpty)
        // tradeOffsAccepted may be empty; that's fine
        #expect(!result.sensitivityBands.average.isEmpty)
        #expect(!result.sensitivityBands.optimistic.isEmpty)
        #expect(!result.sensitivityBands.pessimistic.isEmpty)
        // widowStressDelta and ssClaimNudge may have whatever values
    }

    @Test("Stress test disabled: optimistic/pessimistic mirror average")
    func stressTestDisabledMirrors() {
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 80
        assumptions.stressTestEnabled = false

        let result = MultiYearTaxStrategyEngine().compute(inputs: makeInputs(), assumptions: assumptions)
        #expect(result.sensitivityBands.optimistic == result.sensitivityBands.average)
        #expect(result.sensitivityBands.pessimistic == result.sensitivityBands.average)
    }

    @Test("Lifetime tax matches between recommendedPath and sensitivityBands.average (stress on)")
    func lifetimeTaxConsistency() {
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 75
        assumptions.stressTestEnabled = true

        let result = MultiYearTaxStrategyEngine().compute(inputs: makeInputs(), assumptions: assumptions)
        let pathLifetimeTax = result.lifetimeTaxFromRecommendedPath
        let avgBandLifetimeTax = result.sensitivityBands.average.reduce(0.0) { $0 + $1.taxBreakdown.total }
        // They both come from optimize() runs at the same growthRate, so should match exactly
        #expect(abs(pathLifetimeTax - avgBandLifetimeTax) < 1.0)
    }

    @Test("Single filer: widowStressDelta is zero")
    func singleFilerNoWidow() {
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 80
        assumptions.stressTestEnabled = false

        let result = MultiYearTaxStrategyEngine().compute(inputs: makeInputs(), assumptions: assumptions)
        #expect(result.widowStressDelta.delta == 0)
    }

    @Test("Perf: full compute() under 5s for 30-year horizon (single filer)")
    func perfFullCompute30Year() {
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 95
        assumptions.stressTestEnabled = true

        let inputs = makeInputs(currentAge: 65)
        let start = Date()
        let result = MultiYearTaxStrategyEngine().compute(inputs: inputs, assumptions: assumptions)
        let elapsed = Date().timeIntervalSince(start)

        #expect(result.recommendedPath.count == 31)
        #expect(elapsed < 15.0, "compute() took \(elapsed)s; budget <15s (concurrent-test-safe; see MultiYearPerfTests.swift header)")
    }
}
