//
//  ACASubsidyEngineTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("ACASubsidyEngine — FPL lookup")
struct ACASubsidyEngineFPLTests {

    @Test("Household size 1 mainland: fplAmount = 15060, fplPercent at MAGI 30k = 199.2%")
    func size1Mainland() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 30_000),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        #expect(result.fplAmount == 15_060)
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
        #expect(result.fplAmount == 15_060 * 1.25)
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
        #expect(result.fplAmount == 20_440 * 1.15)
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
        #expect(result.fplAmount == 52_720)  // size 8 value
    }
}

@Suite("ACASubsidyEngine — applicable-figure interpolation")
struct ACASubsidyEngineApplicableFigureTests {

    @Test("MAGI = 200% FPL: applicableFigure = 0.04")
    func at200Percent() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Size 1, MAGI = 200% of 15060 = 30120
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
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 37_650),  // 250% of 15060
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
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 33_885),  // 225% of 15060
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
        // Size 1, 400% FPL = 60240. MAGI 60000 → just under.
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 60_000),
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
        // Size 1, 400% FPL = 60240
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 60_500),
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
        // Size 1, 360% of 15060 = 54216
        let result = ACASubsidyEngine.calculateSubsidy(
            acaMAGI: ACAMAGI(value: 54_216),
            householdSize: 1,
            benchmarkSilverPlanAnnualPremium: 7_800,
            regionalAdjustment: .mainland48,
            config: config
        )
        // applicable_figure interpolated between 300%(0.08) and 400%(1.00):
        // 360% is 60% of the way → 0.08 + 0.60 × 0.92 = 0.632
        // expected = 54216 × 0.632 ≈ 34_265
        // subsidy = max(0, 7800 - 34265) = 0
        #expect(result.annualPremiumAssistance == 0)
    }
}
