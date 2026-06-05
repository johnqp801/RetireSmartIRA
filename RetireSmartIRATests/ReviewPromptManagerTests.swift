import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("ReviewPromptManager", .serialized)
struct ReviewPromptManagerTests {

    /// Fresh isolated defaults per test so persisted keys don't leak.
    private func makeManager(now: @escaping () -> Date = { Date(timeIntervalSince1970: 0) },
                             version: String = "1.8.6") -> ReviewPromptManager {
        let suite = "test.review.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return ReviewPromptManager(defaults: defaults, currentVersion: version, now: now)
    }

    @Test("4 Scenario<->Tax switches set pendingRequest")
    func switchThresholdSetsPending() {
        let m = makeManager()
        for _ in 0..<3 { m.recordScenarioTaxSwitch() }
        #expect(m.pendingRequest == false)
        m.recordScenarioTaxSwitch()           // 4th
        #expect(m.pendingRequest == true)
    }

    @Test("Below both thresholds leaves pendingRequest false")
    func belowThresholdStaysFalse() {
        let m = makeManager()
        m.recordScenarioTaxSwitch()
        m.recordScenarioTaxSwitch()
        #expect(m.pendingRequest == false)
    }
}
