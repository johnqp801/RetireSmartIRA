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

    @Test("editing a tracked upstream field triggers a recompute")
    func upstreamEditTriggersRecompute() async {
        let dm = DataManager(skipPersistence: true)
        let mgr = MultiYearStrategyManager()
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)
        let before = mgr.recomputeCount
        dm.filingStatus = (dm.filingStatus == .single) ? .marriedFilingJointly : .single
        try? await Task.sleep(nanoseconds: 250_000_000)  // > 50ms observation debounce
        #expect(mgr.recomputeCount > before)
    }

    @Test("editing the Year-1 Roth conversion triggers a recompute")
    func year1RothEditTriggersRecompute() async {
        let dm = DataManager(skipPersistence: true)
        let mgr = MultiYearStrategyManager()
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)
        let before = mgr.recomputeCount
        dm.yourRothConversion += 10_000
        try? await Task.sleep(nanoseconds: 250_000_000)
        #expect(mgr.recomputeCount > before)
    }
}
