import XCTest
@testable import RetireSmartIRA

final class SmartSliderNotchesTests: XCTestCase {

    func testNoNotches_WhenSliderMaxIsZero() {
        let notches = SmartSliderNotches.compute(
            sliderMax: 0,
            bracketFillAmounts: [10_000, 30_000],
            cliffAmounts: [50_000],
            irmaaTierCrossings: []
        )
        XCTAssertTrue(notches.isEmpty)
    }

    func testBracketFillNotches_WithinRange_AreIncluded() {
        let notches = SmartSliderNotches.compute(
            sliderMax: 100_000,
            bracketFillAmounts: [12_000, 48_000],
            cliffAmounts: [],
            irmaaTierCrossings: []
        )
        let values = notches.map(\.value).sorted()
        XCTAssertEqual(values, [12_000, 48_000])
        XCTAssertTrue(notches.allSatisfy { $0.kind == .bracketFill })
    }

    func testNotches_OutOfRange_AreDropped() {
        let notches = SmartSliderNotches.compute(
            sliderMax: 50_000,
            bracketFillAmounts: [12_000, 200_000],
            cliffAmounts: [],
            irmaaTierCrossings: []
        )
        XCTAssertEqual(notches.map(\.value), [12_000])
    }

    func testNotches_NonPositiveValues_AreDropped() {
        let notches = SmartSliderNotches.compute(
            sliderMax: 100_000,
            bracketFillAmounts: [0, -500, 25_000],
            cliffAmounts: [],
            irmaaTierCrossings: []
        )
        XCTAssertEqual(notches.map(\.value), [25_000])
    }

    func testCliffAndIRMAANotches_AreLabeledCorrectly() {
        let notches = SmartSliderNotches.compute(
            sliderMax: 200_000,
            bracketFillAmounts: [],
            cliffAmounts: [60_000],
            irmaaTierCrossings: [
                .init(value: 100_000, tier: 1),
                .init(value: 150_000, tier: 2),
            ]
        )
        let kinds = notches.map(\.kind)
        XCTAssertEqual(Set(kinds), Set([.acaCliff, .irmaaTier]))
        let labels = notches.map(\.label).sorted()
        XCTAssertTrue(labels.contains("ACA cliff"))
        XCTAssertTrue(labels.contains("IRMAA Tier 1"))
        XCTAssertTrue(labels.contains("IRMAA Tier 2"))
    }

    func testNotchPosition_HalfOfRange_IsHalf() {
        let pos = SmartSliderNotches.position(value: 50_000, sliderMax: 100_000)
        XCTAssertEqual(pos, 0.5, accuracy: 1e-9)
    }

    func testNotchPosition_ClampedTo0to1() {
        XCTAssertEqual(SmartSliderNotches.position(value: -10, sliderMax: 100), 0, accuracy: 1e-9)
        XCTAssertEqual(SmartSliderNotches.position(value: 1_000, sliderMax: 100), 1, accuracy: 1e-9)
        XCTAssertEqual(SmartSliderNotches.position(value: 10, sliderMax: 0), 0, accuracy: 1e-9)
    }

    func testNotches_AreSortedAscendingByValue_AcrossKinds() {
        let notches = SmartSliderNotches.compute(
            sliderMax: 200_000,
            bracketFillAmounts: [80_000, 25_000],
            cliffAmounts: [60_000],
            irmaaTierCrossings: [
                .init(value: 100_000, tier: 1),
                .init(value: 40_000, tier: 0),
            ]
        )
        let values = notches.map(\.value)
        XCTAssertEqual(values, values.sorted())
        // Tier-0 crossings passed directly to `compute` are included (gating happens at call site).
        XCTAssertEqual(values, [25_000, 40_000, 60_000, 80_000, 100_000])
    }

    func testDeduplication_PreservesFirstWinForSameValue() {
        let notches = SmartSliderNotches.compute(
            sliderMax: 100_000,
            bracketFillAmounts: [50_000],
            cliffAmounts: [50_000],
            irmaaTierCrossings: []
        )
        XCTAssertEqual(notches.count, 1)
        XCTAssertEqual(notches.first?.kind, .bracketFill)
    }
}
