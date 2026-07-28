//
//  InfeasibleYearModelTests.swift
//  RetireSmartIRATests
//
//  V2.3: a year whose tax cannot be funded is no longer presentable as a valid plan.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("YearRecommendation infeasibility flags")
struct InfeasibleYearModelTests {

    private func make(underfunded: Double?, infeasible: Bool, dependent: Bool) -> YearRecommendation {
        YearRecommendation(
            year: 2030, agi: 100_000, acaMagi: nil, irmaaMagi: nil,
            taxableIncome: 80_000,
            taxBreakdown: TaxBreakdown(federal: 10_000, state: 2_000, irmaa: 0,
                                       acaPremiumImpact: 0, niit: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: [],
            underfunded: underfunded,
            isInfeasible: infeasible,
            dependsOnInfeasibleYear: dependent
        )
    }

    @Test("Defaults keep existing call sites feasible")
    func defaultsAreFeasible() {
        let y = YearRecommendation(
            year: 2030, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: TaxBreakdown(federal: 0, state: 0, irmaa: 0,
                                       acaPremiumImpact: 0, niit: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: [])
        #expect(y.isInfeasible == false)
        #expect(y.dependsOnInfeasibleYear == false)
        #expect(y.isFullyFunded == true)
    }

    @Test("An infeasible year is not fully funded")
    func infeasibleIsNotFunded() {
        let y = make(underfunded: 8_420, infeasible: true, dependent: false)
        #expect(y.isFullyFunded == false)
        #expect(y.underfunded == 8_420)
    }

    @Test("A dependent year is not fully funded even with no shortfall of its own")
    func dependentIsNotFunded() {
        let y = make(underfunded: nil, infeasible: false, dependent: true)
        #expect(y.isFullyFunded == false)
    }

    @Test("Flags survive Codable round-trip")
    func roundTrips() throws {
        let y = make(underfunded: 500, infeasible: true, dependent: true)
        let back = try JSONDecoder().decode(
            YearRecommendation.self, from: try JSONEncoder().encode(y))
        #expect(back.isInfeasible == true)
        #expect(back.dependsOnInfeasibleYear == true)
        #expect(back.underfunded == 500)
    }
}
