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

    func testYearsBeforeFirstRMD_ReturnsCorrectCount_WhenAge65_BornPre1960() {
        // Use a birth year firmly in the 1951–1959 cohort (RMD age = 73).
        // birthYear = 1955 → age = currentYear - 1955 (varies), but we pin currentYear
        // so the test is stable: use birthYear = currentYear - 65 only when that lands
        // in [1951,1959]. Since currentYear ≥ 2026, currentYear - 65 ≥ 1961, which is
        // NOT in that cohort — so we hard-code a 1951–1959 year instead.
        let dataManager = DataManager(skipPersistence: true)
        let currentYear = Calendar.current.component(.year, from: Date())
        // birthYear 1955 → age = currentYear - 1955 (e.g. 71 in 2026), RMD age 73
        let birthYear = 1955
        dataManager.birthDate = Calendar.current.date(
            from: DateComponents(year: birthYear, month: 1, day: 1)
        )!
        dataManager.currentYear = currentYear
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        let expectedAge = currentYear - birthYear
        let expectedYears = max(0, 73 - expectedAge)
        if expectedYears > 0 {
            XCTAssertEqual(manager.yearsBeforeFirstRMD, expectedYears,
                           "yearsBeforeFirstRMD should be \(expectedYears) for 1951–1959 cohort (RMD age 73) at age \(expectedAge)")
        } else {
            XCTAssertNil(manager.yearsBeforeFirstRMD,
                         "yearsBeforeFirstRMD should be nil when already at or past RMD age 73")
        }
    }

    func testYearsBeforeFirstRMD_ReturnsCorrectCount_WhenAge60_Born1964() {
        // Born 1960+ → RMD age 75. At age 60, expect yearsBeforeFirstRMD = 15.
        let dataManager = DataManager(skipPersistence: true)
        let currentYear = Calendar.current.component(.year, from: Date())
        // birthYear = currentYear - 60 ensures currentAge == 60.
        // In 2026, that gives birthYear 1966, which is ≥ 1960 → RMD age 75. ✓
        let birthYear = currentYear - 60
        dataManager.birthDate = Calendar.current.date(
            from: DateComponents(year: birthYear, month: 1, day: 1)
        )!
        dataManager.currentYear = currentYear
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        // birthYear >= 1960 → RMD age 75; age 60 → 15 years to go
        XCTAssertEqual(manager.yearsBeforeFirstRMD, 15,
                       "yearsBeforeFirstRMD should be 15 for 1960+ cohort (RMD age 75) at age 60")
    }

    func testYearsBeforeFirstRMD_ReturnsOne_WhenAge74_Born1960Cohort() {
        // Born 1960+ → RMD age 75. At age 74, expect yearsBeforeFirstRMD = 1.
        let dataManager = DataManager(skipPersistence: true)
        let currentYear = Calendar.current.component(.year, from: Date())
        // birthYear = currentYear - 74 ensures currentAge == 74.
        // In 2026, that gives birthYear 1952, which is in [1951,1959] → RMD age 73, not 75.
        // So we must hard-code a 1960+ birth year and pin currentYear such that age = 74,
        // i.e., birthYear = 1960, currentYear = 2034 is in the future.
        // Instead, use the real current year and set birthYear so it's ≥ 1960 and age = 74:
        // that requires currentYear - birthYear = 74 with birthYear ≥ 1960 → currentYear ≥ 2034.
        // Since we can't guarantee that, we test age 74 with a 1960 birth year by overriding
        // dataManager.currentYear to a future year where 1960 + 74 = 2034.
        dataManager.birthDate = Calendar.current.date(
            from: DateComponents(year: 1960, month: 1, day: 1)
        )!
        dataManager.currentYear = 2034  // 2034 - 1960 = 74 → age 74, RMD age 75 → 1 year remaining
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        XCTAssertEqual(manager.yearsBeforeFirstRMD, 1,
                       "yearsBeforeFirstRMD should be 1 for 1960+ cohort (RMD age 75) at age 74")
    }

    func testYearsBeforeFirstRMD_ReturnsNil_WhenAtRMDAge75_Born1960Cohort() {
        // Born 1960+ → RMD age 75. At age 75, expect yearsBeforeFirstRMD = nil.
        let dataManager = DataManager(skipPersistence: true)
        // birthYear 1960, currentYear 2035 → age 75, RMD age 75 → nil
        dataManager.birthDate = Calendar.current.date(
            from: DateComponents(year: 1960, month: 1, day: 1)
        )!
        dataManager.currentYear = 2035
        let scenarioStateManager = ScenarioStateManager()
        let manager = MultiYearStrategyManager()
        manager.attach(dataManager: dataManager, scenarioStateManager: scenarioStateManager)

        XCTAssertNil(manager.yearsBeforeFirstRMD,
                     "yearsBeforeFirstRMD must return nil when 1960+ cohort user is exactly at RMD age (75)")
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
