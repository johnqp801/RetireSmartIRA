import XCTest
@testable import RetireSmartIRA

final class NIITCliffIndicatorTests: XCTestCase {
    func testFarBelowThreshold_returnsClear() {
        let s = NIITCliffIndicator.state(magi: 150_000, threshold: 250_000, nii: 10_000)
        XCTAssertEqual(s, .clear)
    }

    func testWithin25KBelowThreshold_returnsApproaching() {
        let s = NIITCliffIndicator.state(magi: 235_000, threshold: 250_000, nii: 10_000)
        XCTAssertEqual(s, .approaching)
    }

    func testExactlyAtThreshold_returnsApproaching() {
        let s = NIITCliffIndicator.state(magi: 250_000, threshold: 250_000, nii: 10_000)
        XCTAssertEqual(s, .approaching)
    }

    func testJustOverThreshold_returnsTriggered() {
        let s = NIITCliffIndicator.state(magi: 251_000, threshold: 250_000, nii: 10_000)
        XCTAssertEqual(s, .triggered)
    }

    func testNoInvestmentIncome_returnsHidden() {
        let s = NIITCliffIndicator.state(magi: 300_000, threshold: 250_000, nii: 0)
        XCTAssertEqual(s, .hidden)
    }

    func testSingleFilerThreshold200K() {
        let s = NIITCliffIndicator.state(magi: 195_000, threshold: 200_000, nii: 5_000)
        XCTAssertEqual(s, .approaching)
    }

    func testMessage_triggered_includesSurchargeAmount() {
        // NII subject = min(NII, MAGI - threshold) = min(20000, 10000) = 10000 → 380 surcharge
        let msg = NIITCliffIndicator.message(state: .triggered, magi: 260_000, threshold: 250_000, nii: 20_000)
        XCTAssertTrue(msg.contains("$380"))
    }

    func testMessage_approaching_showsHeadroom() {
        let msg = NIITCliffIndicator.message(state: .approaching, magi: 235_000, threshold: 250_000, nii: 10_000)
        XCTAssertTrue(msg.contains("$15,000") || msg.contains("$15K"))
    }
}
