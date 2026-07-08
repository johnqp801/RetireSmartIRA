//
//  ItemizedDeductionOverallLimitationTests.swift
//  RetireSmartIRATests
//
//  Verifies the OBBBA overall limitation on itemized deductions (IRC §68 as
//  amended, tax years beginning after 2025). For taxpayers whose taxable income
//  BEFORE the itemized deduction exceeds the 37%-bracket threshold, itemized
//  deductions are reduced by 2/37 of the lesser of (a) the itemized deductions
//  or (b) the excess of that income over the threshold. Net effect caps the
//  marginal benefit near 35 cents per dollar. This is a FEDERAL provision
//  applied AFTER all other floors/phaseouts (including the 0.5% charitable AGI
//  floor); it does not change AGI or state tax. Only bites in the 37% bracket
//  (~$640,600 single / $768,700 MFJ taxable income for 2026).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("OBBBA Overall Limitation on Itemized Deductions (2/37 rule)", .serialized)
@MainActor
struct ItemizedDeductionOverallLimitationTests {

    /// The statutory 2/37 reduction rate.
    private let rate = 2.0 / 37.0

    private func makeDM(year: Int = 2026,
                        filing: FilingStatus = .single,
                        income: Double = 900_000) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = year
        dm.filingStatus = filing
        dm.selectedState = .florida // no state income tax → deterministic AGI
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: income)
        ]
        return dm
    }

    @Test("37%-bracket itemizer: reduction = 2/37 of the itemized total when it is the lesser amount")
    func reducesByItemizedWhenItemizedIsLesser() {
        let dm = makeDM() // single, $900k income → excess over $640,600 = $259,400
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 30_000)
        ]
        dm.deductionOverride = .itemized
        // min($30,000 itemized, $259,400 excess) = $30,000 → reduction = $30,000 × 2/37
        #expect(abs(dm.itemizedOverallLimitationReduction - 30_000 * rate) < 0.5)
        #expect(abs(dm.effectiveDeductionAmount - (30_000 - 30_000 * rate)) < 0.5)
    }

    @Test("Reduction is capped by the excess over the threshold when the excess is the lesser amount")
    func reducesByExcessWhenExcessIsLesser() {
        // Income $660,000 single → excess over $640,600 = $19,400, smaller than $50,000 itemized.
        // Uses income BEFORE the itemized deduction: even though taxable income after the $50k
        // deduction ($610k) falls below the threshold, the reduction still applies to the excess.
        let dm = makeDM(income: 660_000)
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 50_000)
        ]
        dm.deductionOverride = .itemized
        #expect(abs(dm.itemizedOverallLimitationReduction - 19_400 * rate) < 0.5)
        #expect(abs(dm.effectiveDeductionAmount - (50_000 - 19_400 * rate)) < 0.5)
    }

    @Test("Below the 37% threshold: no reduction, full itemized deduction")
    func noReductionBelowThreshold() {
        let dm = makeDM(income: 300_000) // below $640,600
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 30_000)
        ]
        dm.deductionOverride = .itemized
        #expect(dm.itemizedOverallLimitationReduction == 0)
        #expect(abs(dm.effectiveDeductionAmount - 30_000) < 0.5)
    }

    @Test("Pre-2026 (TY 2025): no limitation even in the top bracket")
    func noReductionBefore2026() {
        let dm = makeDM(year: 2025)
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 30_000)
        ]
        dm.deductionOverride = .itemized
        #expect(dm.itemizedOverallLimitationReduction == 0)
        #expect(abs(dm.effectiveDeductionAmount - 30_000) < 0.5)
    }

    @Test("Standard-deduction path is never reduced")
    func noReductionOnStandardPath() {
        let dm = makeDM() // single, $900k
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 30_000)
        ]
        dm.deductionOverride = .standard
        #expect(dm.itemizedOverallLimitationReduction == 0)
        #expect(abs(dm.effectiveDeductionAmount - dm.standardDeductionAmount) < 0.5)
    }

    @Test("Uses the MFJ 37% threshold for joint filers")
    func usesMFJThreshold() {
        // $700,000 is above the single threshold ($640,600) but below the MFJ threshold
        // ($768,700), so a joint filer gets NO reduction where a single filer would.
        let dm = makeDM(filing: .marriedFilingJointly, income: 700_000)
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 30_000)
        ]
        dm.deductionOverride = .itemized
        #expect(dm.itemizedOverallLimitationReduction == 0)
        #expect(abs(dm.effectiveDeductionAmount - 30_000) < 0.5)
    }

    @Test("Applied AFTER the 0.5% charitable AGI floor (reduction base is the post-floor total)")
    func appliedAfterCharitableFloor() {
        let dm = makeDM() // single, $900k income, AGI ≈ $900k
        dm.cashDonationAmount = 50_000
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 20_000)
        ]
        dm.deductionOverride = .itemized
        // 0.5% floor: $900k × 0.005 = $4,500 → deductible charitable = $45,500.
        // Post-floor itemized total = $20,000 + $45,500 = $65,500 (senior bonus phased out).
        let expectedTotal = 65_500.0
        #expect(abs(dm.totalItemizedDeductions - expectedTotal) < 1)
        // Excess ($259,400) > total, so reduction = $65,500 × 2/37.
        #expect(abs(dm.itemizedOverallLimitationReduction - expectedTotal * rate) < 0.5)
        #expect(abs(dm.effectiveDeductionAmount - (expectedTotal - expectedTotal * rate)) < 0.5)
    }
}
