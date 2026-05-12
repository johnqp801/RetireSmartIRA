//
//  ACASubsidyEngineTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ACASubsidyEngine — FPL lookup")
struct ACASubsidyEngineFPLTests {

    @Test("Household size 1 mainland: fplAmount = 15650 (2026 HHS), fplPercent at MAGI 30k ≈ 191.7%")
    func size1Mainland() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 30_000),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // 2026 HHS FPL HH=1: $15,650
        #expect(result.fplAmount == 15_650)
        // 30,000 / 15,650 × 100 ≈ 191.7%
        #expect(abs(result.fplPercent - 191.7) < 0.5)
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
        #expect(result.fplAmount == 15_650 * 1.25)  // 2026 HH=1: $15,650
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
        #expect(result.fplAmount == 21_150 * 1.15)  // 2026 HH=2: $21,150
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
        #expect(result.fplAmount == 54_150)  // 2026 size 8 value: $54,150
    }
}

@Suite("ACASubsidyEngine — applicable-figure interpolation")
struct ACASubsidyEngineApplicableFigureTests {

    @Test("MAGI = 200% FPL: applicableFigure = 0.04")
    func at200Percent() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, MAGI = 200% of 15650 (2026) = 31300
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 31_300),
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
        // 250% of 15650 (2026) = 39125
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 39_125),
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
        // 225% of 15650 (2026) = 35212.50
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 35_213),
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
        // Size 1, 2026 FPL = $15,650 → 400% cliff = $62,600. MAGI $62,500 → just under.
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 62_500),
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
        // Size 1, 2026 FPL = $15,650 → 400% cliff = $62,600. MAGI $62,700 → over cliff.
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 62_700),
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
        // Size 1, 360% of 15650 (2026) = 56340
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 56_340),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // CORRECTED (backport from V2.0 commit f323da8): cliff sentinel row (400% → 1.00)
        // is now excluded from interpolation. The last non-cliff row is 300% → 0.08.
        // A household at 360% FPL stays at applicable_figure = 0.08; subsidy is positive.
        // applicable_figure = 0.08
        // expected contribution = 56340 × 0.08 = 4507.20
        // subsidy = max(0, 7800 - 4507.20) = 3292.80
        #expect(abs(result.applicableFigure - 0.08) < 0.001)
        #expect(result.annualPremiumAssistance > 0)
        #expect(abs(result.annualPremiumAssistance - (7_800 - 56_340 * 0.08)) < 1.0)
    }

    @Test("350% FPL does not interpolate through cliff sentinel")
    func testApplicableFigure_300to400_DoesNotInterpolateThroughCliff() {
        // 350% FPL should NOT interpolate between 300% (≈0.08) and 400% (1.0 cliff sentinel).
        // Correct behavior: stay near the 300% applicable figure until cliff applies.
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)

        // Size 1: 350% of 15650 (2026) = 54775
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 54_775),
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
