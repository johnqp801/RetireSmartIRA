//
//  PlanBPersistenceTests.swift
//  RetireSmartIRATests
//

import XCTest
@testable import RetireSmartIRA

@MainActor
final class PlanBPersistenceTests: XCTestCase {

    private let testKey = "multiYearAssumptions"
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "PlanBPersistenceTests-\(UUID().uuidString)")!
    }

    override func tearDown() {
        if let suiteName = testDefaults.dictionaryRepresentation().keys.first {
            testDefaults.removePersistentDomain(forName: suiteName)
        }
        testDefaults = nil
        super.tearDown()
    }

    func testMultiYearAssumptions_RoundTripViaPersistenceManager() {
        let dm = DataManager(skipPersistence: true)
        var assumptions = MultiYearAssumptions()
        assumptions.baselineAnnualExpenses = 72_000
        assumptions.dismissedInsightKeys = ["test-insight-key"]
        dm.multiYearAssumptions = assumptions

        PersistenceManager.saveAll(from: dm, defaults: testDefaults)

        let dm2 = DataManager(skipPersistence: true)
        XCTAssertNil(dm2.multiYearAssumptions, "Fresh DataManager has no assumptions")

        PersistenceManager.loadAll(into: dm2, defaults: testDefaults)

        XCTAssertNotNil(dm2.multiYearAssumptions)
        XCTAssertEqual(dm2.multiYearAssumptions?.baselineAnnualExpenses, 72_000)
        XCTAssertEqual(dm2.multiYearAssumptions?.dismissedInsightKeys, ["test-insight-key"])
    }

    func testMultiYearAssumptions_NilOnFreshDataManager() {
        let dm = DataManager(skipPersistence: true)
        XCTAssertNil(dm.multiYearAssumptions,
            "1.x users (no saved data) must load with nil multiYearAssumptions")
    }

    func testMultiYearAssumptions_LegacyKeysIgnored() {
        // Older saves don't have the key — load should leave assumptions nil.
        testDefaults.set("MFJ", forKey: "filingStatus")  // unrelated key

        let dm = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: dm, defaults: testDefaults)

        XCTAssertNil(dm.multiYearAssumptions,
            "Absent multiYearAssumptions key must leave field nil after loadAll")
    }
}
