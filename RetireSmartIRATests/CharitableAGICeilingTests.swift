//
//  CharitableAGICeilingTests.swift
//  RetireSmartIRATests
//
//  Verifies the AGI ceilings on itemized charitable contributions:
//    - Long-term appreciated property (donated stock at FMV): 30% of AGI.
//    - Cash (and short-term / basis-valued stock): 60% of AGI.
//  These ceilings are longstanding (60% cash made permanent by OBBBA) and apply
//  every year, before the 0.5%-of-AGI floor. Excess above a ceiling is not
//  deductible in the current year (it would carry forward up to 5 years — not
//  modeled). Federal itemized path only; AGI and state are unaffected.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Charitable AGI Ceilings (30% LT stock / 60% cash)", .serialized)
@MainActor
struct CharitableAGICeilingTests {

    private func makeDM(agiPension: Double = 150_000) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .single
        dm.selectedState = .florida // no state income tax → AGI == pension
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: agiPension)
        ]
        dm.deductionOverride = .itemized
        return dm
    }

    /// Set the stock gift long-term (purchased > 1 year ago) or short-term.
    private func setStock(_ dm: DataManager, fmv: Double, basis: Double, longTerm: Bool) {
        dm.stockDonationEnabled = true
        dm.stockCurrentValue = fmv
        dm.stockPurchasePrice = basis
        let years = longTerm ? -3 : 0
        dm.stockPurchaseDate = Calendar.current.date(byAdding: .year, value: years, to: Date())!
    }

    @Test("Long-term stock above the 30% ceiling is capped at 30% of AGI")
    func ltStockCappedAt30Percent() {
        let dm = makeDM(agiPension: 150_000)
        setStock(dm, fmv: 60_000, basis: 10_000, longTerm: true)
        // 30% × $150k = $45,000 ceiling; $60k gift capped to $45k (pre-floor)
        #expect(abs(dm.ceilingLimitedCharitable - 45_000) < 1)
    }

    @Test("Long-term stock below the 30% ceiling deducts in full")
    func ltStockBelowCeiling() {
        let dm = makeDM(agiPension: 150_000)
        setStock(dm, fmv: 30_000, basis: 10_000, longTerm: true)
        #expect(abs(dm.ceilingLimitedCharitable - 30_000) < 1)
    }

    @Test("Cash above the 60% ceiling is capped at 60% of AGI")
    func cashCappedAt60Percent() {
        let dm = makeDM(agiPension: 100_000)
        dm.cashDonationAmount = 70_000
        // 60% × $100k = $60,000 ceiling
        #expect(abs(dm.ceilingLimitedCharitable - 60_000) < 1)
    }

    @Test("Cash below the 60% ceiling deducts in full")
    func cashBelowCeiling() {
        let dm = makeDM(agiPension: 100_000)
        dm.cashDonationAmount = 5_000
        #expect(abs(dm.ceilingLimitedCharitable - 5_000) < 1)
    }

    @Test("Short-term / basis-valued stock uses the 60% cash bucket at basis")
    func shortTermStockUses60PercentAtBasis() {
        let dm = makeDM(agiPension: 100_000)
        setStock(dm, fmv: 90_000, basis: 70_000, longTerm: false)
        // Non-LT stock deducts at basis ($70k) in the 60% bucket → capped at $60k
        #expect(abs(dm.ceilingLimitedCharitable - 60_000) < 1)
    }

    @Test("Ceiling then floor: deductible = ceiling-limited minus 0.5% AGI floor")
    func ceilingThenFloor() {
        let dm = makeDM(agiPension: 150_000)
        setStock(dm, fmv: 60_000, basis: 10_000, longTerm: true)
        // Ceiling-limited $45,000; floor 0.5% × $150k = $750 → deductible $44,250
        #expect(abs(dm.deductibleCharitableDeductions - 44_250) < 1)
    }

    @Test("Ceiling reduces the federal itemized total")
    func ceilingReducesItemizedTotal() {
        let dm = makeDM(agiPension: 150_000)
        setStock(dm, fmv: 60_000, basis: 10_000, longTerm: true)
        let expected = dm.baseItemizedDeductions + dm.deductibleCharitableDeductions + dm.seniorBonusDeductionAmount
        #expect(abs(dm.totalItemizedDeductions - expected) < 1)
        // And the total is strictly less than if the full $60k flowed through.
        #expect(dm.deductibleCharitableDeductions < 60_000)
    }
}
