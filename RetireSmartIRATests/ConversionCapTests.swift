//
//  ConversionCapTests.swift
//  RetireSmartIRATests
//
//  B4 root cause 1 (2026-07-13 fix backlog): both optimizer paths could LOCK a
//  Roth conversion request larger than the traditional balance actually available
//  in that projected year. The ProjectionEngine clamps the EXECUTED conversion to
//  what's really convertible, but the locked/requested amount (surfaced in
//  rec.actions, and consumed by PlanSummary/ladder rows/CPA export/etc.) kept the
//  phantom, inflated figure once the IRA drained (deterministic ladder: constant
//  $500k `upperBoundCap` off the STARTING balance; greedy `recommendedTaxMin`:
//  candidate sweep never checked availability at all).
//
//  This suite asserts the invariant directly: for every YearRecommendation on a
//  draining MFJ/TX profile, the summed `.rothConversion` LOCKED for that year must
//  never exceed the traditional balance actually available at the start of that
//  year (prior year's end-of-year traditional + inheritedTraditional, +$1 slack
//  for floating-point noise).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("B4 root cause 1 — per-year conversion cap (no phantom locked requests)")
@MainActor
struct ConversionCapTests {

    // MARK: - Fixture: MFJ/TX, $400K trad, $85 horizon — small enough trad + long
    // enough horizon that fillToBracket(0.22) / recommendedTaxMin fully drain the
    // IRA well before the horizon ends, reproducing the drained-year phantom lock.

    private static func makeInputs() -> MultiYearStaticInputs {
        let baseYear = Calendar.current.component(.year, from: Date())
        return MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                traditional: 400_000,
                roth: 0,
                taxable: 300_000,   // brokerage, funds expenses/taxes once trad is gone
                hsa: 0
            ),
            baseYear: baseYear,
            primaryCurrentAge: 60,
            spouseCurrentAge: 60,
            filingStatus: .marriedFilingJointly,
            state: "TX",  // no state income tax to keep the test deterministic (federal-only)
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 2_500, spouseExpectedBenefitAtFRA: 2_500,
            primaryBirthYear: baseYear - 60,
            spouseBirthYear: baseYear - 60,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 60_000
        )
    }

    private static func makeAssumptions() -> MultiYearAssumptions {
        var a = MultiYearAssumptions.default
        a.horizonEndAge = 85   // 25-year horizon; plenty of time to drain a $400K IRA
        a.stressTestEnabled = false
        return a
    }

    /// Shared invariant check: walk the path, tracking the start-of-year traditional
    /// balance (prior year's endOfYearBalances.traditional + inheritedTraditional,
    /// seeded from the starting balances), and assert the summed locked
    /// `.rothConversion` never exceeds it (+$1 tolerance).
    private static func assertNoPhantomConversions(
        _ path: [YearRecommendation],
        startingTraditional: Double,
        label: String
    ) {
        var availableTraditional = startingTraditional
        for rec in path {
            let lockedConversion = rec.actions.compactMap { action -> Double? in
                if case .rothConversion(let amount) = action { return amount }
                return nil
            }.reduce(0, +)

            #expect(lockedConversion <= availableTraditional + 1,
                Comment(rawValue: "\(label) year \(rec.year): locked conversion \(lockedConversion) exceeds " +
                "start-of-year available traditional \(availableTraditional) — phantom request"))

            availableTraditional = rec.endOfYearBalances.traditional + rec.endOfYearBalances.inheritedTraditional
        }
    }

    @Test("fillToBracket (deterministic ladder) never locks a conversion above the year's available traditional")
    func fillToBracketNeverLocksPhantomConversion() {
        let inputs = ConversionCapTests.makeInputs()
        let assumptions = ConversionCapTests.makeAssumptions()

        let result = OptimizationEngine().optimize(
            inputs: inputs, assumptions: assumptions, approach: .fillToBracket(rate: 0.22))

        // Sanity: the profile must actually drain within the horizon for this test to be
        // meaningful (otherwise the invariant would trivially hold even with the bug).
        let finalTraditional = result.recommendedPath.last?.endOfYearBalances.traditional ?? -1
        #expect(finalTraditional <= 1, "fixture should fully drain the IRA within the horizon; got \(finalTraditional)")

        ConversionCapTests.assertNoPhantomConversions(
            result.recommendedPath,
            startingTraditional: inputs.startingBalances.traditional,
            label: "fillToBracket(0.22)")
    }

    @Test("recommendedTaxMin (greedy path) never locks a conversion above the year's available traditional")
    func recommendedTaxMinNeverLocksPhantomConversion() {
        let inputs = ConversionCapTests.makeInputs()
        let assumptions = ConversionCapTests.makeAssumptions()

        let result = OptimizationEngine().optimize(
            inputs: inputs, assumptions: assumptions, approach: .recommendedTaxMin)

        let finalTraditional = result.recommendedPath.last?.endOfYearBalances.traditional ?? -1
        #expect(finalTraditional <= 1, "fixture should fully drain the IRA within the horizon; got \(finalTraditional)")

        ConversionCapTests.assertNoPhantomConversions(
            result.recommendedPath,
            startingTraditional: inputs.startingBalances.traditional,
            label: "recommendedTaxMin")
    }
}
