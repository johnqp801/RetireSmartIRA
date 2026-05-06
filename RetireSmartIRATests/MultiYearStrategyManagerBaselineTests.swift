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
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        manager.recompute(reason: .appLaunch)
        try await waitForComputation(manager: manager, timeout: 10.0)

        let baseline = manager.baselineProjection ?? []
        XCTAssertFalse(baseline.isEmpty, "Baseline must contain years before checking for forbidden actions")
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

    // MARK: - yearsBeforeFirstRMD tests

    func testYearsBeforeFirstRMD_ReturnsNil_WhenNotAttached() {
        let manager = MultiYearStrategyManager()
        // Not attached to a DataManager
        XCTAssertNil(manager.yearsBeforeFirstRMD,
                     "yearsBeforeFirstRMD must return nil when dataManager is not set")
    }

    func testYearsBeforeFirstRMD_ReturnsCorrectCount_WhenAge65() {
        // currentAge = currentYear - birthYear, so set birthYear = currentYear - 65
        let dataManager = DataManager(skipPersistence: true)
        let currentYear = Calendar.current.component(.year, from: Date())
        dataManager.birthDate = Calendar.current.date(
            from: DateComponents(year: currentYear - 65, month: 1, day: 1)
        )!
        dataManager.currentYear = currentYear
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        // At age 65, RMD age 73: expect 8 years remaining
        XCTAssertEqual(manager.yearsBeforeFirstRMD, 8,
                       "yearsBeforeFirstRMD should be 8 when primary is age 65 (73 - 65)")
    }

    func testYearsBeforeFirstRMD_ReturnsNil_WhenAtRMDAge73() {
        // A user born in 1951–1959 reaches RMD at 73.
        // Use birthYear = currentYear - 73 to land squarely in that cohort.
        let dataManager = DataManager(skipPersistence: true)
        let currentYear = Calendar.current.component(.year, from: Date())
        // Birth year that gives age 73 and falls in the 1951–1959 cohort (RMD=73):
        // currentYear - 73 → e.g. 2026 - 73 = 1953, which is in [1951,1959] ✓
        dataManager.birthDate = Calendar.current.date(
            from: DateComponents(year: currentYear - 73, month: 1, day: 1)
        )!
        dataManager.currentYear = currentYear
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        // At RMD age, yearsBeforeFirstRMD should be nil (0 years remaining → nil)
        XCTAssertNil(manager.yearsBeforeFirstRMD,
                     "yearsBeforeFirstRMD must return nil when user is exactly at RMD age (73)")
    }

    func testYearsBeforeFirstRMD_ReturnsNil_WhenPastRMDAge() {
        let dataManager = DataManager(skipPersistence: true)
        let currentYear = Calendar.current.component(.year, from: Date())
        // Age 74: birthYear = currentYear - 74 → e.g. 2026 - 74 = 1952, cohort RMD=73 ✓
        dataManager.birthDate = Calendar.current.date(
            from: DateComponents(year: currentYear - 74, month: 1, day: 1)
        )!
        dataManager.currentYear = currentYear
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        XCTAssertNil(manager.yearsBeforeFirstRMD,
                     "yearsBeforeFirstRMD must return nil when user is past RMD age (74)")
    }

    // MARK: - Helpers

    private func waitForComputation(manager: MultiYearStrategyManager, timeout: TimeInterval) async throws {
        // Wait for computing to start (handles cases where isComputing hasn't been set yet)
        let startDeadline = Date().addingTimeInterval(1.0)
        while !manager.isComputing && Date() < startDeadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        // Wait for computing to finish
        let endDeadline = Date().addingTimeInterval(timeout)
        while manager.isComputing && Date() < endDeadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        if manager.isComputing {
            XCTFail("waitForComputation timed out after \(timeout)s")
        }
    }
}
