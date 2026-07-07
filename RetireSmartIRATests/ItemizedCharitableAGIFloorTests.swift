//
//  ItemizedCharitableAGIFloorTests.swift
//  RetireSmartIRATests
//
//  Verifies the OBBBA 0.5%-of-AGI floor on ITEMIZED charitable contributions
//  (IRC §170(b)(1), tax years beginning after 2025). For itemizers, only the
//  portion of charitable gifts exceeding 0.5% of the contribution base (AGI)
//  is deductible. This is a FEDERAL provision applied to the federal itemized
//  total; it does not change AGI. The separate non-itemizer §170(p) cash
//  deduction is NOT subject to this floor.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("OBBBA 0.5% AGI Floor on Itemized Charitable", .serialized)
@MainActor
struct ItemizedCharitableAGIFloorTests {

    private func makeDM(year: Int = 2026, filing: FilingStatus = .single) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = year
        dm.filingStatus = filing
        dm.selectedState = .florida // no state income tax → deterministic AGI
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 200_000)
        ]
        return dm
    }

    @Test("Floor equals 0.5% of AGI; charitable above it deducts the excess")
    func floorDisallowsBelowHalfPercent() {
        let dm = makeDM()
        dm.cashDonationAmount = 10_000
        dm.deductionOverride = .itemized
        // AGI ~ $200k → floor $1,000; deductible charitable = $10,000 - $1,000 = $9,000
        #expect(abs(dm.charitableAGIFloor - 0.005 * dm.federalAGI.value) < 0.01)
        #expect(abs(dm.deductibleCharitableDeductions - 9_000) < 1)
    }

    @Test("Charitable entirely below the floor is fully disallowed")
    func fullyBelowFloorDisallowed() {
        let dm = makeDM()
        dm.cashDonationAmount = 500 // floor ~$1,000 > $500
        dm.deductionOverride = .itemized
        #expect(dm.deductibleCharitableDeductions == 0)
    }

    @Test("Floor reduces the federal itemized total by the disallowed amount")
    func floorReducesItemizedTotal() {
        let dm = makeDM()
        dm.cashDonationAmount = 10_000
        dm.deductionItems = [
            DeductionItem(name: "Mortgage", type: .mortgageInterest, annualAmount: 20_000)
        ]
        dm.deductionOverride = .itemized
        let expected = dm.baseItemizedDeductions + 9_000 + dm.seniorBonusDeductionAmount
        #expect(abs(dm.totalItemizedDeductions - expected) < 1)
    }

    @Test("Pre-2026 (TY 2025): no floor, full charitable deductible")
    func noFloorBefore2026() {
        let dm = makeDM(year: 2025)
        dm.cashDonationAmount = 10_000
        dm.deductionOverride = .itemized
        #expect(dm.charitableAGIFloor == 0)
        #expect(abs(dm.deductibleCharitableDeductions - 10_000) < 1)
    }

    @Test("Floor scales with AGI (contribution base)")
    func floorScalesWithAGI() {
        let dm = makeDM()
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 400_000)
        ]
        dm.cashDonationAmount = 10_000
        dm.deductionOverride = .itemized
        // AGI ~ $400k → floor $2,000; deductible = $8,000
        #expect(abs(dm.charitableAGIFloor - 2_000) < 1)
        #expect(abs(dm.deductibleCharitableDeductions - 8_000) < 1)
    }
}
