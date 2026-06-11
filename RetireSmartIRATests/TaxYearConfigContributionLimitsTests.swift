//
//  TaxYearConfigContributionLimitsTests.swift
//  RetireSmartIRATests
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("TaxYearConfig — Contribution Limits 2026")
struct TaxYearConfigContributionLimitsTests {

    @Test("401(k) limits load with base + 3 catchup tiers")
    func four01kLimits() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(config.contributionLimits401k.base == 24_500)
        #expect(config.contributionLimits401k.catchupAge50To59 == 8_000)
        #expect(config.contributionLimits401k.catchupAge60To63 == 11_250)
        #expect(config.contributionLimits401k.catchupAge64Plus == 8_000)
    }

    @Test("IRA limits load with base + over-50 catchup")
    func iraLimits() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(config.contributionLimitsIRA.base == 7_500)
        #expect(config.contributionLimitsIRA.catchupAge50Plus == 1_100)
    }

    @Test("HSA limits load with self-only / family / over-55 catchup")
    func hsaLimits() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // 2026 values per IRS Rev. Proc. 2025-19
        #expect(config.contributionLimitsHSA.selfOnly == 4_400)
        #expect(config.contributionLimitsHSA.family == 8_750)
        #expect(config.contributionLimitsHSA.catchupAge55Plus == 1_000)
    }

    @Test("2026 HSA family + both spouses 55+ catch-up = $10,750")
    func testHSALimits_2026_FamilyBothCatchup_Equals10750() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let hsa = config.contributionLimitsHSA
        // IRS Rev. Proc. 2025-19: family $8,750 + 2 × $1,000 catch-up = $10,750
        let combined = hsa.family + (2 * hsa.catchupAge55Plus)
        #expect(combined == 10_750,
            "Family HDHP with both spouses 55+ should allow $10,750 combined HSA contribution")
    }
}

@Suite("TaxYearConfig — Medicare 2026 defaults")
struct TaxYearConfigMedicareTests {

    @Test("Medicare premium defaults load from JSON")
    func medicareDefaultsLoad() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(config.medicare2026.partBStandardMonthly == 202.90)
        #expect(config.medicare2026.partDAvgMonthly == 50.00)
        #expect(config.medicare2026.medigapAvgMonthly == 150.00)
        #expect(config.medicare2026.advantageAvgMonthly == 50.00)
    }
}

@Suite("TaxYearConfig — ACA Subsidy 2026")
struct TaxYearConfigACASubsidyTests {

    @Test("ACA FPL table loads with all 8 household sizes — 2025 HHS values (prior-year-FPL rule for 2026 PTC)")
    func fplTableLoads() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Per 26 CFR 1.36B, 2026 PTC uses 2025 HHS Federal Poverty Guidelines.
        // HH=1 $15,060; +$5,380 per additional member (48 states + DC).
        // Updated 2026-05-17 per 1.8.2 C2 audit.
        #expect(config.acaSubsidy2026.fpl2026.householdSizeToFPL["1"] == 15_650)
        #expect(config.acaSubsidy2026.fpl2026.householdSizeToFPL["2"] == 21_150)
        #expect(config.acaSubsidy2026.fpl2026.householdSizeToFPL["8"] == 54_150)
        #expect(config.acaSubsidy2026.fpl2026.alaskaMultiplier == 1.25)
        #expect(config.acaSubsidy2026.fpl2026.hawaiiMultiplier == 1.15)
    }

    @Test("2026 ACA cliff HH=2 is $81,760 (400% × $20,440, 2025 HHS, per prior-year-FPL rule)")
    func testACA_FPL_2026_HouseholdOf2() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let fpl = config.acaSubsidy2026.fpl2026.householdSizeToFPL["2"] ?? 0
        #expect(fpl == 21_150, "2025 HHS FPL HH=2 should be $21,150 (used for 2026 PTC)")
        // 400% cliff
        let cliff = fpl * 4
        #expect(cliff == 84_600, "400% FPL cliff HH=2 should be $84,600")
    }

    @Test("ACA applicable figures table loads in ascending fplPercent order")
    func applicableFiguresLoad() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        let figures = config.acaSubsidy2026.applicableFigures
        #expect(figures.count >= 5)
        #expect(figures.first?.fplPercent == 100)
        #expect(figures.last?.fplPercent == 400)
        // Cliff present: last entry's applicable_figure is 1.0 (subsidy = 0)
        #expect(figures.last?.applicableFigure == 1.00)
    }

    @Test("ACA cliff flag and benchmark Silver plan annual load")
    func cliffAndBenchmark() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        #expect(config.acaSubsidy2026.hasCliff == true)
        #expect(config.acaSubsidy2026.nationalAvgBenchmarkSilverPlanAnnual == 7_800)
    }
}
