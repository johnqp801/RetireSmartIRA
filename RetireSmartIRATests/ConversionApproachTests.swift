//
//  ConversionApproachTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Phase 2a — selectable conversion approaches", .serialized)
@MainActor
struct ConversionApproachTests {

    // MARK: Test fixtures (mirrors ProjectionEngineTests, age 60 so the year is pre-Medicare)

    private static func makeInputs(
        currentAge: Int = 60,
        traditional: Double = 1_000_000,
        roth: Double = 0,
        taxable: Double = 0,
        hsa: Double = 0,
        wageIncome: Double = 0,
        pensionIncome: Double = 0,
        baselineExpenses: Double = 0,
        ssClaimAge: Int = 67,
        expectedBenefitAtFRA: Double = 3_000,  // monthly
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

    private static func makeAssumptions(
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

    private static var baseYear: Int { Calendar.current.component(.year, from: Date()) }

    @Test("YearRecommendation exposes taxablePreferential and an always-populated magi")
    func exposesOrdinaryAndMagi() {
        // A conversion-free projection: preferential = 0 when no preferential income; magi is non-nil.
        // Pension income ensures year 1 has nonzero AGI/MAGI even though the household is
        // pre-Medicare (age 60) and hasn't claimed SS yet (claim age 67) or hit RMD age.
        let inputs = ConversionApproachTests.makeInputs(traditional: 1_000_000, pensionIncome: 40_000)
        let years = ProjectionEngine().project(inputs: inputs, assumptions: ConversionApproachTests.makeAssumptions(),
                                               actionsPerYear: [ConversionApproachTests.baseYear: []])
        #expect(years[0].taxablePreferential >= 0)
        #expect(years[0].taxablePreferential <= years[0].taxableIncome)
        #expect(years[0].magi > 0)   // populated even pre-Medicare (unlike irmaaMagi which may be nil)
        #expect(years[0].irmaaMagi == nil)  // age 60 primary, no spouse: pre-IRMAA-window
    }

    // MARK: - ConversionLadder bisection (pure root-finder, no engine coupling)

    @Test("bisection finds the largest X with a monotone f(X) at or below target")
    func bisectionMonotone() {
        // f(x) = x (identity). target 100_000 -> ~100_000.
        let x = ConversionLadder.largestConversionBelow(target: 100_000, upperBound: 500_000, tolerance: 1) { $0 }
        #expect(abs(x - 100_000) < 2)
    }

    @Test("bisection returns 0 when f(0) already exceeds target")
    func bisectionAlreadyOver() {
        let x = ConversionLadder.largestConversionBelow(target: 50_000, upperBound: 500_000) { $0 + 60_000 }
        #expect(x == 0)
    }

    @Test("bisection returns upperBound when f never reaches target")
    func bisectionNeverReaches() {
        let x = ConversionLadder.largestConversionBelow(target: 1_000_000, upperBound: 200_000) { $0 }
        #expect(x == 200_000)
    }

    @Test("bisection handles a kinked-but-monotone f (flat then rising)")
    func bisectionKinked() {
        // f flat at 40k for x<=50k (e.g. SS torpedo saturates), then rises.
        let f: (Double) -> Double = { $0 <= 50_000 ? 40_000 : 40_000 + ($0 - 50_000) }
        let x = ConversionLadder.largestConversionBelow(target: 60_000, upperBound: 500_000, tolerance: 1, evaluate: f)
        #expect(abs(x - 70_000) < 2) // 40k + (x-50k) = 60k -> x = 70k
    }

    // MARK: - End-to-end: optimize(approach:) deterministic ladders

    /// Top of the ordinary bracket at `rate` = the NEXT bracket's threshold, read the same way
    /// the engine reads it (configProvider.config(forYear:).toTaxBrackets()).
    private static func bracketTop(rate: Double, filingStatus: FilingStatus, year: Int) -> Double {
        let cfg = TaxYearConfigProvider.current.config(forYear: year)
        let brackets = cfg.toTaxBrackets()
        let arr = filingStatus == .single ? brackets.federalSingle : brackets.federalMarried
        guard let i = arr.firstIndex(where: { abs($0.rate - rate) < 1e-9 }), i + 1 < arr.count else {
            return .greatestFiniteMagnitude
        }
        return arr[i + 1].threshold
    }

    /// IRMAA tier threshold, read the same way the engine reads it (configProvider.config(forYear:).toIRMAATiers()).
    private static func irmaaTierThreshold(tier: Int, filingStatus: FilingStatus, year: Int) -> Double {
        let cfg = TaxYearConfigProvider.current.config(forYear: year)
        let tiers = cfg.toIRMAATiers()
        guard tier >= 0 && tier < tiers.count else { return .greatestFiniteMagnitude }
        return filingStatus == .single ? tiers[tier].singleThreshold : tiers[tier].mfjThreshold
    }

    @Test("fillToBracket lands ordinary taxable income at or below the chosen bracket top")
    func fillToBracketLandsAtTop() {
        let inputs = ConversionApproachTests.makeInputs(traditional: 3_000_000, filingStatus: .single) // large trad so the bracket binds
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: ConversionApproachTests.makeAssumptions(),
                                                   approach: .fillToBracket(rate: 0.22))
        let y0 = result.recommendedPath[0]
        let top22 = ConversionApproachTests.bracketTop(rate: 0.22, filingStatus: .single, year: y0.year)
        let ordinary = y0.taxableIncome - y0.taxablePreferential
        #expect(ordinary <= top22 + 1)          // did not overshoot the 22% top
        #expect(ordinary >= top22 - 5_000)      // filled close to it (converted meaningfully)
    }

    @Test("limitToIRMAA keeps MAGI at or below the tier ceiling every year")
    func limitToIRMAAKeepsMagiUnderTier() {
        let inputs = ConversionApproachTests.makeInputs(traditional: 3_000_000, filingStatus: .single)
        let buffer = 2_000.0
        let result = OptimizationEngine().optimize(inputs: inputs, assumptions: ConversionApproachTests.makeAssumptions(),
                                                   approach: .limitToIRMAA(tier: 1, buffer: buffer))
        let y0 = result.recommendedPath[0]
        let tier1 = ConversionApproachTests.irmaaTierThreshold(tier: 1, filingStatus: .single, year: y0.year)
        #expect(y0.magi <= tier1 - buffer + 1)  // stayed under the tier-1 ceiling minus buffer
    }

    @Test("recommendedTaxMin is unchanged by adding the approach parameter")
    func recommendedTaxMinUnchanged() {
        let inputs = ConversionApproachTests.makeInputs(traditional: 1_000_000)
        let a = OptimizationEngine().optimize(inputs: inputs, assumptions: ConversionApproachTests.makeAssumptions())
        let b = OptimizationEngine().optimize(inputs: inputs, assumptions: ConversionApproachTests.makeAssumptions(),
                                              approach: .recommendedTaxMin)
        #expect(abs(a.totalObjectiveCost - b.totalObjectiveCost) < 0.01)
        #expect(a.recommendedPath.count == b.recommendedPath.count)
    }
}
