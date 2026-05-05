//
//  MigrationFlowTests.swift
//  RetireSmartIRATests

import XCTest
@testable import RetireSmartIRA

final class MigrationFlowTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clean up after each test so they don't interfere
        UserDefaults.standard.removeObject(forKey: "filingStatus")
        UserDefaults.standard.removeObject(forKey: "iraAccounts")
        UserDefaults.standard.removeObject(forKey: "primarySSBenefit")
    }

    func testNewUser_LandsOnProfileWithGetStartedBanner() {
        // Simulate fresh install: no setup data
        UserDefaults.standard.removeObject(forKey: "filingStatus")
        UserDefaults.standard.removeObject(forKey: "iraAccounts")
        UserDefaults.standard.removeObject(forKey: "primarySSBenefit")

        let initialTab = ContentView.detectSetupComplete() ? 5 : 1
        XCTAssertEqual(initialTab, 1, "New user must land on My Profile (tab 1)")
    }

    func testSetupCompleteUser_LandsOnTaxPlanning() {
        // Simulate a 1.8 user with all setup data present
        UserDefaults.standard.set("MFJ", forKey: "filingStatus")
        UserDefaults.standard.set(Data([0x01]), forKey: "iraAccounts")     // non-nil data stub
        UserDefaults.standard.set(Data([0x01]), forKey: "primarySSBenefit") // non-nil data stub

        let initialTab = ContentView.detectSetupComplete() ? 5 : 1
        XCTAssertEqual(initialTab, 5, "Setup-complete user must land on Tax Planning (tab 5)")
    }

    func testPartialSetup_MissingAccounts_LandsOnProfile() {
        UserDefaults.standard.set("MFJ", forKey: "filingStatus")
        UserDefaults.standard.removeObject(forKey: "iraAccounts")
        UserDefaults.standard.set(Data([0x01]), forKey: "primarySSBenefit")

        let initialTab = ContentView.detectSetupComplete() ? 5 : 1
        XCTAssertEqual(initialTab, 1, "Missing accounts → profile tab")
    }

    @MainActor
    func testFirstOffPlanShown_FlagsOneTimeNeutralFraming() {
        let mgr = MultiYearStrategyManager()
        XCTAssertFalse(mgr.firstOffPlanShown, "Initially false — first off-plan moment uses neutral framing")

        mgr.markFirstOffPlanShown()
        XCTAssertTrue(mgr.firstOffPlanShown, "After first interaction, switches to standard 4-state warning")
    }

    func testAssumptionsConfirmed_DefaultsFalse() {
        let assumptions = MultiYearAssumptions()
        XCTAssertFalse(assumptions.assumptionsConfirmed, "Fresh assumptions are unconfirmed — pane starts locked")
    }

    func testAssumptionsConfirmed_PersistsAcrossDecode() throws {
        var assumptions = MultiYearAssumptions()
        assumptions.assumptionsConfirmed = true

        let encoded = try JSONEncoder().encode(assumptions)
        let decoded = try JSONDecoder().decode(MultiYearAssumptions.self, from: encoded)
        XCTAssertTrue(decoded.assumptionsConfirmed, "assumptionsConfirmed must survive encode/decode round-trip")
    }

    func testAssumptionsConfirmed_DefaultsFalseWhenMissingFromLegacyJSON() throws {
        // Simulate old saved data without assumptionsConfirmed key
        let legacyJSON = """
        {
          "horizonEndAge": 95,
          "cpiRate": 0.025,
          "investmentGrowthRate": 0.06,
          "withdrawalOrderingRule": "tax_efficient",
          "stressTestEnabled": true,
          "perYearExpenseOverrides": {},
          "currentTaxableBalance": 0,
          "currentHSABalance": 0,
          "baselineAnnualExpenses": 60000,
          "terminalLiquidationTaxRate": 0.22,
          "cliffBuffer": 5000
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MultiYearAssumptions.self, from: legacyJSON)
        XCTAssertFalse(decoded.assumptionsConfirmed, "Legacy saves without the key must default to false (locked)")
    }
}
