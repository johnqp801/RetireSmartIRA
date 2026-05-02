//
//  OptimizationEngineTests.swift
//  RetireSmartIRATests
//
//  TDD test suite for OptimizationEngine (Task 1.9 — Scope C+D greedy with lookahead).
//  Tests cover: correctness of path length, lifetime-tax improvement vs baseline,
//  constraint-hit rationale population, edge cases (empty horizon, zero balances),
//  heuristic correctness (trad-heavy scenario expects conversions), and perf budget.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("OptimizationEngine — Scope C+D greedy with lookahead")
struct OptimizationEngineTests {

    private func makeStandardInputs(currentAge: Int = 65) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                traditional: 1_000_000,
                roth: 200_000,
                taxable: 100_000,
                hsa: 30_000
            ),
            primaryCurrentAge: currentAge,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "CA",
            primarySSClaimAge: 67,
            spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 3_000,
            spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - currentAge,
            spouseBirthYear: nil,
            primaryWageIncome: 0,
            spouseWageIncome: 0,
            primaryPensionIncome: 0,
            spousePensionIncome: 0,
            acaEnrolled: false,
            acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65,
            spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 60_000
        )
    }

    private func makeAssumptions() -> MultiYearAssumptions {
        var a = MultiYearAssumptions.default
        a.horizonEndAge = 80    // shorter horizon for faster tests
        a.stressTestEnabled = false
        return a
    }

    private func lifetimeTax(of path: [YearRecommendation]) -> Double {
        path.reduce(0.0) { $0 + $1.taxBreakdown.total }
    }

    // MARK: - Smoke + correctness

    @Test("Returns path of correct length for the horizon")
    func returnsPathForHorizon() {
        let inputs = makeStandardInputs(currentAge: 65)
        var assumptions = makeAssumptions()
        assumptions.horizonEndAge = 75   // 11-year horizon
        let engine = OptimizationEngine()
        let result = engine.optimize(inputs: inputs, assumptions: assumptions)
        // 11 years inclusive of start and end
        #expect(result.recommendedPath.count == 11)
    }

    @Test("Beats or ties no-conversion baseline on lifetime tax")
    func beatsBaselineNoConversionStrategy() {
        let inputs = makeStandardInputs()
        let assumptions = makeAssumptions()

        let optResult = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)
        let optTax = lifetimeTax(of: optResult.recommendedPath)

        // Compute baseline: zero conversions every year
        let baseYear = Calendar.current.component(.year, from: Date())
        let endYear = baseYear + (assumptions.horizonEndAge - inputs.primaryCurrentAge)
        let baselineActions = Dictionary(uniqueKeysWithValues: (baseYear...endYear).map { ($0, [LeverAction]()) })
        let baselinePath = ProjectionEngine().project(
            inputs: inputs, assumptions: assumptions, actionsPerYear: baselineActions
        )
        let baselineTax = lifetimeTax(of: baselinePath)

        #expect(optTax <= baselineTax, "Optimizer (\(optTax)) should not exceed baseline (\(baselineTax))")
    }

    @Test("All accepted constraint hits have non-empty rationale")
    func acceptedHitsHaveRationales() {
        let inputs = makeStandardInputs(currentAge: 60)
        let assumptions = makeAssumptions()
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)
        for hit in result.tradeOffsAccepted {
            #expect(!hit.acceptanceRationale.isEmpty,
                "Hit \(hit) has empty acceptanceRationale — controller fills these in")
        }
    }

    @Test("Output path matches engine's locked-in actions")
    func pathMatchesLockedActions() {
        let inputs = makeStandardInputs()
        let assumptions = makeAssumptions()
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)
        // Each year's YearRecommendation.actions should be self-consistent
        for year in result.recommendedPath {
            for action in year.actions {
                if case .rothConversion(let amount) = action {
                    #expect(amount > 0, "rothConversion(0) should not appear; emit empty actions instead")
                }
            }
        }
    }

    // MARK: - Edge cases

    @Test("Already past mortality: returns empty path")
    func emptyHorizon() {
        var assumptions = makeAssumptions()
        assumptions.horizonEndAge = 60   // before currentAge=65
        let inputs = makeStandardInputs(currentAge: 65)
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)
        #expect(result.recommendedPath.isEmpty)
    }

    @Test("Single-year horizon: chooses one year of actions")
    func singleYearHorizon() {
        var assumptions = makeAssumptions()
        assumptions.horizonEndAge = 65
        let inputs = makeStandardInputs(currentAge: 65)   // 1-year horizon
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)
        #expect(result.recommendedPath.count == 1)
    }

    @Test("Zero-balance scenario: returns all-empty path with zero tax")
    func zeroBalanceScenario() {
        let inputs = MultiYearStaticInputs(
            startingBalances: .zero,
            primaryCurrentAge: 65, spouseCurrentAge: nil,
            filingStatus: .single, state: "CA",
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 0, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 65,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
        var assumptions = makeAssumptions()
        assumptions.horizonEndAge = 70
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)
        #expect(result.recommendedPath.count == 6)
        // No income → no tax
        let lifetime = lifetimeTax(of: result.recommendedPath)
        #expect(lifetime < 100, "Zero-balance scenario should produce ~zero lifetime tax")
    }

    // MARK: - Heuristic correctness

    @Test("Tax-deferred-heavy scenario: optimizer recommends meaningful conversions when RMD pressure exists")
    func recommendsConversionsForLargeTraditional() {
        // v2.0 Phase 1 (RMD modeling): person age 60 with $2M traditional, no Roth, low expenses.
        // With SECURE 2.0 (birthYear = currentYear - 60 ≥ 1960 → rmdAge = 75), there is a
        // 15-year window of low AGI before RMDs hit at 75. The optimizer should fill brackets
        // with Roth conversions to reduce future RMD-driven AGI.
        let inputs = MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 2_000_000, roth: 0, taxable: 100_000, hsa: 0),
            primaryCurrentAge: 60, spouseCurrentAge: nil,
            filingStatus: .single, state: "TX",  // no state income tax
            primarySSClaimAge: 70, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 3_500, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: Calendar.current.component(.year, from: Date()) - 60,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 50_000
        )
        var assumptions = makeAssumptions()
        assumptions.horizonEndAge = 90  // long enough for RMDs to bite meaningfully
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)

        let totalConversions = result.recommendedPath.flatMap { $0.actions }
            .compactMap { if case .rothConversion(let a) = $0 { return a } else { return nil } }
            .reduce(0.0, +)

        // With RMD pressure, optimizer should recommend SOMETHING — at least $20K total
        // across the 30-year horizon. Soft floor; tighten if real-world testing supports.
        #expect(totalConversions > 20_000,
            "RMD pressure should drive optimizer to recommend meaningful conversions; got \(totalConversions)")

        // Optimizer must never make things worse than baseline
        let baseYear = Calendar.current.component(.year, from: Date())
        let endYear = baseYear + (assumptions.horizonEndAge - inputs.primaryCurrentAge)
        let baselineActions = Dictionary(uniqueKeysWithValues: (baseYear...endYear).map { ($0, [LeverAction]()) })
        let baselinePath = ProjectionEngine().project(inputs: inputs, assumptions: assumptions, actionsPerYear: baselineActions)
        let baselineTax = lifetimeTax(of: baselinePath)
        let optimizedTax = lifetimeTax(of: result.recommendedPath)
        #expect(optimizedTax <= baselineTax, "Optimizer must not exceed baseline tax for any input")

        // Any conversions that appear must be positive (no rothConversion(0) noise)
        for year in result.recommendedPath {
            for action in year.actions {
                if case .rothConversion(let amount) = action {
                    #expect(amount > 0, "Optimizer must not emit rothConversion(0)")
                }
            }
        }
    }

    // MARK: - Performance budget

    @Test("Perf: 30-year horizon completes in under 5 seconds")
    func perf30YearHorizon() {
        let inputs = makeStandardInputs(currentAge: 65)
        var assumptions = makeAssumptions()
        assumptions.horizonEndAge = 95   // full 30-year horizon

        let start = Date()
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: assumptions)
        let elapsed = Date().timeIntervalSince(start)

        #expect(result.recommendedPath.count == 31)
        #expect(elapsed < 5.0, "30-year optimize() took \(elapsed)s; target is <5s on M1 base")
    }
}
