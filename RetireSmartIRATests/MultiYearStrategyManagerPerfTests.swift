//
//  MultiYearStrategyManagerPerfTests.swift
//  RetireSmartIRATests

import XCTest
@testable import RetireSmartIRA

@MainActor
final class MultiYearStrategyManagerPerfTests: XCTestCase {

    private var dataManager: DataManager!
    private var scenarioStateManager: ScenarioStateManager!
    private var manager: MultiYearStrategyManager!

    override func setUp() async throws {
        dataManager = DataManager(skipPersistence: true)
        // Populate enough data so the engine has something to compute with.
        dataManager.socialSecurity.primarySSBenefit = SSBenefitEstimate(
            owner: .primary,
            benefitAt62: 2660,
            benefitAtFRA: 3800,
            benefitAt70: 4712,
            plannedClaimingAge: 70,
            plannedClaimingMonth: 0,
            isAlreadyClaiming: false,
            currentBenefit: 0
        )
        scenarioStateManager = ScenarioStateManager()
        manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)
    }

    func testColdStartLatency_completesWithinBudget() async throws {
        let start = Date()
        manager.recompute(reason: .appLaunch)
        try await waitForComputation(timeout: 5.0)
        let elapsedMs = Date().timeIntervalSince(start) * 1000
        // Wall-clock cold-start budget; loose to tolerate ~30% CI/machine-load variance —
        // this is a smoke check, not a micro-benchmark. Measured medians on this machine:
        // ~1.57s on both this branch and the pre-Track-1 (2.1.0) base — quiet-machine runs
        // land ~1.55-1.6s, but the same code has been observed at 1582-2047ms depending on
        // background load, i.e. the failures were environmental variance around a too-tight
        // 2000ms line, not a real regression (2.1.1 Track 1's optimizer changes reuse the
        // already-computed baseline projection on this path and add ~0ms).
        XCTAssertLessThan(elapsedMs, 3_000, "Cold-start budget: <3s wall-clock")
        XCTAssertTrue(manager.hasEverComputed, "Should have completed a compute")
    }

    func testRecompute_completesWithinBudget() async throws {
        // First compute
        manager.recompute(reason: .appLaunch)
        try await waitForComputation(timeout: 5.0)

        // Second compute (override change — no optimal recompute)
        let start = Date()
        manager.recompute(reason: .overridesChanged)
        try await waitForComputation(timeout: 3.0)
        let elapsedMs = Date().timeIntervalSince(start) * 1000
        XCTAssertLessThan(elapsedMs, 2_000, "Recompute budget: <2s")
    }

    func testAssumptionsChanged_SetsNeedsOptimalRecompute() {
        manager.recompute(reason: .assumptionsChanged)
        XCTAssertTrue(manager.needsOptimalRecompute, "Assumptions change must set dirty flag")
    }

    func testOverridesChanged_DoesNotSetNeedsOptimalRecompute() {
        // First, mark the dirty flag via assumptionsChanged
        manager.recompute(reason: .assumptionsChanged)
        XCTAssertTrue(manager.needsOptimalRecompute, "Precondition: assumptionsChanged must set dirty flag")

        // Now trigger an overrides-only recompute — should not clear the dirty flag
        manager.recompute(reason: .overridesChanged)
        XCTAssertTrue(manager.needsOptimalRecompute,
                      "Overrides change must not clear the needsOptimalRecompute dirty flag")
    }

    func testBaselineComputation_AddsLessThan50ms() async throws {
        manager.recompute(reason: .appLaunch)
        try await waitForComputation(timeout: 5.0)

        // Trigger a baseline-eligible recompute and measure
        let start = Date()
        manager.recompute(reason: .assumptionsChanged)
        try await waitForComputation(timeout: 5.0)
        let elapsedMs = Date().timeIntervalSince(start) * 1000

        // Baseline projection adds at most ~50ms over the existing optimization.
        // The optimization itself takes most of the budget; if total exceeds
        // 2050ms we assume baseline is the regression.
        XCTAssertLessThan(elapsedMs, 2_050, "Recompute (incl. baseline) under 2.05s")
        XCTAssertNotNil(manager.baselineProjection, "Baseline must be set")
    }

    private func waitForComputation(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.isComputing && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)  // 50ms poll
        }
    }
}
