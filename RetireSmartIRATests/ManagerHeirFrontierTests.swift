import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Manager heir frontier compute", .serialized)
@MainActor
struct ManagerHeirFrontierTests {
    @Test("computeHeirFrontier populates six points")
    func computesFrontier() async {
        let dm = DataManager(skipPersistence: true)
        let mgr = MultiYearStrategyManager()
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)
        mgr.computeHeirFrontier()
        let deadline = Date().addingTimeInterval(20)
        while mgr.heirFrontier == nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(mgr.heirFrontier?.points.count == 6)
        #expect(mgr.selectedHeirWeight == 0)
    }

    @Test("attach seeds assumptions from DataManager")
    func attachSeedsAssumptions() {
        let dm = DataManager(skipPersistence: true)
        dm.multiYearAssumptions.dismissedInsightKeys = ["ssNudge"]
        dm.multiYearAssumptions.currentTaxableBalance = 123_456
        let mgr = MultiYearStrategyManager()
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)
        #expect(mgr.assumptions.dismissedInsightKeys.contains("ssNudge"))
        #expect(mgr.assumptions.currentTaxableBalance == 123_456)
    }

    @Test("dismissInsight mirrors back to DataManager")
    func dismissMirrorsToDataManager() {
        let dm = DataManager(skipPersistence: true)
        let mgr = MultiYearStrategyManager()
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)
        mgr.dismissInsight("survivor")
        #expect(dm.multiYearAssumptions.dismissedInsightKeys.contains("survivor"))
    }
}
