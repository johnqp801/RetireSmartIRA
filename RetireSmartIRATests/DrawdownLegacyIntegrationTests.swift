//
//  DrawdownLegacyIntegrationTests.swift
//  RetireSmartIRATests
//
//  Task 14 / decision (b): the Legacy estate projection must reflect the
//  drawdown trajectory when drawdown is active, and stay byte-for-byte
//  unchanged when drawdown is inactive (spending target 0 / rate 0).
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Drawdown → Legacy Estate Integration", .serialized)
@MainActor struct DrawdownLegacyIntegrationTests {

    /// Single-owner DataManager pinned to TY2026 with a Traditional balance and
    /// Legacy planning enabled. No persistence side effects.
    private func makeDM() -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .single
        dm.selectedState = .california
        // Born 1964 → age 62 in 2026, well below RMD age. Gives a long pre-RMD
        // bridge so a voluntary drawdown clearly diverges from the grow-only path.
        var c = DateComponents(); c.year = 1964; c.month = 1; c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!
        dm.incomeSources = []
        dm.deductionItems = []
        dm.enableSpouse = false
        dm.enableLegacyPlanning = true
        dm.legacyHeirType = "adultChild"
        dm.primaryGrowthRate = 5.0
        dm.iraAccounts = [
            IRAAccount(name: "Trad IRA", accountType: .traditionalIRA, balance: 1_500_000, owner: .primary)
        ]
        // Inactive drawdown defaults (will be overridden in the active case).
        dm.drawdownMode = .withdrawalRate
        dm.drawdownRatePercent = 0.0
        dm.drawdownSpendingTarget = 0.0
        dm.drawdownInflationPercent = 0.0
        return dm
    }

    // MARK: - Active drawdown lowers the projected estate

    @Test("Active drawdown lowers the no-action Traditional inheritance")
    func activeDrawdownLowersInheritance() {
        // Baseline: drawdown inactive (rate 0, target 0).
        let inactive = makeDM()
        let estateNoDrawdown = inactive.legacyNoActionTraditionalAtDeath
        #expect(estateNoDrawdown > 0)

        // Active: substantial 5% annual withdrawal rate over the horizon.
        let active = makeDM()
        active.drawdownMode = .withdrawalRate
        active.drawdownRatePercent = 5.0
        let estateWithDrawdown = active.legacyNoActionTraditionalAtDeath

        #expect(estateWithDrawdown < estateNoDrawdown,
                "Active drawdown should reduce the projected Traditional estate (\(estateWithDrawdown) !< \(estateNoDrawdown))")
        #expect(estateWithDrawdown >= 0)
    }

    @Test("Active drawdown lowers the with-scenario Traditional inheritance")
    func activeDrawdownLowersScenarioInheritance() {
        let inactive = makeDM()
        let scenarioNoDrawdown = inactive.legacyWithScenarioTraditionalAtDeath

        let active = makeDM()
        active.drawdownMode = .withdrawalRate
        active.drawdownRatePercent = 5.0
        let scenarioWithDrawdown = active.legacyWithScenarioTraditionalAtDeath

        #expect(scenarioWithDrawdown < scenarioNoDrawdown,
                "Active drawdown should reduce the with-scenario Traditional estate")
    }

    @Test("Active drawdown lowers the heir's taxable drawdown total")
    func activeDrawdownLowersHeirDrawdown() {
        let inactive = makeDM()
        let heirNoDrawdown = inactive.legacyNoActionHeirTaxableDrawdown

        let active = makeDM()
        active.drawdownMode = .withdrawalRate
        active.drawdownRatePercent = 5.0
        let heirWithDrawdown = active.legacyNoActionHeirTaxableDrawdown

        #expect(heirWithDrawdown < heirNoDrawdown)
    }

    // MARK: - Inactive drawdown is a no-op (no regression)

    @Test("Inactive drawdown (rate 0 / target 0) leaves Legacy estate unchanged")
    func inactiveDrawdownIsNoOp() {
        // The drawdown-aware DM with rate 0 / target 0 must equal a DM whose
        // drawdown settings were never touched at all.
        let touched = makeDM()
        touched.drawdownMode = .withdrawalRate
        touched.drawdownRatePercent = 0.0
        touched.drawdownSpendingTarget = 0.0

        let pristine = DataManager(skipPersistence: true)
        pristine.currentYear = 2026
        pristine.filingStatus = .single
        pristine.selectedState = .california
        var c = DateComponents(); c.year = 1964; c.month = 1; c.day = 1
        pristine.birthDate = Calendar.current.date(from: c)!
        pristine.incomeSources = []
        pristine.deductionItems = []
        pristine.enableSpouse = false
        pristine.enableLegacyPlanning = true
        pristine.legacyHeirType = "adultChild"
        pristine.primaryGrowthRate = 5.0
        pristine.iraAccounts = [
            IRAAccount(name: "Trad IRA", accountType: .traditionalIRA, balance: 1_500_000, owner: .primary)
        ]

        #expect(touched.legacyNoActionTraditionalAtDeath == pristine.legacyNoActionTraditionalAtDeath)
        #expect(touched.legacyWithScenarioTraditionalAtDeath == pristine.legacyWithScenarioTraditionalAtDeath)
        #expect(touched.legacyNoActionHeirTaxableDrawdown == pristine.legacyNoActionHeirTaxableDrawdown)
    }

    @Test("Spending-gap mode fully covered by guaranteed income is inactive")
    func spendingGapNoVoluntaryWithdrawalIsNoOp() {
        // Spending target 0 in spendingGap mode → desired 0 every year → inactive.
        let gap = makeDM()
        gap.drawdownMode = .spendingGap
        gap.drawdownSpendingTarget = 0.0

        let rateZero = makeDM()
        rateZero.drawdownMode = .withdrawalRate
        rateZero.drawdownRatePercent = 0.0

        #expect(gap.legacyNoActionTraditionalAtDeath == rateZero.legacyNoActionTraditionalAtDeath)
        #expect(gap.legacyWithScenarioTraditionalAtDeath == rateZero.legacyWithScenarioTraditionalAtDeath)
        #expect(gap.legacyNoActionHeirTaxableDrawdown == rateZero.legacyNoActionHeirTaxableDrawdown)
    }
}
