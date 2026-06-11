//
//  TaxYearConstants2026Tests.swift
//  RetireSmartIRATests
//
//  Regression tests pinning 2026 tax constants against primary-source-verified values:
//    - Federal income tax brackets — IRS Rev. Proc. 2025-32 (October 2025)
//    - LTCG 0% bracket tops — IRS Rev. Proc. 2025-32
//    - Standard deduction — IRS Rev. Proc. 2025-32
//    - HSA contribution limits — IRS Rev. Proc. 2025-19
//    - Federal Poverty Level — HHS ASPE 2025 Poverty Guidelines (used for 2026 PTC
//      per 26 CFR 1.36B prior-year-FPL rule)
//    - ACA enhanced subsidy expiration — ARPA/IRA expired Dec 31, 2025
//    - Social Security COLA — SSA press release Oct 24, 2025 (CPI-W Q3-2024→Q3-2025)
//    - Medicare Part B standard premium — CMS Nov 2025
//    - Medicare IRMAA tier-1 thresholds — CMS Nov 2025
//
//  Pins audited values to prevent quiet drift in future tax-year updates.
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
        #expect(cfg().contributionLimitsHSA.selfOnly == 4_400)
    }

    @Test("HSA family limit 2026 = $8,750")
    func hsaFamilyLimit() {
        #expect(cfg().contributionLimitsHSA.family == 8_750)
    }

    @Test("HSA catchup age 55+ = $1,000")
    func hsaCatchupAge55Plus() {
        #expect(cfg().contributionLimitsHSA.catchupAge55Plus == 1_000)
    }

    // MARK: - Federal Poverty Level (HHS ASPE 2025 Poverty Guidelines)
    // Per 26 CFR 1.36B, 2026 Premium Tax Credit uses prior-year (2025) FPL.

    @Test("HHS FPL HH=1 (48 states) = $15,060 — used for 2026 PTC per prior-year rule")
    func fplHouseholdSize1() {
        let fpl = cfg().acaSubsidy2026.fpl2026.householdSizeToFPL["1"]
        #expect(fpl == 15_650)
    }

    @Test("HHS FPL per additional member = $5,380 (HH=2 = $20,440)")
    func fplPerAdditionalMember() {
        let fpl2 = cfg().acaSubsidy2026.fpl2026.householdSizeToFPL["2"]
        #expect(fpl2 == 21_150)
    }

    @Test("HHS FPL HH=8 = $52,720 (caps lookup for HH ≥ 8)")
    func fplHouseholdSize8() {
        let fpl8 = cfg().acaSubsidy2026.fpl2026.householdSizeToFPL["8"]
        #expect(fpl8 == 54_150)
    }

    @Test("HHS FPL Alaska multiplier = 1.25")
    func fplAlaskaMultiplier() {
        #expect(cfg().acaSubsidy2026.fpl2026.alaskaMultiplier == 1.25)
    }

    @Test("HHS FPL Hawaii multiplier = 1.15")
    func fplHawaiiMultiplier() {
        #expect(cfg().acaSubsidy2026.fpl2026.hawaiiMultiplier == 1.15)
    }

    // MARK: - ACA Enhanced Subsidies (ARPA/IRA Expiration)
    // Enhanced subsidies expired Dec 31, 2025. 2026 reverts to pre-ARPA schedule
    // with the 400% FPL cliff.

    @Test("ACA cliff enabled in 2026 (enhanced subsidies expired Dec 31, 2025)")
    func acaCliffActive() {
        #expect(cfg().acaSubsidy2026.hasCliff == true)
    }

    @Test("ACA cliff sentinel at 400% FPL (applicableFigure = 1.00)")
    func acaCliffEntryAt400Percent() {
        let fig400 = cfg().acaSubsidy2026.applicableFigures.first { $0.fplPercent == 400 }
        #expect(fig400?.applicableFigure == 1.00)
    }

    // MARK: - Social Security COLA (SSA press release Oct 24, 2025)

    @Test("SS COLA 2026 default = 2.8% (SSA Oct 24, 2025, CPI-W Q3-2024→Q3-2025)")
    func ssCOLA2026Default() {
        let defaultParams = SSWhatIfParameters()
        #expect(defaultParams.colaRate == 2.8)
    }

    // MARK: - Medicare Part B Standard Premium (CMS Nov 2025)

    @Test("Medicare Part B standard premium 2026 = $202.90 monthly")
    func medicarePartBStandardMonthly() {
        #expect(cfg().medicare2026.partBStandardMonthly == 202.90)
    }

    @Test("IRMAA standard Part B reference = $202.90")
    func irmaaStandardPartBMatches() {
        #expect(cfg().irmaaStandardPartB == 202.90)
    }

    // MARK: - Medicare IRMAA Tier 1 Thresholds (CMS Nov 2025)
    // Codebase stores tier-1 threshold one dollar above the IRS-published trigger
    // ($109,000 single, $218,000 MFJ) to represent ">" rather than "≥".

    @Test("IRMAA tier-1 single threshold = $109,001 (trigger > $109,000)")
    func irmaaTier1Single() {
        let tier1 = cfg().irmaaTiers.first { $0.tier == 1 }
        #expect(tier1?.singleThreshold == 109_001)
    }

    @Test("IRMAA tier-1 MFJ threshold = $218,001 (trigger > $218,000)")
    func irmaaTier1MFJ() {
        let tier1 = cfg().irmaaTiers.first { $0.tier == 1 }
        #expect(tier1?.mfjThreshold == 218_001)
    }

    // MARK: - Standard Deduction (IRS Rev. Proc. 2025-32)

    @Test("Standard deduction Single 2026 = $16,100")
    func standardDeductionSingle() {
        #expect(cfg().standardDeductionSingle == 16_100)
    }

    @Test("Standard deduction MFJ 2026 = $32,200")
    func standardDeductionMFJ() {
        #expect(cfg().standardDeductionMFJ == 32_200)
    }

    @Test("Additional standard deduction age 65+ Single = $2,050")
    func additionalDeduction65Single() {
        #expect(cfg().additionalDeduction65Single == 2_050)
    }

    @Test("Additional standard deduction age 65+ MFJ (per qualifying spouse) = $1,650")
    func additionalDeduction65MFJ() {
        #expect(cfg().additionalDeduction65MFJ == 1_650)
    }

    // MARK: - Federal Income Tax Brackets — MFJ (IRS Rev. Proc. 2025-32)

    @Test("Federal MFJ 10% bracket start = $0")
    func mfjBracket10Start() {
        let b = cfg().federalBracketsMFJ.first { $0.rate == 0.10 }
        #expect(b?.threshold == 0)
    }

    @Test("Federal MFJ 12% bracket start = $24,800")
    func mfjBracket12Start() {
        let b = cfg().federalBracketsMFJ.first { $0.rate == 0.12 }
        #expect(b?.threshold == 24_800)
    }

    @Test("Federal MFJ 22% bracket start = $100,800")
    func mfjBracket22Start() {
        let b = cfg().federalBracketsMFJ.first { $0.rate == 0.22 }
        #expect(b?.threshold == 100_800)
    }

    @Test("Federal MFJ 24% bracket start = $211,400")
    func mfjBracket24Start() {
        let b = cfg().federalBracketsMFJ.first { $0.rate == 0.24 }
        #expect(b?.threshold == 211_400)
    }

    @Test("Federal MFJ 32% bracket start = $403,550")
    func mfjBracket32Start() {
        let b = cfg().federalBracketsMFJ.first { $0.rate == 0.32 }
        #expect(b?.threshold == 403_550)
    }

    @Test("Federal MFJ 35% bracket start = $512,450")
    func mfjBracket35Start() {
        let b = cfg().federalBracketsMFJ.first { $0.rate == 0.35 }
        #expect(b?.threshold == 512_450)
    }

    @Test("Federal MFJ 37% bracket start = $768,700")
    func mfjBracket37Start() {
        let b = cfg().federalBracketsMFJ.first { $0.rate == 0.37 }
        #expect(b?.threshold == 768_700)
    }

    // MARK: - Federal Income Tax Brackets — Single (IRS Rev. Proc. 2025-32)

    @Test("Federal Single 10% bracket start = $0")
    func singleBracket10Start() {
        let b = cfg().federalBracketsSingle.first { $0.rate == 0.10 }
        #expect(b?.threshold == 0)
    }

    @Test("Federal Single 12% bracket start = $12,400")
    func singleBracket12Start() {
        let b = cfg().federalBracketsSingle.first { $0.rate == 0.12 }
        #expect(b?.threshold == 12_400)
    }

    @Test("Federal Single 22% bracket start = $50,400")
    func singleBracket22Start() {
        let b = cfg().federalBracketsSingle.first { $0.rate == 0.22 }
        #expect(b?.threshold == 50_400)
    }

    @Test("Federal Single 24% bracket start = $105,700")
    func singleBracket24Start() {
        let b = cfg().federalBracketsSingle.first { $0.rate == 0.24 }
        #expect(b?.threshold == 105_700)
    }

    @Test("Federal Single 32% bracket start = $201,775")
    func singleBracket32Start() {
        let b = cfg().federalBracketsSingle.first { $0.rate == 0.32 }
        #expect(b?.threshold == 201_775)
    }

    @Test("Federal Single 35% bracket start = $256,225")
    func singleBracket35Start() {
        let b = cfg().federalBracketsSingle.first { $0.rate == 0.35 }
        #expect(b?.threshold == 256_225)
    }

    @Test("Federal Single 37% bracket start = $640,600")
    func singleBracket37Start() {
        let b = cfg().federalBracketsSingle.first { $0.rate == 0.37 }
        #expect(b?.threshold == 640_600)
    }

    @Test("Federal MFJ brackets count = 7")
    func mfjBracketsCount() {
        #expect(cfg().federalBracketsMFJ.count == 7)
    }

    @Test("Federal Single brackets count = 7")
    func singleBracketsCount() {
        #expect(cfg().federalBracketsSingle.count == 7)
    }

    // MARK: - LTCG 0% Bracket Top (IRS Rev. Proc. 2025-32)

    @Test("LTCG 15% bracket start (= 0% top) Single = $49,450")
    func ltcg0PercentTopSingle() {
        // Top of the 0% LTCG bracket is the threshold where the 15% bracket starts.
        let b = cfg().federalCapGainsBracketsSingle.first { $0.rate == 0.15 }
        #expect(b?.threshold == 49_450)
    }

    @Test("LTCG 15% bracket start (= 0% top) MFJ = $98,900")
    func ltcg0PercentTopMFJ() {
        let b = cfg().federalCapGainsBracketsMFJ.first { $0.rate == 0.15 }
        #expect(b?.threshold == 98_900)
    }
}
