//
//  ConversionReportingTests.swift
//  RetireSmartIRATests
//
//  B4 downstream audit (2026-07-13, Task 3): PlanSummary.totalConversions and
//  PlanPathMetrics.peakAnnualRothConversion (plus four other reporting sites, covered
//  by their own construct/unit test suites) summed the REQUESTED `.rothConversion`
//  amount from rec.actions. ConversionCapTests (B4 root cause 1) already caps the
//  LOCKED request at the household's total available traditional balance for the
//  year, but that household-level cap does not net out the CURRENT year's required
//  RMD, while YearRecommendation.executedRothConversion (B4 root cause 2) clamps each
//  spouse's convertible amount to balance-minus-reserved-RMD. So in an RMD year where
//  the optimizer locks a request at (or near) the full available balance, the locked
//  request can still exceed what actually converts by roughly that year's RMD.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("B4 downstream — PlanSummary/PlanPathMetrics report executed, not requested, conversions")
@MainActor
struct ConversionReportingTests {

    // MARK: - Fixture: MFJ/TX, $300K trad @ age 68, horizon to 92 (same profile as
    // ConversionCapTests.recommendedTaxMinNeverLocksPhantomConversionPartialDrainProfile,
    // duplicated here since that suite's factory methods are file-private). The greedy
    // recommendedTaxMin path fully drains the account in its final conversion year,
    // where that year's required RMD reserves part of the balance from conversion —
    // reproducing a genuine (if modest) requested-vs-executed gap driven by real
    // engine output, not a hand-fabricated number.

    private static func makeInputs() -> MultiYearStaticInputs {
        let baseYear = Calendar.current.component(.year, from: Date())
        return MultiYearStaticInputs(
            startingBalances: AccountSnapshot(
                traditional: 300_000,
                roth: 0,
                taxable: 300_000,
                hsa: 0
            ),
            baseYear: baseYear,
            primaryCurrentAge: 68,
            spouseCurrentAge: 68,
            filingStatus: .marriedFilingJointly,
            state: "TX",  // no state income tax to keep the test deterministic (federal-only)
            primarySSClaimAge: 67, spouseSSClaimAge: 67,
            primaryExpectedBenefitAtFRA: 2_500, spouseExpectedBenefitAtFRA: 2_500,
            primaryBirthYear: baseYear - 68,
            spouseBirthYear: baseYear - 68,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 2,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: 65,
            baselineAnnualExpenses: 60_000
        )
    }

    private static func makeAssumptions() -> MultiYearAssumptions {
        var a = MultiYearAssumptions.default
        a.horizonEndAge = 92
        a.stressTestEnabled = false
        return a
    }

    private static func requestedTotal(_ path: [YearRecommendation]) -> Double {
        path.reduce(0.0) { acc, rec in
            acc + rec.actions.reduce(0.0) { a, act in
                if case let .rothConversion(amount) = act { return a + amount }
                return a
            }
        }
    }

    @Test("PlanSummary.totalConversions sums executedRothConversion, not the inflated requested amount")
    func totalConversionsReflectsExecuted() {
        let inputs = ConversionReportingTests.makeInputs()
        let assumptions = ConversionReportingTests.makeAssumptions()
        let result = OptimizationEngine().optimize(
            inputs: inputs, assumptions: assumptions, approach: .recommendedTaxMin)
        let path = result.recommendedPath

        // Sanity: fixture must actually drain within the horizon, else the requested and
        // executed totals would trivially match and this test would be vacuous.
        let finalTraditional = path.last?.endOfYearBalances.traditional ?? -1
        #expect(finalTraditional <= 1, "fixture should drain the IRA near zero by the end of the horizon; got \(finalTraditional)")

        let executedTotal = path.reduce(0.0) { $0 + $1.executedRothConversion }
        let requested = ConversionReportingTests.requestedTotal(path)

        // Sanity: the fixture must actually reproduce the phantom-request gap (an RMD year
        // where the locked request exceeds what the RMD reservation left convertible), else
        // this test would pass vacuously regardless of which field PlanSummary reads.
        #expect(executedTotal < requested,
            "fixture should reproduce the phantom-request gap (executed < requested) for this assertion to be meaningful")

        let summary = PlanSummary(path: path)
        #expect(summary.totalConversions == executedTotal)
    }

    // MARK: - peakAnnualRothConversion

    // A hand-built path isolates the case that matters for this metric: the YEAR with the
    // largest REQUESTED conversion is exactly the year an RMD reservation clamps the
    // EXECUTED conversion below it (mirroring the real engine's final-drain-year behavior
    // above, but with the gap sized so it lands on the peak year specifically — in the
    // engine fixture above, the peak requested year happens to be an earlier, non-drained
    // year, which would make a peak assertion pass vacuously either way).
    private static func peakGapPath() -> [YearRecommendation] {
        func rec(_ year: Int, requested: Double, executed: Double) -> YearRecommendation {
            YearRecommendation(
                year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
                taxBreakdown: .zero,
                endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
                actions: requested > 0 ? [.rothConversion(amount: requested)] : [],
                executedRothConversion: executed)
        }
        return [
            rec(2026, requested: 40_000, executed: 40_000),
            rec(2027, requested: 90_000, executed: 60_000),   // peak requested year, RMD-clamped executed
            rec(2028, requested: 30_000, executed: 30_000),
        ]
    }

    @Test("PlanPathMetrics.peakAnnualRothConversion is the max executedRothConversion, not the max requested/locked amount")
    func peakConversionReflectsExecuted() {
        let path = ConversionReportingTests.peakGapPath()
        let peak = PlanPathMetrics.peakAnnualRothConversion(path)
        #expect(peak == 60_000)   // the executed peak, not the 90,000 requested peak
    }
}
