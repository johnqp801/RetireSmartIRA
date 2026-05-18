import XCTest
@testable import RetireSmartIRA

final class SSTorpedoWarningTests: XCTestCase {
    private let mfj = SSTorpedoWarning.Thresholds(lower: 32_000, upper: 44_000)
    private let single = SSTorpedoWarning.Thresholds(lower: 25_000, upper: 34_000)

    func testNoSSBenefits_returnsInactive() {
        let r = SSTorpedoWarning.detect(provisionalIncome: 50_000, totalSS: 0, thresholds: mfj)
        XCTAssertEqual(r.state, .inactive)
    }

    func testWellBelowLower_returnsInactive() {
        let r = SSTorpedoWarning.detect(provisionalIncome: 20_000, totalSS: 30_000, thresholds: mfj)
        XCTAssertEqual(r.state, .inactive)
    }

    func testInsidePhase50Band_returnsInTorpedo50() {
        let r = SSTorpedoWarning.detect(provisionalIncome: 38_000, totalSS: 30_000, thresholds: mfj)
        XCTAssertEqual(r.state, .inTorpedo50)
        XCTAssertGreaterThan(r.effectiveMarginalMultiplier, 1.4)
        XCTAssertLessThan(r.effectiveMarginalMultiplier, 1.6)
    }

    func testInsidePhase85Band_returnsInTorpedo85() {
        let r = SSTorpedoWarning.detect(provisionalIncome: 50_000, totalSS: 30_000, thresholds: mfj)
        XCTAssertEqual(r.state, .inTorpedo85)
        XCTAssertGreaterThan(r.effectiveMarginalMultiplier, 1.8)
        XCTAssertLessThan(r.effectiveMarginalMultiplier, 1.9)
    }

    func testAbove85SaturationCeiling_returnsInactive() {
        let r = SSTorpedoWarning.detect(provisionalIncome: 200_000, totalSS: 30_000, thresholds: mfj)
        XCTAssertEqual(r.state, .inactive)
    }

    func testSingleFilerThresholds() {
        let r = SSTorpedoWarning.detect(provisionalIncome: 28_000, totalSS: 20_000, thresholds: single)
        XCTAssertEqual(r.state, .inTorpedo50)
    }
}
