//
//  MultiYearPerfTests.swift
//  RetireSmartIRATests
//
//  Performance validation suite. Confirms compute() falls within the perf budget
//  for representative personas. Runs once per build; failure surfaces a regression.
//
//  PERF BUDGET: 15s per persona.
//
//  The engine itself measures 0.7-4.6s isolated for the worst-case 30-year horizon
//  on M1 base. The 15s ceiling accommodates xcodebuild's parallel test execution —
//  when this suite runs alongside the other ~700 tests, CPU contention can roughly
//  double wall-clock times. 15s leaves ~50% headroom over the worst-case concurrent
//  measurement (~9s) while still catching genuine engine regressions (a 10× slowdown
//  to ~50s would still fail).
//
//  For accurate isolated perf measurements, run with:
//    xcodebuild test -only-testing:RetireSmartIRATests/MultiYearPerfTests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Performance — full compute() across personas")
struct MultiYearPerfTests {

    private var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    private func compute(_ inputs: MultiYearStaticInputs, _ assumptions: MultiYearAssumptions) -> (TimeInterval, MultiYearStrategyResult) {
        let start = Date()
        let result = MultiYearTaxStrategyEngine().compute(inputs: inputs, assumptions: assumptions)
        let elapsed = Date().timeIntervalSince(start)
        return (elapsed, result)
    }

    @Test("Perf: single filer, age 65, 30-year horizon, stress on")
    func persona1_singleFiler30Years() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 200_000, taxable: 100_000, hsa: 30_000),
            primaryCurrentAge: 65, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 3_000, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: baseYear - 65, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 60_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 95
        assumptions.stressTestEnabled = true

        let (elapsed, result) = compute(inputs, assumptions)
        #expect(result.recommendedPath.count == 31)
        #expect(elapsed < 15.0, "Single filer 30-year compute() took \(elapsed)s; budget <15s (see file header)")
    }

    @Test("Perf: MFJ couple, age 60/58, 35-year horizon, stress + ACA")
    func persona2_mfjCouple35Years() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_500_000, roth: 200_000, taxable: 200_000, hsa: 50_000),
            primaryCurrentAge: 60, spouseCurrentAge: 58,
            filingStatus: .marriedFilingJointly, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 3_500, spouseExpectedBenefitAtFRA: 2_000,
            primaryBirthYear: baseYear - 60, spouseBirthYear: baseYear - 58,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: true, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 80_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 95
        assumptions.stressTestEnabled = true

        let (elapsed, result) = compute(inputs, assumptions)
        #expect(result.recommendedPath.count == 36)
        #expect(elapsed < 15.0, "MFJ 35-year compute() took \(elapsed)s; budget <15s (see file header)")
    }

    @Test("Perf: post-RMD retiree, 15-year horizon, stress off")
    func persona3_postRMDRetiree() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_200_000, roth: 100_000, taxable: 50_000, hsa: 0),
            primaryCurrentAge: 75, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 2_800, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1951, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 60_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 90
        assumptions.stressTestEnabled = false

        let (elapsed, _) = compute(inputs, assumptions)
        #expect(elapsed < 15.0, "Short-horizon RMD scenario took \(elapsed)s; budget <15s (see file header)")
    }

    @Test("Perf: pre-retirement saver, 35-year horizon, stress on, MFJ with wages")
    func persona4_preRetirementSaverWithWages() {
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 600_000, roth: 100_000, taxable: 400_000, hsa: 30_000),
            primaryCurrentAge: 60, spouseCurrentAge: 58,
            filingStatus: .marriedFilingJointly, state: "TX",
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 3_200, spouseExpectedBenefitAtFRA: 2_400,
            primaryBirthYear: baseYear - 60, spouseBirthYear: baseYear - 58,
            primaryWageIncome: 80_000, spouseWageIncome: 50_000,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 100_000
        )
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAge = 95
        assumptions.stressTestEnabled = true

        let (elapsed, _) = compute(inputs, assumptions)
        #expect(elapsed < 15.0, "Pre-retirement 35-year compute() took \(elapsed)s; budget <15s (see file header)")
    }
}
