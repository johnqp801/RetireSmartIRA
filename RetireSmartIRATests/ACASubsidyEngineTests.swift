//
//  ACASubsidyEngineTests.swift
//  RetireSmartIRATests
//
//  Note: 2026 ACA Premium Tax Credit uses 2025 HHS Federal Poverty Level
//  per 26 CFR 1.36B (prior-year FPL rule). HH=1 = $15,650; +$5,500 per
//  additional member. Applicable percentages per Rev. Proc. 2025-25
//  (2.10%–9.96%; enhanced subsidies expired end of 2025, cliff at 400%).
//  Expected values updated 2026-06-10 per article-3 ACA config audit.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ACASubsidyEngine — FPL lookup")
struct ACASubsidyEngineFPLTests {

    @Test("Household size 1 mainland: fplAmount = 15650 (2025 HHS, per prior-year-FPL rule), fplPercent at MAGI 30k ≈ 191.7%")
    func size1Mainland() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 30_000),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // 2025 HHS FPL HH=1: $15,650 (used for 2026 PTC per prior-year rule)
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
        #expect(result.fplAmount == 15_650 * 1.25)  // 2025 HH=1: $15,650
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
        #expect(result.fplAmount == 21_150 * 1.15)  // 2025 HH=2: $21,150
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
        #expect(result.fplAmount == 54_150)  // 2025 size 8 value: $54,150
    }
}

@Suite("ACASubsidyEngine — applicable-figure interpolation")
struct ACASubsidyEngineApplicableFigureTests {

    @Test("MAGI = 200% FPL: applicableFigure = 0.0660 (Rev. Proc. 2025-25)")
    func at200Percent() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, MAGI = 200% of 15650 (2025 HHS) = 31300
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 31_300),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(abs(result.applicableFigure - 0.0660) < 0.001)
    }

    @Test("MAGI = 250% FPL: applicableFigure = 0.0844 (Rev. Proc. 2025-25)")
    func at250Percent() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // 250% of 15650 (2025 HHS) = 39125
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 39_125),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(abs(result.applicableFigure - 0.0844) < 0.001)
    }

    @Test("MAGI = 225% FPL: linearly interpolated 0.0752")
    func at225PercentInterpolated() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // 225% of 15650 (2025 HHS) = 35212.50
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 35_212.50),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // Halfway between 200% (0.0660) and 250% (0.0844) → 0.0752
        #expect(abs(result.applicableFigure - 0.0752) < 0.001)
    }

    @Test("MAGI = 120% FPL: flat 0.0210 band below 133%")
    func at120PercentFlatBand() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // 120% of 15650 (2025 HHS) = 18780
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 18_780),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // Below 133% FPL the applicable percentage is a flat 2.10%
        #expect(abs(result.applicableFigure - 0.0210) < 0.001)
    }
}

@Suite("ACASubsidyEngine — cliff detection")
struct ACASubsidyEngineCliffTests {

    @Test("MAGI just under 400% FPL: subsidy positive, isOverCliff false, dollarsToCliff > 0")
    func justUnderCliff() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, 2025 HHS FPL = $15,650 → 400% cliff = $62,600. MAGI $62,400 → just under.
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 62_400),
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
        // Size 1, 2025 HHS FPL = $15,650 → 400% cliff = $62,600. MAGI $62,700 → over cliff.
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

    @Test("Couple cliff sits at $84,600 (2× FPL row, household of 2)")
    func coupleCliff() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 2, 2025 HHS FPL = $21,150 → 400% cliff = $84,600.
        let under = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 84_500),
            householdSize: 2,
            benchmarkSilverPlanAnnualPremium: 15_600,
            regionalAdjustment: .mainland48,
            config: config
        )
        let over = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 84_700),
            householdSize: 2,
            benchmarkSilverPlanAnnualPremium: 15_600,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(under.isOverCliff == false)
        #expect(over.isOverCliff == true)
        #expect(over.annualPremiumAssistance == 0)
    }

    @Test("Subsidy = benchmark - expectedContribution at 360% FPL")
    func subsidyComputation() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, 360% of 15650 (2025 HHS) = 56340
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 56_340),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // Cliff sentinel row (400% → 1.00) is excluded from interpolation.
        // The last non-cliff row is 300% → 0.0996. A household at 360% FPL
        // stays at applicable_figure = 0.0996; subsidy is positive.
        // expected contribution = 56340 × 0.0996 = 5611.46
        // subsidy = max(0, 7800 - 5611.46) = 2188.54
        #expect(abs(result.applicableFigure - 0.0996) < 0.001)
        #expect(result.annualPremiumAssistance > 0)
        #expect(abs(result.annualPremiumAssistance - (7_800 - 56_340 * 0.0996)) < 1.0)
    }

    @Test("350% FPL does not interpolate through cliff sentinel")
    func testApplicableFigure_300to400_DoesNotInterpolateThroughCliff() {
        // 350% FPL should NOT interpolate between 300% (0.0996) and 400% (1.0 cliff sentinel).
        // Correct behavior: stay at the 300% applicable figure until the cliff applies.
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)

        // Size 1: 350% of 15650 (2025 HHS) = 54775
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 54_775),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )

        // Expected: applicable figure stays at 0.0996 (table cap), NOT ~0.55 interpolated junk
        #expect(result.applicableFigure < 0.105,
            "Applicable figure must not interpolate through cliff sentinel — got \(result.applicableFigure), expected ~0.0996")
    }
}
