//
//  DrawdownProjectionEngineTests.swift
//  RetireSmartIRATests
//

import Testing
@testable import RetireSmartIRA

@Suite("DrawdownProjectionEngine")
struct DrawdownProjectionEngineTests {
    @Test("RMD-only mode: no withdrawal before RMD age, exactly the RMD after")
    func rmdOnly_withdrawsOnlyTheRMD() {
        // Pre-RMD (62, rmdAge 75): no withdrawal, balance just grows.
        let preInputs = DrawdownInputs(mode: .rmdOnly, annualSpendingTarget: 0,
                                       withdrawalRatePercent: 0, inflationRatePercent: 0, horizonYears: 1)
        let young = OwnerState(currentAge: 62, rmdAge: 75, growthRatePercent: 5, startingBalance: 1_000_000)
        let pre = DrawdownProjectionEngine.project(inputs: preInputs, owners: [young],
                                                   guaranteed: .init(annualByYearOffset: [0]), startCalendarYear: 2026)
        #expect(pre.years[0].householdWithdrawal == 0)
        #expect(pre.years[0].householdBalanceEnd == 1_050_000) // 1,000,000 * 1.05

        // At RMD age 75, $2,460,000, divisor 24.6 => RMD 100,000; that's the whole withdrawal.
        let rmdInputs = DrawdownInputs(mode: .rmdOnly, annualSpendingTarget: 0,
                                       withdrawalRatePercent: 0, inflationRatePercent: 0, horizonYears: 1)
        let old = OwnerState(currentAge: 75, rmdAge: 75, growthRatePercent: 0, startingBalance: 2_460_000)
        let r = DrawdownProjectionEngine.project(inputs: rmdInputs, owners: [old],
                                                 guaranteed: .init(annualByYearOffset: [0]), startCalendarYear: 2026)
        #expect(r.years[0].householdWithdrawal == 100_000)
        #expect(r.years[0].plannedPortion == 0)
        #expect(r.years[0].rmdForcedPortion == 100_000)
    }

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

    @Test("RMD floor forces withdrawal above the planned rate")
    func rmdFloor_forcesAbovePlannedRate() {
        // 75yo (RMD age 75), $2,460,000, divisor 24.6 => RMD 100,000.
        // Mode C 1% => planned 24,600. actual = max(24,600, 100,000) = 100,000.
        let inputs = DrawdownInputs(mode: .withdrawalRate, annualSpendingTarget: 0,
                                    withdrawalRatePercent: 1, inflationRatePercent: 0, horizonYears: 1)
        let owner = OwnerState(currentAge: 75, rmdAge: 75, growthRatePercent: 0, startingBalance: 2_460_000)
        let p = DrawdownProjectionEngine.project(inputs: inputs, owners: [owner],
                                                 guaranteed: .init(annualByYearOffset: [0]), startCalendarYear: 2026)
        #expect(p.years[0].householdWithdrawal == 100_000)
        #expect(p.years[0].plannedPortion == 24_600)
        #expect(p.years[0].rmdForcedPortion == 75_400)
    }

    @Test("two owners, pro-rata split, independent RMD ages")
    func twoOwners_proRataSplit_independentRMDAge() {
        // Primary 75 (RMD), spouse 70 (no RMD yet). Balances 600k / 400k. 0% growth.
        // Mode C 5% of 1,000,000 = 50,000 desired. Shares 30,000 / 20,000.
        // Primary RMD at 75 on 600k = 600,000/24.6 ≈ 24,390 < 30,000 => actual 30,000.
        // Spouse no RMD => 20,000. Household 50,000.
        let inputs = DrawdownInputs(mode: .withdrawalRate, annualSpendingTarget: 0,
                                    withdrawalRatePercent: 5, inflationRatePercent: 0, horizonYears: 1)
        let primary = OwnerState(currentAge: 75, rmdAge: 75, growthRatePercent: 0, startingBalance: 600_000)
        let spouse  = OwnerState(currentAge: 70, rmdAge: 75, growthRatePercent: 0, startingBalance: 400_000)
        let p = DrawdownProjectionEngine.project(inputs: inputs, owners: [primary, spouse],
                                                 guaranteed: .init(annualByYearOffset: [0]), startCalendarYear: 2026)
        #expect(p.years[0].householdWithdrawal == 50_000)
        #expect(p.years[0].spouseAge == 70)
    }

    @Test("mode B gap shrinks when guaranteed income starts")
    func spendingGap_gapShrinksWhenGuaranteedIncomeStarts() {
        // Spend 100k. Guaranteed: 0,0 then 70k from year 2 (SS starts). 0% infl, 0% growth, pre-RMD.
        let inputs = DrawdownInputs(mode: .spendingGap, annualSpendingTarget: 100_000,
                                    withdrawalRatePercent: 0, inflationRatePercent: 0, horizonYears: 3)
        let owner = OwnerState(currentAge: 64, rmdAge: 75, growthRatePercent: 0, startingBalance: 5_000_000)
        let sched = GuaranteedIncomeSchedule(annualByYearOffset: [0, 0, 70_000])
        let p = DrawdownProjectionEngine.project(inputs: inputs, owners: [owner], guaranteed: sched, startCalendarYear: 2026)
        #expect(p.years[0].householdWithdrawal == 100_000)
        #expect(p.years[2].householdWithdrawal == 30_000)
        #expect(p.years[2].projectedIncome == 100_000) // 30k draw + 70k guaranteed
    }

    @Test("mode B inflates the spending target")
    func spendingGap_inflatesSpendingTarget() {
        let inputs = DrawdownInputs(mode: .spendingGap, annualSpendingTarget: 100_000,
                                    withdrawalRatePercent: 0, inflationRatePercent: 10, horizonYears: 2)
        let owner = OwnerState(currentAge: 64, rmdAge: 75, growthRatePercent: 0, startingBalance: 9_000_000)
        let p = DrawdownProjectionEngine.project(inputs: inputs, owners: [owner],
                                                 guaranteed: .init(annualByYearOffset: [0, 0]), startCalendarYear: 2026)
        #expect(abs(p.years[0].householdWithdrawal - 100_000) < 0.01)   // year 0: no inflation
        #expect(abs(p.years[1].householdWithdrawal - 110_000) < 0.01)   // year 1: 100k * 1.10 (float)
    }

    @Test("IRMAA tier-1 threshold inflates by year offset")
    func irmaaTier1ThresholdInflates() {
        #expect(abs(DrawdownProjectionEngine.inflatedIrmaaTier1(threshold: 218_000, inflationPercent: 10, yearOffset: 1) - 239_800) < 0.01)
    }
}
