//
//  ExecutedConversionTests.swift
//  RetireSmartIRATests
//
//  B4 root cause 2 (2026-07-13 fix backlog): YearRecommendation.actions carries the
//  REQUESTED `.rothConversion` amount, but ProjectionEngine clamps the actual conversion
//  to the traditional balance actually available that year (fromPrimary/fromSpouse mins
//  against primaryConvertible/spouseConvertible). Once the IRA is drained, the requested
//  and executed amounts diverge — consumers reading `.actions` see a phantom conversion
//  that never happened.
//
//  This suite adds `YearRecommendation.executedRothConversion`, the CLAMPED actual
//  trad->Roth dollars moved that year, as the single source of truth for
//  conversion-amount reporting (Task 3 routes UI/export consumers to it).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("B4 root cause 2 — executedRothConversion is the clamped actual, not the request")
@MainActor
struct ExecutedConversionTests {

    // MARK: - Fixture: single filer, TX, $50K trad — small enough that a single
    // full-balance conversion in year 0 fully drains the IRA, so year 1's oversized
    // request has nothing left to convert.

    private static func makeInputs() -> MultiYearStaticInputs {
        let baseYear = Calendar.current.component(.year, from: Date())
        return MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 50_000, roth: 0, taxable: 100_000, hsa: 0),
            baseYear: baseYear,
            primaryCurrentAge: 60,
            spouseCurrentAge: nil,
            filingStatus: .single,
            state: "TX",  // federal-only, deterministic
            primarySSClaimAge: 67, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 2_000, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: baseYear - 60,
            spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 30_000
        )
    }

    private static func makeAssumptions() -> MultiYearAssumptions {
        var a = MultiYearAssumptions.default
        a.horizonEndAge = 65
        a.stressTestEnabled = false
        return a
    }

    @Test("executedRothConversion == requested in a non-drained year, == 0 once the IRA is drained, and never exceeds start-of-year traditional")
    func executedConversionClampsToAvailableBalance() {
        let inputs = ExecutedConversionTests.makeInputs()
        let assumptions = ExecutedConversionTests.makeAssumptions()
        let baseYear = Calendar.current.component(.year, from: Date())

        // Year 0: request exactly the full starting balance — fully convertible,
        // draining the IRA to (approximately) zero.
        // Year 1: request an amount far larger than anything left — the IRA is already
        // drained, so nothing can actually move.
        let engine = ProjectionEngine()
        let years = engine.project(
            inputs: inputs,
            assumptions: assumptions,
            actionsPerYear: [
                baseYear: [.rothConversion(amount: 50_000)],
                baseYear + 1: [.rothConversion(amount: 1_000_000)],
            ]
        )

        #expect(years.count == 2)

        let year0 = years[0]
        let requested0 = year0.actions.compactMap { action -> Double? in
            if case .rothConversion(let amount) = action { return amount }
            return nil
        }.reduce(0, +)
        #expect(requested0 == 50_000)
        #expect(abs(year0.executedRothConversion - requested0) < 0.01,
            "non-drained year: executed should equal the requested amount (got \(year0.executedRothConversion), requested \(requested0))")
        #expect(year0.executedRothConversion <= 50_000 + 0.01, "executed must never exceed start-of-year traditional")

        let year1 = years[1]
        #expect(abs(year1.endOfYearBalances.traditional) < 1, "sanity: IRA should be drained after year 0's full conversion")
        #expect(year1.executedRothConversion == 0,
            "drained year: nothing left to convert, so executed must be 0 despite a $1,000,000 request")
    }
}
