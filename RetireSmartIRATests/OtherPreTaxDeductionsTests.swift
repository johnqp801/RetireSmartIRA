import XCTest
@testable import RetireSmartIRA

@MainActor
final class OtherPreTaxDeductionsTests: XCTestCase {

    func testDefaultsAreZero() {
        let sm = ScenarioStateManager()
        XCTAssertEqual(sm.yourOtherPreTaxDeductions, 0)
        XCTAssertEqual(sm.spouseOtherPreTaxDeductions, 0)
    }

    func testTotalOther_SumsBothSpouses() {
        let sm = ScenarioStateManager()
        sm.yourOtherPreTaxDeductions = 300
        sm.spouseOtherPreTaxDeductions = 2500
        XCTAssertEqual(sm.scenarioTotalOtherPreTaxDeductions, 2800)
    }

    func testAboveTheLineTotal_IncludesOther() {
        let sm = ScenarioStateManager()
        sm.yourTraditional401kContribution = 10_000
        sm.yourTraditionalIRAContribution = 5_000
        sm.yourHSAContribution = 2_000
        sm.yourOtherPreTaxDeductions = 300
        XCTAssertEqual(sm.scenarioTotalAboveTheLineDeductions, 17_300)
    }

    func testReset_ZerosOtherFields() {
        let sm = ScenarioStateManager()
        sm.yourOtherPreTaxDeductions = 300
        sm.spouseOtherPreTaxDeductions = 250
        sm.resetScenarioState()
        XCTAssertEqual(sm.yourOtherPreTaxDeductions, 0)
        XCTAssertEqual(sm.spouseOtherPreTaxDeductions, 0)
    }
}
