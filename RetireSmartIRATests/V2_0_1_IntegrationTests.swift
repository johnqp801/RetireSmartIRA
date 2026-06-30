//
//  V2_0_1_IntegrationTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

@MainActor
final class V2_0_1_IntegrationTests: XCTestCase {

    func testFullStrategyView_LoadsWithBaseline() async throws {
        let dataManager = DataManager(skipPersistence: true)

        // Set Social Security benefit via the SS manager (primarySSBenefit is on socialSecurity)
        dataManager.socialSecurity.primarySSBenefit = SSBenefitEstimate(
            owner: .primary,
            benefitAt62: 2660, benefitAtFRA: 3800, benefitAt70: 4712,
            plannedClaimingAge: 70, plannedClaimingMonth: 0,
            isAlreadyClaiming: false, currentBenefit: 0
        )

        // primaryTraditionalIRABalance is a computed read-only property that aggregates
        // from accounts.iraAccounts — set a traditional IRA account directly.
        dataManager.accounts.iraAccounts = [
            IRAAccount(
                name: "Primary Traditional IRA",
                accountType: .traditionalIRA,
                balance: 1_500_000,
                owner: .primary
            )
        ]

        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)
        manager.assumptions.assumptionsConfirmed = true

        manager.recompute(reason: .appLaunch)
        try await waitFor(condition: { !manager.isComputing }, timeout: 5.0)

        XCTAssertNotNil(manager.engineOptimalResult)
        XCTAssertNotNil(manager.baselineProjection)
        XCTAssertNotNil(manager.currentResult)

        // Baseline tax should be at least as high as optimal — if traditional balance is large,
        // forcing no-conversion produces RMDs that overrun brackets.
        // We use >= rather than > to allow a tie (e.g. when the optimizer can't improve upon
        // the baseline due to the specific profile shape or a zero-horizon edge case).
        let baselineTax = (manager.baselineProjection ?? []).lifetimeTax
        let optimalTax = manager.engineOptimalResult?.recommendedPath.lifetimeTax ?? 0
        XCTAssertGreaterThanOrEqual(baselineTax, optimalTax,
            "Baseline (no-strategy) tax should be >= optimal tax for users with sizable traditional balance")
    }

    private func waitFor(condition: @escaping () -> Bool, timeout: TimeInterval) async throws {
        // Phase 1: wait for isComputing to become true (up to 1s)
        let startDeadline = Date().addingTimeInterval(1.0)
        while !(!condition()) && Date() < startDeadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        // Phase 2: wait for computation to finish
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        if !condition() {
            XCTFail("Condition not met within \(timeout)s")
        }
    }
}
