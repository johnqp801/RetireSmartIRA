import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Persist MultiYearAssumptions", .serialized)
@MainActor
struct PersistMultiYearAssumptionsTests {

    private func ephemeralSuite() -> UserDefaults {
        UserDefaults(suiteName: "test-mya-\(UUID().uuidString)")!
    }

    @Test("assumptions round-trip through PersistenceManager")
    func roundTrips() {
        let suite = ephemeralSuite()
        let dm = DataManager(skipPersistence: true)
        dm.multiYearAssumptions.dismissedInsightKeys = ["survivor", "ssNudge"]
        dm.multiYearAssumptions.currentTaxableBalance = 250_000
        dm.multiYearAssumptions.terminalLiquidationTaxRate = 0.30
        PersistenceManager.saveAll(from: dm, defaults: suite)

        let reloaded = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: reloaded, defaults: suite)
        #expect(reloaded.multiYearAssumptions.dismissedInsightKeys == ["survivor", "ssNudge"])
        #expect(reloaded.multiYearAssumptions.currentTaxableBalance == 250_000)
        #expect(reloaded.multiYearAssumptions.terminalLiquidationTaxRate == 0.30)
    }

    @Test("missing key leaves default assumptions")
    func missingKeyDefaults() {
        let suite = ephemeralSuite()
        let dm = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: dm, defaults: suite)  // empty suite
        #expect(dm.multiYearAssumptions.dismissedInsightKeys.isEmpty)
        #expect(dm.multiYearAssumptions == MultiYearAssumptions())
    }
}
