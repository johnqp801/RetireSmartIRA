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
}
