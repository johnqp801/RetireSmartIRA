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

    @Test("High-value session: recordLaunch keeps eligibility, pending persists")
    func eligibleAfterLaunch() {
        let m = makeManager()
        for _ in 0..<4 { m.recordScenarioTaxSwitch() }   // pending = true
        #expect(m.pendingRequest == true)
        m.recordLaunch()                                 // simulate next launch
        #expect(m.shouldRequestReviewOnLaunch() == true)
    }

    @Test("recordLaunch resets per-session counters but not pending")
    func launchResetsCounters() {
        let m = makeManager()
        m.recordScenarioTaxSwitch()
        m.recordScenarioTaxSwitch()
        m.recordLaunch()
        #expect(m.switchCount == 0)
        #expect(m.recalcCount == 0)
    }

    @Test("markRequested gates further prompts for this version")
    func versionGate() {
        let m = makeManager(version: "1.8.6")
        for _ in 0..<4 { m.recordScenarioTaxSwitch() }
        #expect(m.shouldRequestReviewOnLaunch() == true)
        m.markRequested()
        #expect(m.pendingRequest == false)
        #expect(m.shouldRequestReviewOnLaunch() == false)
        // New high-value engagement does NOT re-arm for the same version
        for _ in 0..<4 { m.recordScenarioTaxSwitch() }
        #expect(m.pendingRequest == false)
    }
}
