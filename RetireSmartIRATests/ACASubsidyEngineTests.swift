//
//  ACASubsidyEngineTests.swift
//  RetireSmartIRATests
//
//  Note: 2026 ACA Premium Tax Credit uses 2025 HHS Federal Poverty Level
//  per 26 CFR 1.36B (prior-year FPL rule). HH=1 = $15,060; +$5,380 per
//  additional member. Expected values updated 2026-05-17 per 1.8.2 C2 audit.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ACASubsidyEngine — FPL lookup")
struct ACASubsidyEngineFPLTests {

    @Test("Household size 1 mainland: fplAmount = 15060 (2025 HHS, per prior-year-FPL rule), fplPercent at MAGI 30k ≈ 199.2%")
    func size1Mainland() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 30_000),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // 2025 HHS FPL HH=1: $15,060 (used for 2026 PTC per prior-year rule)
        #expect(result.fplAmount == 15_060)
        // 30,000 / 15,060 × 100 ≈ 199.2%
        #expect(abs(result.fplPercent - 199.2) < 0.5)
    }

    @Test("Alaska multiplier applies")
    func alaskaMultiplier() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 30_000),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .alaska,
            config: config
        )
        #expect(result.fplAmount == 15_060 * 1.25)  // 2025 HH=1: $15,060
    }

    @Test("Hawaii multiplier applies")
    func hawaiiMultiplier() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 30_000),
            householdSize: 2,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .hawaii,
            config: config
        )
        #expect(result.fplAmount == 20_440 * 1.15)  // 2025 HH=2: $20,440
    }

    @Test("Household size 9+ caps at size 8 lookup")
    func householdSize9CapsAt8() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 100_000),
            householdSize: 12,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(result.fplAmount == 52_720)  // 2025 size 8 value: $52,720
    }
}

@Suite("ACASubsidyEngine — applicable-figure interpolation")
struct ACASubsidyEngineApplicableFigureTests {

    @Test("MAGI = 200% FPL: applicableFigure = 0.04")
    func at200Percent() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, MAGI = 200% of 15060 (2025 HHS) = 30120
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 30_120),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(abs(result.applicableFigure - 0.04) < 0.001)
    }

    @Test("MAGI = 250% FPL: applicableFigure = 0.06")
    func at250Percent() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // 250% of 15060 (2025 HHS) = 37650
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 37_650),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(abs(result.applicableFigure - 0.06) < 0.001)
    }

    @Test("MAGI = 225% FPL: linearly interpolated 0.05")
    func at225PercentInterpolated() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // 225% of 15060 (2025 HHS) = 33885
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 33_885),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // Halfway between 200% (0.04) and 250% (0.06) → 0.05
        #expect(abs(result.applicableFigure - 0.05) < 0.001)
    }
}

@Suite("ACASubsidyEngine — cliff detection")
struct ACASubsidyEngineCliffTests {

    @Test("MAGI just under 400% FPL: subsidy positive, isOverCliff false, dollarsToCliff > 0")
    func justUnderCliff() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, 2025 HHS FPL = $15,060 → 400% cliff = $60,240. MAGI $60,100 → just under.
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 60_100),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(result.isOverCliff == false)
        #expect(result.dollarsToCliff! > 0)
        #expect(result.dollarsToCliff! < 1_000)
    }

    @Test("MAGI ≥ 400% FPL: subsidy = 0, isOverCliff = true")
    func atOrAboveCliff() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, 2025 HHS FPL = $15,060 → 400% cliff = $60,240. MAGI $60,300 → over cliff.
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 60_300),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(result.isOverCliff == true)
        #expect(result.annualPremiumAssistance == 0)
    }

    @Test("Subsidy = benchmark - expectedContribution at 360% FPL")
    func subsidyComputation() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, 360% of 15060 (2025 HHS) = 54216
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 54_216),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // CORRECTED (backport from V2.0 commit f323da8): cliff sentinel row (400% → 1.00)
        // is now excluded from interpolation. The last non-cliff row is 300% → 0.08.
        // A household at 360% FPL stays at applicable_figure = 0.08; subsidy is positive.
        // applicable_figure = 0.08
        // expected contribution = 54216 × 0.08 = 4337.28
        // subsidy = max(0, 7800 - 4337.28) = 3462.72
        #expect(abs(result.applicableFigure - 0.08) < 0.001)
        #expect(result.annualPremiumAssistance > 0)
        #expect(abs(result.annualPremiumAssistance - (7_800 - 54_216 * 0.08)) < 1.0)
    }

    @Test("350% FPL does not interpolate through cliff sentinel")
    func testApplicableFigure_300to400_DoesNotInterpolateThroughCliff() {
        // 350% FPL should NOT interpolate between 300% (≈0.08) and 400% (1.0 cliff sentinel).
        // Correct behavior: stay near the 300% applicable figure until cliff applies.
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)

        // Size 1: 350% of 15060 (2025 HHS) = 52710
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 52_710),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )

        // Expected: applicable figure stays near 0.08 (table cap), NOT ~0.54 interpolated junk
        #expect(result.applicableFigure < 0.10,
            "Applicable figure must not interpolate through cliff sentinel — got \(result.applicableFigure), expected ~0.08")
    }
}
