//
//  DataManagerDrawdownTests.swift
//  RetireSmartIRATests
//
//  Task 8 integration: DataManager drawdown settings + drawdownProjection accessor.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("DataManager Drawdown Integration", .serialized)
@MainActor struct DataManagerDrawdownTests {

    /// Clean single-owner DataManager pinned to TY2026, no persistence side effects.
    private func makeDM(birthYear: Int = 1955) -> DataManager {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.filingStatus = .single
        dm.selectedState = .california
        var c = DateComponents(); c.year = birthYear; c.month = 1; c.day = 1
        dm.birthDate = Calendar.current.date(from: c)!
        dm.incomeSources = []
        dm.iraAccounts = []
        dm.deductionItems = []
        dm.enableSpouse = false
        return dm
    }

    private func isClose(_ a: Double, _ b: Double, tolerance: Double = 0.01) -> Bool {
        abs(a - b) < tolerance
    }

    // MARK: - Persistence round-trip

    @Test("Drawdown settings survive save/load round-trip")
    func persistenceRoundTrip() {
        let suiteName = "DataManagerDrawdownTests.persistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let dm = makeDM()
        dm.drawdownMode = .withdrawalRate
        dm.drawdownSpendingTarget = 72_500
        dm.drawdownRatePercent = 3.5
        dm.drawdownInflationPercent = 2.0

        PersistenceManager.saveAll(from: dm, defaults: defaults)

        let reloaded = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: reloaded, defaults: defaults)

        #expect(reloaded.drawdownMode == .withdrawalRate)
        #expect(reloaded.drawdownSpendingTarget == 72_500)
        #expect(reloaded.drawdownRatePercent == 3.5)
        #expect(reloaded.drawdownInflationPercent == 2.0)
    }

    @Test("drawdownMode .spendingGap survives save/load round-trip")
    func persistenceRoundTripSpendingGap() {
        let suiteName = "DataManagerDrawdownTests.persistence.spendingGap.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let dm = makeDM()
        dm.drawdownMode = .spendingGap

        PersistenceManager.saveAll(from: dm, defaults: defaults)

        let reloaded = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: reloaded, defaults: defaults)

        #expect(reloaded.drawdownMode == .spendingGap)
    }

    @Test("Defaults are spendingGap / 0 / 4.0 / 2.5")
    func defaults() {
        let dm = makeDM()
        #expect(dm.drawdownMode == .spendingGap)
        #expect(isClose(dm.drawdownSpendingTarget, 0))
        #expect(isClose(dm.drawdownRatePercent, 4.0))
        #expect(isClose(dm.drawdownInflationPercent, 2.5))
    }

    // MARK: - Known-value projection

    @Test("Single owner, $1M @ 4% withdrawal rate → year 0 withdrawal ≈ 40,000")
    func knownValueProjection() {
        let dm = makeDM()
        dm.iraAccounts = [
            IRAAccount(name: "Trad IRA", accountType: .traditionalIRA, balance: 1_000_000, owner: .primary)
        ]
        dm.primaryGrowthRate = 5.0
        dm.drawdownMode = .withdrawalRate
        dm.drawdownRatePercent = 4.0
        dm.drawdownInflationPercent = 0.0

        let projection = dm.drawdownProjection(horizonYears: 40)
        #expect(projection.years.count == 40)
        #expect(isClose(projection.years[0].householdWithdrawal, 40_000))
    }

    @Test("Per-owner balance folds in Traditional 401(k)")
    func balanceIncludes401k() {
        let dm = makeDM()
        dm.iraAccounts = [
            IRAAccount(name: "Trad IRA", accountType: .traditionalIRA, balance: 600_000, owner: .primary),
            IRAAccount(name: "401k", accountType: .traditional401k, balance: 400_000, owner: .primary)
        ]
        dm.primaryGrowthRate = 0.0
        dm.drawdownMode = .withdrawalRate
        dm.drawdownRatePercent = 4.0
        dm.drawdownInflationPercent = 0.0

        let projection = dm.drawdownProjection(horizonYears: 1)
        // 4% of the $1M aggregate (IRA + 401k)
        #expect(isClose(projection.years[0].householdWithdrawal, 40_000))
    }

    @Test("Horizon is capped at 40 years")
    func horizonCap() {
        let dm = makeDM()
        dm.iraAccounts = [
            IRAAccount(name: "Trad IRA", accountType: .traditionalIRA, balance: 500_000, owner: .primary)
        ]
        let projection = dm.drawdownProjection(horizonYears: 100)
        #expect(projection.years.count == 40)
    }
}
