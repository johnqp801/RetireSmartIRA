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
        // Updated 2026-05-03 (constants refresh): old expected base 23_500/catchup50 7_500/catchup60 11_250/catchup64 7_500;
        // new expected values reflect IRS Notice 2025-67 and SECURE 2.0 formula.
        #expect(config.contributionLimits401k.base == 24_500)
        #expect(config.contributionLimits401k.catchupAge50To59 == 8_000)
        #expect(config.contributionLimits401k.catchupAge60To63 == 12_000)
        #expect(config.contributionLimits401k.catchupAge64Plus == 8_000)
    }

    @Test("IRA limits load with base + over-50 catchup")
    func iraLimits() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Updated 2026-05-03 (constants refresh): old expected base 7_000/catchup 1_000;
        // new expected values reflect IRS Notice 2025-67.
        #expect(config.contributionLimitsIRA.base == 7_500)
        #expect(config.contributionLimitsIRA.catchupAge50Plus == 1_100)
    }

    @Test("HSA limits load with self-only / family / over-55 catchup")
    func hsaLimits() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Updated 2026-05-03 (constants refresh): old expected selfOnly 4_300/family 8_550;
        // new expected values reflect IRS Pub 969 / Rev. Proc. 2025-19.
        #expect(config.contributionLimitsHSA.selfOnly == 4_400)
        #expect(config.contributionLimitsHSA.family == 8_750)
        #expect(config.contributionLimitsHSA.catchupAge55Plus == 1_000)
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

    @Test("ACA FPL table loads with all 8 household sizes")
    func fplTableLoads() {
        let config = TaxYearConfig.loadOrFallback(forYear: 2026)
        // Updated 2026-05-03 (constants refresh): old expected HH1 15_060/HH8 52_720;
        // new expected values reflect HHS ASPE 2026 Poverty Guidelines.
        #expect(config.acaSubsidy2026.fpl2026.householdSizeToFPL["1"] == 15_960)
        #expect(config.acaSubsidy2026.fpl2026.householdSizeToFPL["8"] == 55_720)
        #expect(config.acaSubsidy2026.fpl2026.alaskaMultiplier == 1.25)
        #expect(config.acaSubsidy2026.fpl2026.hawaiiMultiplier == 1.15)
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
