//
//  NJOtherExclusionAndExemptionsTests.swift
//  RetireSmartIRATests
//
//  Coverage for two NJ-1040 additions (v1.9):
//
//  (A) Worksheet D — Other Retirement Income Exclusion (NJSA 54A:6-15).
//      After the pension/IRA exclusion (line 28a), the UNUSED portion of the
//      chart maximum (chartMax − pension exclusion) shelters OTHER eligible
//      income (interest/dividends/cap-gains/refunds/other), but ONLY when:
//        • taxpayer is 62+ (regularExemptionMinAge), and
//        • total NJ gross income ≤ $150,000, and
//        • earned income (NJ lines 15+18+21+22 ≈ `.consulting`) ≤ $3,000.
//      otherExclusion = min(unused, otherEligibleIncome).
//
//  (B) NJ personal exemptions: $1,000 regular per filer (+ spouse if MFJ),
//      plus an additional $1,000 per filer/spouse age 65+. Subtracted from NJ
//      taxable income. (NJ has no standard deduction.)
//
//  The pension exclusion itself is min(pension × tier%, chartMax) — see also
//  the phaseout-edge case below, which exercises the cap-after-percent fix.
//
//  These tests drive the engine through `calculateStateTax` (which applies the
//  exclusions but NOT the personal exemptions — those are applied in the
//  DataManager caller path) and through the dedicated `njPersonalExemptions`
//  accessor for (B).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("NJ Worksheet D other-income exclusion + personal exemptions")
struct NJOtherExclusionAndExemptionsTests {

    /// Drive NJ state tax with explicit pension + a single "other" income source
    /// (and optional earned income), age 65 (1961 birth), 2026.
    private func njTax(
        total totalIncome: Double,
        pension: Double,
        otherType: IncomeType,
        other: Double,
        earned: Double = 0,
        filingStatus: FilingStatus
    ) -> Double {
        var sources: [IncomeSource] = []
        if pension > 0 { sources.append(IncomeSource(name: "Pension", type: .pension, annualAmount: pension)) }
        if other > 0 { sources.append(IncomeSource(name: "Other", type: otherType, annualAmount: other)) }
        if earned > 0 { sources.append(IncomeSource(name: "Wages", type: .consulting, annualAmount: earned)) }
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

    // MARK: - 1. ≤ $100K: dividends fully sheltered

    @Test("MFJ, $30K pension + $60K dividends, total $90K → all sheltered → $0")
    func underHundredKDividendsFullySheltered() {
        // 100% tier, chartMax $100K. Pension excl = $30K. Unused $70K ≥ $60K div.
        // Taxable = $90K − $30K − $60K = $0. NJ tax = $0.
        let tax = njTax(total: 90_000, pension: 30_000, otherType: .dividends, other: 60_000,
                        filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 0) < 2, "Expected $0 (dividends fully sheltered). Got \(tax)")
    }

    // MARK: - 2. Band case (25% tier), partial shelter

    @Test("MFJ, $30K pension + $100K dividends, total $130K → taxable $97,500")
    func bandCasePartialShelter() {
        // 25% tier, chartMax = 25% × $130K = $32,500. Pension excl = min($30K×0.25, $32,500) = $7,500.
        // Unused = $25,000 → shelters $25K of dividends. Taxable = $130K − $7,500 − $25,000 = $97,500.
        // NJ MFJ tax on $97,500 = $2,611.88.
        let tax = njTax(total: 130_000, pension: 30_000, otherType: .dividends, other: 100_000,
                        filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 2_611.88) < 2, "Expected ≈$2,611.88 (taxable $97,500). Got \(tax)")
    }

    // MARK: - 3. Earned-income gate FAILS

    @Test("MFJ, $30K pension + $90K dividends + $10K wages, total $130K → no Worksheet D")
    func earnedIncomeGateBlocksOtherExclusion() {
        // Earned $10K > $3,000 → NO other exclusion. Only pension excl applies.
        // 25% tier, chartMax $32,500. Pension excl = $7,500.
        // Taxable = $130K − $7,500 = $122,500. NJ MFJ tax = $3,993.12.
        let tax = njTax(total: 130_000, pension: 30_000, otherType: .dividends, other: 90_000,
                        earned: 10_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 3_993.12) < 2, "Expected ≈$3,993.12 (earned-income gate blocks Worksheet D). Got \(tax)")
    }

    // MARK: - 4. Updated $150K worked example

    @Test("MFJ, $50K dividends + $100K pension, total $150K → taxable $112,500")
    func oneFiftyKWorkedExample() {
        // 25% tier, chartMax = 25% × $150K = $37,500. Pension excl = $25,000.
        // Unused = $12,500 → shelters $12,500 of dividends. Taxable = $112,500.
        // NJ MFJ tax = $3,440.63.
        let tax = njTax(total: 150_000, pension: 100_000, otherType: .dividends, other: 50_000,
                        filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 3_440.63) < 2, "Expected ≈$3,440.63 (taxable $112,500). Got \(tax)")
    }

    // MARK: - 5. Phaseout edge fix (cap AFTER percent)

    @Test("MFJ, pension $120K, total $125K → exclusion $60,000 (cap-after-percent fix)")
    func phaseoutEdgeCapAfterPercent() {
        // 50% band. exclusion = min($120K × 0.5, 50% × $125K) = min($60K, $62.5K) = $60,000.
        // (Old cap-before-percent formula gave min($120K, $100K) × 0.5 = $50,000.)
        // The remaining $5K is earned income (>$3K) so Worksheet D is gated off.
        // Taxable = $125K − $60K = $65,000. NJ MFJ tax = $1,172.50.
        let tax = njTax(total: 125_000, pension: 120_000, otherType: .dividends, other: 0,
                        earned: 5_000, filingStatus: .marriedFilingJointly)
        #expect(abs(tax - 1_172.50) < 2, "Expected ≈$1,172.50 (exclusion $60K, not $50K). Got \(tax)")
    }

    // MARK: - 6. Personal exemptions

    @Test("NJ personal exemptions: MFJ 65+ → $4,000")
    func personalExemptionsMFJSenior() {
        let amt = TaxCalculationEngine.njPersonalExemptions(
            filingStatus: .marriedFilingJointly, enableSpouse: true, primaryAge: 65, spouseAge: 66)
        #expect(amt == 4_000, "Expected $4,000 (regular $2K + senior $2K). Got \(amt)")
    }

    @Test("NJ personal exemptions: single 65+ → $2,000")
    func personalExemptionsSingleSenior() {
        let amt = TaxCalculationEngine.njPersonalExemptions(
            filingStatus: .single, enableSpouse: false, primaryAge: 67, spouseAge: 0)
        #expect(amt == 2_000, "Expected $2,000 (regular $1K + senior $1K). Got \(amt)")
    }

    @Test("NJ personal exemptions: single under 65 → $1,000")
    func personalExemptionsSingleUnder65() {
        let amt = TaxCalculationEngine.njPersonalExemptions(
            filingStatus: .single, enableSpouse: false, primaryAge: 60, spouseAge: 0)
        #expect(amt == 1_000, "Expected $1,000 (regular only). Got \(amt)")
    }

    @Test("NJ personal exemptions: MFJ both under 65 → $2,000")
    func personalExemptionsMFJUnder65() {
        let amt = TaxCalculationEngine.njPersonalExemptions(
            filingStatus: .marriedFilingJointly, enableSpouse: true, primaryAge: 60, spouseAge: 61)
        #expect(amt == 2_000, "Expected $2,000 (two regular, no senior). Got \(amt)")
    }
}
