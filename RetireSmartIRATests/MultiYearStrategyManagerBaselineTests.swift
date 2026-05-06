//
//  MultiYearStrategyManagerBaselineTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

@MainActor
final class MultiYearStrategyManagerBaselineTests: XCTestCase {

    func testBaselineProjection_StartsNil() {
        let manager = MultiYearStrategyManager()
        XCTAssertNil(manager.baselineProjection,
                     "baselineProjection must default to nil before first compute")
    }

    func testBaselineProjection_PopulatedAfterRecompute() async throws {
        let dataManager = DataManager(skipPersistence: true)
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
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        manager.recompute(reason: .appLaunch)
        try await waitForComputation(manager: manager, timeout: 10.0)

        XCTAssertNotNil(manager.baselineProjection,
                        "baselineProjection must be populated after appLaunch recompute")
        XCTAssertFalse(manager.baselineProjection?.isEmpty ?? true,
                        "baselineProjection must contain at least one YearRecommendation")
    }

    func testBaselineProjection_HasNoRothConversions() async throws {
        let dataManager = DataManager(skipPersistence: true)
        dataManager.socialSecurity.primarySSBenefit = SSBenefitEstimate(
            owner: .primary, benefitAt62: 2660, benefitAtFRA: 3800, benefitAt70: 4712,
            plannedClaimingAge: 70, plannedClaimingMonth: 0, isAlreadyClaiming: false, currentBenefit: 0
        )
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: ScenarioStateManager())

        manager.recompute(reason: .appLaunch)
        try await waitForComputation(manager: manager, timeout: 10.0)

        let baseline = manager.baselineProjection ?? []
        for year in baseline {
            for action in year.actions {
                if case .rothConversion = action {
                    XCTFail("Baseline must not contain Roth conversion actions; found in year \(year.year)")
                }
                // Note: LeverAction has no .qcd case in V2.0; QCDs are not yet emitted
                // by either ProjectionEngine or OptimizationEngine. This test documents
                // the no-conversion invariant; QCD invariant is moot in the current model.
            }
        }
    }

    private func waitForComputation(manager: MultiYearStrategyManager, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while manager.isComputing && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
