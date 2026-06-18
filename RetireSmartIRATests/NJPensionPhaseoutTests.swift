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
//  The cap is applied to the excludable pension/retirement income BEFORE the
//  tier percentage. These tests drive the engine through its direct static
//  API so the total-income gate and pension amount can be controlled exactly.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("NJ pension-exclusion AGI phaseout (NJSA 54A:6-15)")
struct NJPensionPhaseoutTests {

    /// Helper: compute NJ state tax for a given total gross income and pension
    /// amount, age 62+ (1961 birth → 65 in 2026). Dividends/other income is
    /// implicitly the difference between `totalIncome` and the pension source;
    /// it is not separately exempt, so it simply rides in `income`.
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

    @Test("MFJ, total ≤ $100K → full pension exclusion (existing behavior preserved)")
    func mfjUnderHundredKFullExclusion() {
        // $80K pension + $20K other = $100K total → 100% tier.
        // Excludable = min($80K, $100K MFJ cap) × 100% = $80K.
        // Taxable = $100K − $80K = $20K. NJ MFJ tax on $20K = $20K × 1.4% = $280.
        let tax = njTax(totalIncome: 100_000, pension: 80_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 280) < 2, "Expected ≈$280 (full $80K excluded). Got \(tax)")
    }

    // MARK: - MFJ $150K worked example: 25% tier

    @Test("MFJ, $50K dividends + $100K pension, total $150K → 25% tier")
    func mfjOneFiftyKTwentyFivePercentTier() {
        // Total $150,000 → $125,001–$150,000 band → 25%.
        // Excludable = min($100K pension, $100K MFJ cap) × 25% = $25,000.
        // Taxable = $150,000 − $25,000 = $125,000 → NJ MFJ tax = $4,131.25.
        let tax = njTax(totalIncome: 150_000, pension: 100_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 4_131.25) < 2,
                "Expected ≈$4,131 (only 25% of pension excluded, taxable $125K). Got \(tax)")
    }

    // MARK: - MFJ tier boundaries (50% tier)

    @Test("MFJ, total exactly $125,000 → 50% tier (inclusive upper bound)")
    func mfjOneTwentyFiveKBoundaryFiftyPercent() {
        // $100K pension + $25K other = $125K → still ≤ $125,000 → 50%.
        // Excludable = min($100K, $100K cap) × 50% = $50K. Taxable = $75K.
        // NJ MFJ tax on $75K = $1,470.
        let tax = njTax(totalIncome: 125_000, pension: 100_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 1_470) < 2, "Expected ≈$1,470 (50% tier). Got \(tax)")
    }

    @Test("MFJ, total $100,001 (just over) → 50% tier")
    func mfjJustOverHundredKFiftyPercent() {
        // $100K pension + $1 other = $100,001 → first 50% band.
        // Excludable = min($100K, $100K cap) × 50% = $50K. Taxable = $50,001.
        // NJ MFJ tax ≈ $805.02.
        let tax = njTax(totalIncome: 100_001, pension: 100_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 805.02) < 2, "Expected ≈$805 (50% tier just over $100K). Got \(tax)")
    }

    // MARK: - Single $75K cap + single-status tiers

    @Test("Single, $90K pension, total ≤ $100K → cap is $75K (not $100K)")
    func singleCapIsSeventyFiveK() {
        // $90K pension, total $90K ≤ $100K → 100% tier.
        // Excludable = min($90K pension, $75K SINGLE cap) × 100% = $75K.
        // Taxable = $90K − $75K = $15K. NJ single tax on $15K = $210.
        // (If the cap were wrongly $100K, the full $90K would exclude → $0.)
        let tax = njTax(totalIncome: 90_000, pension: 90_000, filingStatus: .single)
        #expect(abs(tax - 210) < 2, "Expected ≈$210 ($75K single cap leaves $15K taxable). Got \(tax)")
    }

    @Test("Single, total $150K → 18.75% tier with $75K cap")
    func singleOneFiftyKTwentyTier() {
        // $100K pension + $50K other = $150K → $125,001–$150,000 band → 18.75%.
        // Excludable = min($100K pension, $75K cap) × 18.75% = $14,062.50.
        // Taxable = $150,000 − $14,062.50 = $135,937.50.
        // NJ single tax on $135,937.50 = $6,532.97 (hardcoded so this test can't
        // pass on a shared bracket-helper error).
        let tax = njTax(totalIncome: 150_000, pension: 100_000, filingStatus: .single)
        #expect(abs(tax - 6_532.97) < 2, "Expected ≈$6,532.97 (18.75% tier, $75K cap). Got \(tax)")
    }

    // MARK: - > $150K cliff

    @Test("MFJ, total $160K → 0% exclusion (cliff, full pension taxed)")
    func mfjAboveOneFiftyKCliff() {
        // $100K pension + $60K other = $160K → > $150,000 → 0% exclusion.
        // Taxable = full $160,000. NJ MFJ tax = $6,149.50.
        let tax = njTax(totalIncome: 160_000, pension: 100_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 6_149.50) < 2, "Expected ≈$6,150 (cliff, no exclusion). Got \(tax)")
    }
}
