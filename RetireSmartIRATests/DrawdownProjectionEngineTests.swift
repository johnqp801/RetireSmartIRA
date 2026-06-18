//
//  DrawdownProjectionEngineTests.swift
//  RetireSmartIRATests
//

import Testing
@testable import RetireSmartIRA

@Suite("DrawdownProjectionEngine")
struct DrawdownProjectionEngineTests {
    @Test("withdrawalRate mode, single owner, pre-RMD: balance compounds correctly over two years")
    func withdrawalRate_singleOwner_preRMD_compoundsCorrectly() {
        // 62yo, $1,000,000, 5% growth, 4% withdrawal, 0% inflation, RMD age 75
        let inputs = DrawdownInputs(mode: .withdrawalRate, annualSpendingTarget: 0,
                                    withdrawalRatePercent: 4, inflationRatePercent: 0, horizonYears: 2)
        let owner = OwnerState(currentAge: 62, rmdAge: 75, growthRatePercent: 5, startingBalance: 1_000_000)
        let sched = GuaranteedIncomeSchedule(annualByYearOffset: [0, 0])
        let p = DrawdownProjectionEngine.project(inputs: inputs, owners: [owner],
                                                 guaranteed: sched, startCalendarYear: 2026)
        // year 0: withdraw 4% of 1,000,000 = 40,000; (1,000,000-40,000)*1.05 = 1,008,000
        #expect(p.years[0].householdWithdrawal == 40_000)
        #expect(p.years[0].householdBalanceEnd == 1_008_000)
        // year 1: withdraw 4% of 1,008,000 = 40,320; (1,008,000-40,320)*1.05 = 1,016,064
        #expect(p.years[1].householdWithdrawal == 40_320)
        #expect(p.years[1].householdBalanceEnd == 1_016_064)
        #expect(p.years[0].rmdForcedPortion == 0)
        #expect(p.years[1].rmdForcedPortion == 0)
    }
}
