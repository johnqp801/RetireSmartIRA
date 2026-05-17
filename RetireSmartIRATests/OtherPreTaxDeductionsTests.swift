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

    func testAboveTheLineTotal_IncludesSpouseOther() {
        let sm = ScenarioStateManager()
        sm.yourTraditional401kContribution = 10_000
        sm.yourTraditionalIRAContribution = 5_000
        sm.yourHSAContribution = 2_000
        sm.spouseOtherPreTaxDeductions = 500
        XCTAssertEqual(sm.scenarioTotalAboveTheLineDeductions, 17_500)
    }

    func testAboveTheLineTotal_BothSpousesAllLevers() {
        let sm = ScenarioStateManager()
        sm.yourTraditional401kContribution = 23_500
        sm.spouseTraditional401kContribution = 20_000
        sm.yourTraditionalIRAContribution = 7_000
        sm.spouseTraditionalIRAContribution = 6_500
        sm.yourHSAContribution = 4_300
        sm.spouseHSAContribution = 4_000
        sm.yourOtherPreTaxDeductions = 1_200
        sm.spouseOtherPreTaxDeductions = 800
        let expected: Double = 23_500 + 20_000 + 7_000 + 6_500 + 4_300 + 4_000 + 1_200 + 800
        XCTAssertEqual(sm.scenarioTotalAboveTheLineDeductions, expected)
    }

    func testReset_ZerosOtherFields() {
        let sm = ScenarioStateManager()
        sm.yourOtherPreTaxDeductions = 300
        sm.spouseOtherPreTaxDeductions = 250
        sm.resetScenarioState()
        XCTAssertEqual(sm.yourOtherPreTaxDeductions, 0)
        XCTAssertEqual(sm.spouseOtherPreTaxDeductions, 0)
        XCTAssertEqual(sm.scenarioTotalOtherPreTaxDeductions, 0)
        XCTAssertEqual(sm.scenarioTotalAboveTheLineDeductions, 0)
    }

    func testFederalAGIDropsByOtherTotal() {
        let dm = DataManager(skipPersistence: true)
        dm.incomeSources = [
            IncomeSource(name: "Wages", type: .consulting, annualAmount: 200_000, owner: .primary)
        ]
        let baseline = dm.federalAGI.value
        dm.scenario.yourOtherPreTaxDeductions = 1_500
        dm.scenario.spouseOtherPreTaxDeductions = 800
        let withOther = dm.federalAGI.value
        XCTAssertEqual(baseline - withOther, 2_300,
            "federalAGI must drop by yourOther + spouseOther (2_300)")
    }
}
