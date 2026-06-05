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

    @Test("Rapid recalcs within debounce interval count as one")
    func recalcDebounceCoalesces() {
        let t = Date(timeIntervalSince1970: 0)
        let m = makeManager(now: { t })
        // 20 recalcs at the same instant (a single slider drag) -> counts as 1
        for _ in 0..<20 { m.recordScenarioRecalc() }
        #expect(m.recalcCount == 1)
        #expect(m.pendingRequest == false)
    }

    @Test("6 spaced recalcs cross the recalc threshold")
    func spacedRecalcsSetPending() {
        var t = Date(timeIntervalSince1970: 0)
        let m = makeManager(now: { t })
        for _ in 0..<6 {
            m.recordScenarioRecalc()
            t = t.addingTimeInterval(2)   // > 1.0s apart
        }
        #expect(m.recalcCount == 6)
        #expect(m.pendingRequest == true)
    }
}
