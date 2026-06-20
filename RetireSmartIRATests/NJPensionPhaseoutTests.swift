//
//  NJPensionPhaseoutTests.swift
//  RetireSmartIRATests
//
//  Boundary coverage for the New Jersey pension/retirement-income exclusion
//  AGI phaseout (NJSA 54A:6-15). The exclusion is stepped by TOTAL NJ gross
//  income with per-filing-status caps ($100K MFJ / $75K single):
//
//    Total NJ gross income      MFJ %     Single %
//    ≤ $100,000                 100%      100%
//    $100,001–$125,000           50%      37.5%
//    $125,001–$150,000           25%      18.75%
//    > $150,000                   0%       0%   (cliff)
//
//  The pension exclusion is `min(pension × tier%, chartMax)`, where chartMax is
//  the Worksheet D chart ceiling (the per-filing-status cap at the ≤$100K tier,
//  tier% × total income in the phaseout bands, $0 over $150K). These tests drive
//  the engine through its direct static API so the total-income gate and pension
//  amount can be controlled exactly.
//
//  1.9 NOTE: The Worksheet D "Other Retirement Income Exclusion" is now live
//  (NJSA 54A:6-15, NJ-1040 Worksheet D line 3). The UNUSED portion of the chart
//  maximum (chartMax − pension exclusion) shelters OTHER eligible income
//  (interest/dividends/cap-gains/etc.) when the taxpayer is 62+, total income
//  ≤ $150K, and earned income ≤ $3,000. In this helper the "other" income is the
//  difference between `totalIncome` and the pension source; because age is 65
//  with no earned income, that other income is now sheltered by the unused
//  exclusion. Several assertions below were recomputed accordingly — these are
//  correct NJ outcomes, not regressions.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("NJ pension-exclusion AGI phaseout (NJSA 54A:6-15)")
struct NJPensionPhaseoutTests {

    /// Helper: compute NJ state tax for a given total gross income and pension
    /// amount, age 62+ (1961 birth → 65 in 2026). Any "other" income is the
    /// difference between `totalIncome` and the pension source; with Worksheet D
    /// live it is eligible for the other-retirement-income exclusion (no earned
    /// income here, total ≤ $150K, age 65).
    private func njTax(
        totalIncome: Double,
        pension: Double,
        filingStatus: FilingStatus
    ) -> Double {
        let sources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: pension)
        ]
        return TaxCalculationEngine.calculateStateTax(
            income: totalIncome,
            forState: .newJersey,
            filingStatus: filingStatus,
            taxableSocialSecurity: 0,
            incomeSources: sources,
            currentAge: 65,
            enableSpouse: filingStatus == .marriedFilingJointly,
            spouseBirthYear: 1961,
            currentYear: 2026
        )
    }

    // MARK: - MFJ ≤ $100K: full exclusion preserved

    @Test("MFJ, total ≤ $100K → pension + other fully excluded")
    func mfjUnderHundredKFullExclusion() {
        // $80K pension + $20K other = $100K total → 100% tier, chartMax $100K.
        // Pension exclusion = min($80K × 100%, $100K) = $80K.
        // Unused = $100K − $80K = $20K → shelters the $20K of other income.
        // Taxable = $100K − $80K − $20K = $0. NJ tax = $0.
        let tax = njTax(totalIncome: 100_000, pension: 80_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 0) < 2, "Expected $0 (pension + other fully excluded). Got \(tax)")
    }

    // MARK: - MFJ $150K worked example: 25% tier (Worksheet D)

    @Test("MFJ, $50K dividends + $100K pension, total $150K → 25% tier + Worksheet D")
    func mfjOneFiftyKTwentyFivePercentTier() {
        // Total $150,000 → 25% band. chartMax = 25% × $150K = $37,500.
        // Pension exclusion = min($100K × 25%, $37,500) = $25,000.
        // Unused = $37,500 − $25,000 = $12,500 → shelters $12,500 of the $50K other.
        // Taxable = $150,000 − $25,000 − $12,500 = $112,500. NJ MFJ tax = $3,440.63.
        let tax = njTax(totalIncome: 150_000, pension: 100_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 3_440.63) < 2,
                "Expected ≈$3,440.63 (taxable $112,500 after Worksheet D). Got \(tax)")
    }

    // MARK: - MFJ tier boundaries (50% tier)

    @Test("MFJ, total exactly $125,000 → 50% tier (inclusive upper bound)")
    func mfjOneTwentyFiveKBoundaryFiftyPercent() {
        // $100K pension + $25K other = $125K → 50% tier. chartMax = 50% × $125K = $62,500.
        // Pension exclusion = min($100K × 50%, $62,500) = $50,000.
        // Unused = $62,500 − $50,000 = $12,500 → shelters $12,500 of the $25K other.
        // Taxable = $125,000 − $50,000 − $12,500 = $62,500. NJ MFJ tax = $1,111.25.
        let tax = njTax(totalIncome: 125_000, pension: 100_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 1_111.25) < 2, "Expected ≈$1,111.25 (50% tier + Worksheet D). Got \(tax)")
    }

    @Test("MFJ, total $100,001 (just over) → 50% tier")
    func mfjJustOverHundredKFiftyPercent() {
        // $100K pension + $1 other = $100,001 → 50% band. chartMax = 50% × $100,001 = $50,000.50.
        // Pension exclusion = min($100K × 50%, $50,000.50) = $50,000.
        // Unused = $0.50 → shelters $0.50 of the $1 other. Taxable = $50,000.50.
        // NJ MFJ tax ≈ $805.01.
        let tax = njTax(totalIncome: 100_001, pension: 100_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 805.01) < 2, "Expected ≈$805 (50% tier just over $100K). Got \(tax)")
    }

    // MARK: - Single $75K cap + single-status tiers

    @Test("Single, $90K pension, total ≤ $100K → cap is $75K (not $100K)")
    func singleCapIsSeventyFiveK() {
        // $90K pension, total $90K ≤ $100K → 100% tier. chartMax = $75K single cap.
        // Pension exclusion = min($90K × 100%, $75K) = $75K. There is no "other"
        // income ($90K total = $90K pension), so unused exclusion shelters nothing.
        // Taxable = $90K − $75K = $15K. NJ single tax on $15K = $210.
        let tax = njTax(totalIncome: 90_000, pension: 90_000, filingStatus: .single)
        #expect(abs(tax - 210) < 2, "Expected ≈$210 ($75K single cap leaves $15K taxable). Got \(tax)")
    }

    @Test("Single, total $150K → 18.75% tier with $75K cap + Worksheet D")
    func singleOneFiftyKTwentyTier() {
        // $100K pension + $50K other = $150K → 18.75% band. chartMax = 18.75% × $150K = $28,125.
        // Pension exclusion = min($100K × 18.75%, $28,125) = $18,750.
        // Unused = $28,125 − $18,750 = $9,375 → shelters $9,375 of the $50K other.
        // Taxable = $150,000 − $18,750 − $9,375 = $121,875. NJ single tax = $5,637.19.
        let tax = njTax(totalIncome: 150_000, pension: 100_000, filingStatus: .single)
        #expect(abs(tax - 5_637.19) < 2, "Expected ≈$5,637.19 (18.75% tier + Worksheet D). Got \(tax)")
    }

    // MARK: - > $150K cliff

    @Test("MFJ, total $160K → 0% exclusion (cliff, full income taxed)")
    func mfjAboveOneFiftyKCliff() {
        // $100K pension + $60K other = $160K → > $150,000 → 0% exclusion, chartMax $0.
        // No pension exclusion, no Worksheet D shelter (chartMax $0 and total > $150K).
        // Taxable = full $160,000. NJ MFJ tax = $6,149.50.
        let tax = njTax(totalIncome: 160_000, pension: 100_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 6_149.50) < 2, "Expected ≈$6,150 (cliff, no exclusion). Got \(tax)")
    }
}
