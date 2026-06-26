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
}
