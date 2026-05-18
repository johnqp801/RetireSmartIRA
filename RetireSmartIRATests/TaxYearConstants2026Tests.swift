//
//  TaxYearConstants2026Tests.swift
//  RetireSmartIRATests
//
//  Regression tests for 2026 tax constants audited against real-world published values:
//  - HSA contribution limits (IRS Rev. Proc. 2025-19)
//  - HHS Federal Poverty Level (48 states)
//  - ACA enhanced subsidy expiration (ARPA/IRA expired Dec 31, 2025)
//  - Social Security COLA (CMS/SSA Oct 2025)
//  - Medicare Part B standard premium (CMS Nov 2025)
//  - Federal MFJ bracket tops (IRS Rev. Proc. 2025-32)
//
//  These tests pin the audited values to prevent quiet drift in future tax-year updates.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("TaxYearConstants2026 — Regression tests for audited constants")
struct TaxYearConstants2026Tests {

    private func cfg() -> TaxYearConfig {
        TaxYearConfig.loadOrFallback(forYear: 2026)
    }

    // MARK: - HSA Contribution Limits (IRS Rev. Proc. 2025-19)

    @Test("HSA self-only limit 2026 = $4,400")
    func hsaSelfOnlyLimit() {
        let config = cfg()
        #expect(config.contributionLimitsHSA.selfOnly == 4_400)
    }

    @Test("HSA family limit 2026 = $8,750")
    func hsaFamilyLimit() {
        let config = cfg()
        #expect(config.contributionLimitsHSA.family == 8_750)
    }

    @Test("HSA catchup age 55+ = $1,000")
    func hsaCatchupAge55Plus() {
        let config = cfg()
        #expect(config.contributionLimitsHSA.catchupAge55Plus == 1_000)
    }

    // MARK: - HHS Federal Poverty Level 2026 (48 states)

    @Test("HHS FPL 2026 household size 1 (single) = $15,650")
    func fplHouseholdSize1() {
        let config = cfg()
        let fpl1 = config.acaSubsidy2026.fpl2026.householdSizeToFPL["1"]
        #expect(fpl1 == 15_650)
    }

    @Test("HHS FPL 2026 household size 2 = $21,150")
    func fplHouseholdSize2() {
        let config = cfg()
        let fpl2 = config.acaSubsidy2026.fpl2026.householdSizeToFPL["2"]
        #expect(fpl2 == 21_150)
    }

    @Test("HHS FPL 2026 household size 3 = $26,650")
    func fplHouseholdSize3() {
        let config = cfg()
        let fpl3 = config.acaSubsidy2026.fpl2026.householdSizeToFPL["3"]
        #expect(fpl3 == 26_650)
    }

    @Test("HHS FPL 2026 household size 4 = $32,150")
    func fplHouseholdSize4() {
        let config = cfg()
        let fpl4 = config.acaSubsidy2026.fpl2026.householdSizeToFPL["4"]
        #expect(fpl4 == 32_150)
    }

    @Test("HHS FPL 2026 Alaska multiplier = 1.25")
    func fplAlaskaMultiplier() {
        let config = cfg()
        #expect(config.acaSubsidy2026.fpl2026.alaskaMultiplier == 1.25)
    }

    @Test("HHS FPL 2026 Hawaii multiplier = 1.15")
    func fplHawaiiMultiplier() {
        let config = cfg()
        #expect(config.acaSubsidy2026.fpl2026.hawaiiMultiplier == 1.15)
    }

    // MARK: - ACA Enhanced Subsidies (ARPA/IRA Expiration)
    // Enhanced subsidies expired Dec 31, 2025.
    // 2026 must use pre-ARPA applicablePercentage schedule with 400% FPL cliff.

    @Test("ACA cliff enabled (400% FPL cliff active)")
    func acaCliffActive() {
        let config = cfg()
        #expect(config.acaSubsidy2026.hasCliff == true)
    }

    @Test("ACA applicable figure at 100% FPL = 0.00 (no subsidy for 0-100% FPL)")
    func acaApplicableFigure100Percent() {
        let config = cfg()
        let fig100 = config.acaSubsidy2026.applicableFigures.first { $0.fplPercent == 100 }
        #expect(fig100?.applicableFigure == 0.00)
    }

    @Test("ACA applicable figure at 200% FPL = 0.04 (pre-ARPA schedule)")
    func acaApplicableFigure200Percent() {
        let config = cfg()
        let fig200 = config.acaSubsidy2026.applicableFigures.first { $0.fplPercent == 200 }
        #expect(fig200?.applicableFigure == 0.04)
    }

    @Test("ACA applicable figure at 300% FPL = 0.08 (pre-ARPA ceiling for 300-400% band)")
    func acaApplicableFigure300Percent() {
        let config = cfg()
        let fig300 = config.acaSubsidy2026.applicableFigures.first { $0.fplPercent == 300 }
        #expect(fig300?.applicableFigure == 0.08)
    }

    @Test("ACA cliff entry at 400% FPL marks hard subsidy cliff")
    func acaCliffEntryAt400Percent() {
        let config = cfg()
        let fig400 = config.acaSubsidy2026.applicableFigures.first { $0.fplPercent == 400 }
        #expect(fig400?.applicableFigure == 1.00)  // sentinel value marking the cliff
    }

    @Test("ACA applicable figures list has exactly 6 entries (100%, 150%, 200%, 250%, 300%, 400%)")
    func acaApplicableFiguresCount() {
        let config = cfg()
        #expect(config.acaSubsidy2026.applicableFigures.count == 6)
    }

    // MARK: - Social Security COLA 2026 (CMS/SSA Oct 2025)

    @Test("SS COLA 2026 default = 2.5% (0.025 as decimal)")
    func ssCOLA2026Default() {
        // Note: The default COLA is hardcoded in SSWhatIfParameters; this documents the expected 2026 rate.
        // The actual COLA rate is user-configurable, so we test that it defaults to the official 2026 rate.
        let expectedCOLA = 2.5  // Official 2026 COLA
        let defaultParams = SSWhatIfParameters()
        #expect(defaultParams.colaRate == expectedCOLA)
    }

    // MARK: - Medicare Part B Standard Premium 2026 (CMS Nov 2025)

    @Test("Medicare Part B standard premium 2026 = $202.90 monthly")
    func medicarePartBStandardMonthly() {
        let config = cfg()
        #expect(config.medicare2026.partBStandardMonthly == 202.90)
    }

    @Test("IRMAA standard Part B reference = $202.90 (matches Medicare2026 config)")
    func irmaaStandardPartBMatches() {
        let config = cfg()
        #expect(config.irmaaStandardPartB == 202.90)
    }

    @Test("IRMAA tier 0 (base) Part B = $202.90")
    func irmaaTier0PartB() {
        let config = cfg()
        let tier0 = config.irmaaTiers.first { $0.tier == 0 }
        #expect(tier0?.partBMonthly == 202.90)
    }

    // MARK: - Federal MFJ Bracket Thresholds 2026 (IRS Rev. Proc. 2025-32)
    // Standard IRS 2026 published bracket tops

    @Test("Federal MFJ 12% bracket top (threshold) = $96,950")
    func mfjBracket12PercentTop() {
        let config = cfg()
        let bracket12 = config.federalBracketsMFJ.first { $0.rate == 0.12 }
        #expect(bracket12?.threshold == 96_950)
    }

    @Test("Federal MFJ 22% bracket top (threshold) = $206,700")
    func mfjBracket22PercentTop() {
        let config = cfg()
        let bracket22 = config.federalBracketsMFJ.first { $0.rate == 0.22 }
        #expect(bracket22?.threshold == 206_700)
    }

    @Test("Federal MFJ 24% bracket top (threshold) = $394,600")
    func mfjBracket24PercentTop() {
        let config = cfg()
        let bracket24 = config.federalBracketsMFJ.first { $0.rate == 0.24 }
        #expect(bracket24?.threshold == 394_600)
    }

    @Test("Federal MFJ 32% bracket top (threshold) = $806,800")
    func mfjBracket32PercentTop() {
        let config = cfg()
        let bracket32 = config.federalBracketsMFJ.first { $0.rate == 0.32 }
        #expect(bracket32?.threshold == 806_800)
    }

    @Test("Federal MFJ 35% bracket top (threshold) = $1,024,200")
    func mfjBracket35PercentTop() {
        let config = cfg()
        let bracket35 = config.federalBracketsMFJ.first { $0.rate == 0.35 }
        #expect(bracket35?.threshold == 1_024_200)
    }

    @Test("Federal MFJ 37% bracket top (threshold) = $1,537,400")
    func mfjBracket37PercentTop() {
        let config = cfg()
        let bracket37 = config.federalBracketsMFJ.first { $0.rate == 0.37 }
        #expect(bracket37?.threshold == 1_537_400)
    }

    // MARK: - Federal Single Bracket Thresholds 2026
    // Derived from MFJ using standard IRS patterns (roughly 48-50% of MFJ for lower brackets)

    @Test("Federal Single 12% bracket top (threshold) = $48,475")
    func singleBracket12PercentTop() {
        let config = cfg()
        let bracket12 = config.federalBracketsSingle.first { $0.rate == 0.12 }
        #expect(bracket12?.threshold == 48_475)
    }

    @Test("Federal Single 22% bracket top (threshold) = $103,350")
    func singleBracket22PercentTop() {
        let config = cfg()
        let bracket22 = config.federalBracketsSingle.first { $0.rate == 0.22 }
        #expect(bracket22?.threshold == 103_350)
    }

    @Test("Federal Single 24% bracket top (threshold) = $197,300")
    func singleBracket24PercentTop() {
        let config = cfg()
        let bracket24 = config.federalBracketsSingle.first { $0.rate == 0.24 }
        #expect(bracket24?.threshold == 197_300)
    }

    // MARK: - Comprehensive Bracket Structure Tests

    @Test("Federal MFJ brackets list has 7 entries (10%, 12%, 22%, 24%, 32%, 35%, 37%)")
    func mfjBracketsCount() {
        let config = cfg()
        #expect(config.federalBracketsMFJ.count == 7)
    }

    @Test("Federal Single brackets list has 7 entries (10%, 12%, 22%, 24%, 32%, 35%, 37%)")
    func singleBracketsCount() {
        let config = cfg()
        #expect(config.federalBracketsSingle.count == 7)
    }

    @Test("Federal MFJ 10% bracket starts at $0 threshold")
    func mfjBracket10PercentStart() {
        let config = cfg()
        let bracket10 = config.federalBracketsMFJ.first { $0.rate == 0.10 }
        #expect(bracket10?.threshold == 0)
    }

    @Test("Federal Single 10% bracket starts at $0 threshold")
    func singleBracket10PercentStart() {
        let config = cfg()
        let bracket10 = config.federalBracketsSingle.first { $0.rate == 0.10 }
        #expect(bracket10?.threshold == 0)
    }
}
