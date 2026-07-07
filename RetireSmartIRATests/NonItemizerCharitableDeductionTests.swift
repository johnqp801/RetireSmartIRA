//
//  NonItemizerCharitableDeductionTests.swift
//  RetireSmartIRATests
//
//  Verifies the OBBBA §170(p) deduction for NON-itemizers: up to $1,000
//  (single/HoH/MFS) or $2,000 (MFJ) for CASH gifts to qualifying charities,
//  on top of the standard deduction, for tax years beginning after 2025.
//  It reduces federal taxable income but NOT AGI, applies to cash only
//  (stock gifts do not qualify), and only when the taxpayer takes the
//  standard deduction (if they itemize, the cash already flows through the
//  itemized total).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("OBBBA Non-Itemizer Cash Charitable Deduction (§170(p))", .serialized)
@MainActor
struct NonItemizerCharitableDeductionTests {

    private func makeDM(year: Int = 2026, filing: FilingStatus = .single) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = year
        dm.filingStatus = filing
        dm.selectedState = .florida // no state income tax → deterministic
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 50_000)
        ]
        return dm
    }

    @Test("Single non-itemizer: $1,500 cash gift is capped at $1,000")
    func singleCappedAt1000() {
        let dm = makeDM()
        dm.deductionOverride = .standard
        dm.cashDonationAmount = 1_500
        #expect(abs(dm.nonItemizerCharitableDeduction - 1_000) < 0.01)
    }

    @Test("Single non-itemizer: $600 cash gift is deducted in full")
    func singleUnderCap() {
        let dm = makeDM()
        dm.deductionOverride = .standard
        dm.cashDonationAmount = 600
        #expect(abs(dm.nonItemizerCharitableDeduction - 600) < 0.01)
    }

    @Test("MFJ non-itemizer: $2,500 cash gift is capped at $2,000")
    func mfjCappedAt2000() {
        let dm = makeDM(filing: .marriedFilingJointly)
        dm.enableSpouse = true
        dm.deductionOverride = .standard
        dm.cashDonationAmount = 2_500
        #expect(abs(dm.nonItemizerCharitableDeduction - 2_000) < 0.01)
    }

    @Test("Itemizer gets no separate non-itemizer deduction (cash already itemized)")
    func zeroWhenItemizing() {
        let dm = makeDM()
        dm.deductionOverride = .itemized
        dm.cashDonationAmount = 1_500
        #expect(dm.nonItemizerCharitableDeduction == 0)
    }

    @Test("Stock-only donation does not qualify (cash-only rule)")
    func zeroForStockOnly() {
        let dm = makeDM()
        dm.deductionOverride = .standard
        dm.cashDonationAmount = 0
        dm.stockDonationEnabled = true
        dm.stockPurchasePrice = 4_000
        dm.stockCurrentValue = 10_000
        // scenarioCharitableDeductions (cash + stock) is now > 0; a naive impl that
        // summed it would wrongly yield $1,000. The correct rule counts cash only.
        #expect(dm.scenarioCharitableDeductions > 0)
        #expect(dm.nonItemizerCharitableDeduction == 0)
    }

    @Test("Pre-2026 (TY 2025) → zero (provision not yet effective)")
    func zeroBefore2026() {
        let dm = makeDM(year: 2025)
        dm.deductionOverride = .standard
        dm.cashDonationAmount = 1_500
        #expect(dm.nonItemizerCharitableDeduction == 0)
    }

    @Test("Reduces federal taxable income by the deducted amount, but leaves AGI unchanged")
    func reducesTaxableIncomeNotAGI() {
        let dm = makeDM()
        dm.deductionOverride = .standard

        dm.cashDonationAmount = 0
        let agiBefore = dm.federalAGI.value
        let taxableBefore = dm.scenarioTaxableIncome

        dm.cashDonationAmount = 1_000
        let agiAfter = dm.federalAGI.value
        let taxableAfter = dm.scenarioTaxableIncome

        #expect(abs(agiAfter - agiBefore) < 0.01,
                "AGI must be unchanged by a below-the-line charitable deduction")
        #expect(abs((taxableBefore - taxableAfter) - 1_000) < 0.01,
                "Taxable income must drop by the deducted amount: before=\(taxableBefore) after=\(taxableAfter)")
    }
}
