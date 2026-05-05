//
//  MultiYearStrategyManagerTests.swift
//  RetireSmartIRATests
//

import XCTest
import Combine
@testable import RetireSmartIRA

@MainActor
final class MultiYearStrategyManagerTests: XCTestCase {

    func testRecompute_SetsIsComputingImmediately() {
        let mgr = MultiYearStrategyManager()
        XCTAssertFalse(mgr.isComputing)

        mgr.recompute(reason: .appLaunch)

        XCTAssertTrue(mgr.isComputing,
            "isComputing must be true synchronously after recompute() — immediate visual signal")
    }

    func testRecompute_AppLaunchSetsDirtyFlag() {
        let mgr = MultiYearStrategyManager()
        XCTAssertFalse(mgr.needsOptimalRecompute)

        mgr.recompute(reason: .appLaunch)

        XCTAssertTrue(mgr.needsOptimalRecompute,
            ".appLaunch reason must set needsOptimalRecompute")
    }

    func testRecompute_AssumptionsChangedSetsDirtyFlag() {
        let mgr = MultiYearStrategyManager()
        mgr.recompute(reason: .assumptionsChanged)
        XCTAssertTrue(mgr.needsOptimalRecompute)
    }

    func testRecompute_OverridesChangedDoesNotSetDirtyFlag() {
        let mgr = MultiYearStrategyManager()
        mgr.recompute(reason: .overridesChanged)
        XCTAssertFalse(mgr.needsOptimalRecompute,
            ".overridesChanged alone must NOT set the flag — only assumption changes do")
    }

    func testRecompute_DirtyFlagSurvivesCancellation() async throws {
        let mgr = MultiYearStrategyManager()

        // 1. Trigger an assumption-change recompute. Sets dirty flag.
        mgr.recompute(reason: .assumptionsChanged)
        XCTAssertTrue(mgr.needsOptimalRecompute)

        // 2. Before the 500ms debounce elapses, trigger an overrides-changed recompute.
        //    This cancels the prior task and starts a new one. The flag must NOT clear.
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms, well within debounce
        mgr.recompute(reason: .overridesChanged)

        XCTAssertTrue(mgr.needsOptimalRecompute,
            "Flag MUST survive cancellation: cancelled task lost an opportunity to clear it, but next task must still see it set")
    }

    func testRecompute_RapidCallsCancelPrevious() async throws {
        let mgr = MultiYearStrategyManager()

        // Three rapid calls within the debounce window.
        mgr.recompute(reason: .appLaunch)
        try await Task.sleep(nanoseconds: 50_000_000)
        mgr.recompute(reason: .appLaunch)
        try await Task.sleep(nanoseconds: 50_000_000)
        mgr.recompute(reason: .appLaunch)

        // Wait past debounce + a generous compute budget. Without an attached
        // DataManager, performCompute exits early with isComputing = false.
        try await Task.sleep(nanoseconds: 800_000_000)

        XCTAssertFalse(mgr.isComputing,
            "After debounce window, only the latest task survives; manager not attached so it bails fast and clears isComputing")
    }

    func testDismissInsight_AddsToSet() {
        let mgr = MultiYearStrategyManager()
        XCTAssertTrue(mgr.assumptions.dismissedInsightKeys.isEmpty)

        mgr.dismissInsight("ss-nudge-67-23k")
        XCTAssertEqual(mgr.assumptions.dismissedInsightKeys, ["ss-nudge-67-23k"])

        mgr.dismissInsight("widow-stress-major")
        XCTAssertEqual(mgr.assumptions.dismissedInsightKeys, ["ss-nudge-67-23k", "widow-stress-major"])
    }

    func testRestoreDismissedInsights_ClearsSet() {
        let mgr = MultiYearStrategyManager()
        mgr.assumptions.dismissedInsightKeys = ["a", "b", "c"]

        mgr.restoreDismissedInsights()
        XCTAssertTrue(mgr.assumptions.dismissedInsightKeys.isEmpty)
    }

    func testMarkFirstOffPlanShown_FlipsFlag() {
        let mgr = MultiYearStrategyManager()
        XCTAssertFalse(mgr.firstOffPlanShown)

        mgr.markFirstOffPlanShown()
        XCTAssertTrue(mgr.firstOffPlanShown)
    }

    // MARK: - Cache invariant test (spec §5.2)

    /// Property test asserting engineOptimalResult.lifetimeTaxFromRecommendedPath
    /// stays constant under a sequence of Year 1 override changes when assumptions
    /// and static inputs are held constant. This is the foundational invariant the
    /// off-plan indicator depends on (per spec §5.2): engineOptimalResult must reflect
    /// the unconstrained engine choice, never the user's Year 1 override.
    ///
    /// This test became meaningful in Bundle C1 — the engine fix that wires
    /// year1PrimaryRothConversion as a pin in OptimizationEngine.optimize().
    func testCacheInvariant_OptimalUnaffectedByYear1Overrides() async throws {
        // Set up a trad-heavy scenario so the optimizer has significant Roth-conversion
        // work to do, mirroring testEngine_RespectsYear1RothConversionOverride in
        // MultiYearInputAdapterTests.swift. $1M trad balance guarantees the engine
        // produces non-trivial lifetime tax totals.
        let dm = DataManager(skipPersistence: true)
        dm.iraAccounts = [
            IRAAccount(name: "Primary Trad IRA", accountType: .traditionalIRA,
                       balance: 1_000_000, owner: .primary),
            IRAAccount(name: "Primary Roth IRA", accountType: .rothIRA,
                       balance: 100_000, owner: .primary),
        ]

        // Short horizon for test speed; consistent with OptimizationEngineTests conventions.
        var assumptions = MultiYearAssumptions()
        assumptions.horizonEndAge = 80
        assumptions.stressTestEnabled = false

        // Use dm.scenario directly to match production wiring (Phase 3 will
        // attach via dm.scenario, not a fresh ScenarioStateManager instance).
        let mgr = MultiYearStrategyManager(assumptions: assumptions)
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)

        // First compute — appLaunch sets needsOptimalRecompute, populates engineOptimalResult.
        mgr.recompute(reason: .appLaunch)
        try await waitUntilNotComputing(mgr, timeout: 5.0)
        XCTAssertNotNil(mgr.engineOptimalResult,
            "engineOptimalResult must populate after initial appLaunch compute")

        let initialOptimal = mgr.engineOptimalResult!.lifetimeTaxFromRecommendedPath
        XCTAssertGreaterThan(initialOptimal, 0,
            "Scenario with $1M trad balance must produce non-trivial lifetime tax — " +
            "if zero, the DataManager fixture is not configured correctly")

        // Property: under 5 different Year 1 Roth override values, engineOptimalResult
        // MUST remain unchanged. Only currentResult changes.
        let overrideSequence: [Double] = [10_000, 25_000, 47_500, 75_000, 0]
        for override in overrideSequence {
            dm.yourRothConversion = override
            mgr.recompute(reason: .overridesChanged)
            try await waitUntilNotComputing(mgr, timeout: 5.0)

            let currentOptimal = try XCTUnwrap(
                mgr.engineOptimalResult?.lifetimeTaxFromRecommendedPath,
                "engineOptimalResult must still be set after override change. Override = \(override)"
            )
            XCTAssertEqual(
                currentOptimal,
                initialOptimal,
                accuracy: 0.01,
                "engineOptimalResult MUST NOT change when only Year 1 overrides change. " +
                "Override = \(override). This is spec §5.2 invariant."
            )
        }
    }

    // MARK: - Combine subscription test (Task 1.12)

    /// Sanity-check that the Combine subscription wired in attach() propagates
    /// DataManager mutations to recompute(.overridesChanged). After the 50ms
    /// Combine debounce, isComputing must be true.
    func testCombineSubscription_FiresOnDataManagerChange() async throws {
        let dm = DataManager(skipPersistence: true)
        // In production, scenarioStateManager will be `dm.scenario`. Mirror that
        // here so the test catches any future regression where production wires
        // a separate instance (which would silently break observation).
        let mgr = MultiYearStrategyManager(assumptions: MultiYearAssumptions())
        mgr.attach(dataManager: dm, scenarioStateManager: dm.scenario)

        XCTAssertFalse(mgr.isComputing, "Initially idle")

        // Mutate DataManager — triggers objectWillChange → 50ms Combine debounce
        // → recompute(.overridesChanged) → isComputing = true synchronously.
        dm.yourRothConversion = 30_000

        // Wait 200ms — past the 50ms Combine debounce with safety margin for
        // RunLoop.main jitter on slow CI; well before the 500ms engine debounce.
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(mgr.isComputing,
            "DataManager mutation must propagate via Combine subscription within 100ms " +
            "to trigger recompute (which sets isComputing = true synchronously)")
    }

    // MARK: - Test helpers

    private func waitUntilNotComputing(
        _ mgr: MultiYearStrategyManager,
        timeout: TimeInterval
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while mgr.isComputing && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms poll
        }
        if mgr.isComputing {
            XCTFail("Manager still computing after \(timeout)s — " +
                    "debounce / engine compute did not complete")
        }
    }
}
