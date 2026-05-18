import XCTest
@testable import RetireSmartIRA

final class SSCouplesCloseCallTests: XCTestCase {
    private func cell(_ amount: Double) -> SSCouplesMatrixCell {
        SSCouplesMatrixCell(
            primaryClaimingAge: 67,
            spouseClaimingAge: 67,
            primaryMonthly: 0,
            spouseMonthly: 0,
            combinedLifetimeBenefit: amount,
            survivorBenefitIfPrimaryDies: 0,
            survivorBenefitIfSpouseDies: 0,
            isHighestLifetime: false
        )
    }

    func test_closeCall_whenTop2Within50k() {
        let m = [cell(1_000_000), cell(960_000), cell(800_000)]
        XCTAssertTrue(SSCouplesStrategyView.isCloseCall(matrix: m))
    }

    func test_notCloseCall_whenTop2DifferBy60k() {
        let m = [cell(1_000_000), cell(940_000), cell(800_000)]
        XCTAssertFalse(SSCouplesStrategyView.isCloseCall(matrix: m))
    }

    func test_notCloseCall_whenLessThanTwoCells() {
        XCTAssertFalse(SSCouplesStrategyView.isCloseCall(matrix: [cell(1_000_000)]))
        XCTAssertFalse(SSCouplesStrategyView.isCloseCall(matrix: []))
    }

    func test_closeCall_exactly50k_isInclusive() {
        let m = [cell(1_000_000), cell(950_000)]
        XCTAssertTrue(SSCouplesStrategyView.isCloseCall(matrix: m))
    }
}
