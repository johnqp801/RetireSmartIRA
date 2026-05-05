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
        XCTAssertLessThan(elapsedMs, 2_000, "Cold-start budget: <2s wall-clock")
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

    private func waitForComputation(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.isComputing && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)  // 50ms poll
        }
    }
}
