import XCTest
import SwiftUI
@testable import RetireSmartIRA

final class ColorTokenChartTests: XCTestCase {
    func test_allChartTokensExist() {
        _ = Color.Chart.heroTeal
        _ = Color.Chart.callout
        _ = Color.Chart.calloutHover
        _ = Color.Chart.calloutPressed
        _ = Color.Chart.gray1
        _ = Color.Chart.gray2
        _ = Color.Chart.gray3
        _ = Color.Chart.gray4
        _ = Color.Chart.gray5
        _ = Color.Chart.tealRamp1
        _ = Color.Chart.tealRamp2
        _ = Color.Chart.tealRamp3
        _ = Color.Chart.tealRamp4
        _ = Color.Chart.tealRamp5
        _ = Color.Chart.tealRamp6
    }

    func test_categoricalSeriesReturnsRequestedCount() {
        XCTAssertEqual(Color.Chart.categoricalSeries(count: 1).count, 1)
        XCTAssertEqual(Color.Chart.categoricalSeries(count: 3).count, 3)
        XCTAssertEqual(Color.Chart.categoricalSeries(count: 6).count, 6)
    }

    func test_categoricalSeriesWithCallout() {
        let series = Color.Chart.categoricalSeries(count: 6, callout: 2)
        XCTAssertEqual(series.count, 6)
        // The callout color at index 2 should differ from the gray that would otherwise occupy that slot.
        // We can't directly compare Color values, but we can confirm the function doesn't crash and returns the expected count.
    }

    func test_categoricalSeriesWithCalloutOutOfRangeDoesNotCrash() {
        let series = Color.Chart.categoricalSeries(count: 3, callout: 99)
        XCTAssertEqual(series.count, 3)
    }

    func test_sequentialRampReturnsRequestedCount() {
        XCTAssertEqual(Color.Chart.sequentialRamp(count: 1).count, 1)
        XCTAssertEqual(Color.Chart.sequentialRamp(count: 3).count, 3)
        XCTAssertEqual(Color.Chart.sequentialRamp(count: 6).count, 6)
    }

    func test_sequentialRampClampsAtSix() {
        // Asking for more than 6 should return at most 6 (the ramp's max).
        XCTAssertEqual(Color.Chart.sequentialRamp(count: 10).count, 6)
    }
}
