import XCTest
import SwiftUI
@testable import RetireSmartIRA

/// Pure-logic coverage for the couples claiming-age heat-map's cell color bucketing.
///
/// Bug: all 81 cells in the 9x9 matrix rendered the same gray regardless of
/// `combinedLifetimeBenefit`. This pins `SSCouplesMatrixColor.color(for:min:max:)`
/// to produce visually DISTINCT colors across the worst/mid/best thirds of the
/// matrix's actual value range, and to degrade gracefully (no crash, no NaN)
/// when every cell is tied.
final class SSCouplesMatrixColorTests: XCTestCase {

    // MARK: - RGBA resolution helper (mirrors ContrastAssertionTests/ColorTokenUITests)

    private func rgba(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        (NSColor(color).usingColorSpace(.sRGB) ?? NSColor.black).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (r, g, b, a)
    }

    private func cell(_ amount: Double, primaryAge: Int = 67, spouseAge: Int = 67) -> SSCouplesMatrixCell {
        SSCouplesMatrixCell(
            primaryClaimingAge: primaryAge,
            spouseClaimingAge: spouseAge,
            primaryMonthly: 0,
            spouseMonthly: 0,
            combinedLifetimeBenefit: amount,
            survivorBenefitIfPrimaryDies: 0,
            survivorBenefitIfSpouseDies: 0,
            isHighestLifetime: false
        )
    }

    // MARK: - Distinct 3-bucket coloring across a real spread

    func test_bestMidWorstCells_getDistinctColors() {
        let matrix = [cell(700_000), cell(850_000), cell(1_000_000)]
        let minVal = matrix.map(\.combinedLifetimeBenefit).min()!
        let maxVal = matrix.map(\.combinedLifetimeBenefit).max()!

        let worst = SSCouplesMatrixColor.color(for: 700_000, min: minVal, max: maxVal)
        let mid = SSCouplesMatrixColor.color(for: 850_000, min: minVal, max: maxVal)
        let best = SSCouplesMatrixColor.color(for: 1_000_000, min: minVal, max: maxVal)

        let worstRGBA = rgba(worst)
        let midRGBA = rgba(mid)
        let bestRGBA = rgba(best)

        XCTAssertNotEqual(worstRGBA.r, midRGBA.r, accuracy: 0.001,
                           "worst and mid cells resolved to the same color; heat map won't visually distinguish them")
        XCTAssertNotEqual(midRGBA.r, bestRGBA.r, accuracy: 0.001,
                           "mid and best cells resolved to the same color; heat map won't visually distinguish them")
        XCTAssertNotEqual(worstRGBA.r, bestRGBA.r, accuracy: 0.001,
                           "worst and best cells resolved to the same color; heat map won't visually distinguish them")
    }

    func test_lowestValue_isLightestBucket_highestValue_isDarkestBucket() {
        let minVal = 500_000.0
        let maxVal = 1_000_000.0

        let worstColor = SSCouplesMatrixColor.color(for: minVal, min: minVal, max: maxVal)
        let bestColor = SSCouplesMatrixColor.color(for: maxVal, min: minVal, max: maxVal)

        // Darkest bucket should have lower per-channel luminance than the lightest bucket.
        let worstRGBA = rgba(worstColor)
        let bestRGBA = rgba(bestColor)
        let worstLuma = 0.299 * worstRGBA.r + 0.587 * worstRGBA.g + 0.114 * worstRGBA.b
        let bestLuma = 0.299 * bestRGBA.r + 0.587 * bestRGBA.g + 0.114 * bestRGBA.b

        XCTAssertGreaterThan(worstLuma, bestLuma,
                              "the lowest-benefit cell should render lighter than the highest-benefit cell")
    }

    // MARK: - Real 9-cell spread (subset of the 9x9 matrix)

    func test_nineCellSpread_producesAtLeastThreeDistinctColors() {
        let values: [Double] = [600_000, 650_000, 700_000, 750_000, 800_000, 850_000, 900_000, 950_000, 1_000_000]
        let minVal = values.min()!
        let maxVal = values.max()!

        let colors = values.map { SSCouplesMatrixColor.color(for: $0, min: minVal, max: maxVal) }
        let distinctRGBAs = Set(colors.map { c -> String in
            let comp = rgba(c)
            return "\(Int(comp.r * 255)),\(Int(comp.g * 255)),\(Int(comp.b * 255))"
        })

        XCTAssertGreaterThanOrEqual(distinctRGBAs.count, 3,
                                    "expected at least 3 distinct heat-map colors across a full value spread, got \(distinctRGBAs.count)")
    }

    // MARK: - Degenerate matrix (every cell tied) must not crash

    func test_degenerateMatrix_allCellsEqual_doesNotCrashAndReturnsAColor() {
        let matrix = [cell(750_000), cell(750_000), cell(750_000)]
        let minVal = matrix.map(\.combinedLifetimeBenefit).min()!
        let maxVal = matrix.map(\.combinedLifetimeBenefit).max()!
        XCTAssertEqual(minVal, maxVal)

        let color = SSCouplesMatrixColor.color(for: 750_000, min: minVal, max: maxVal)
        // Must resolve to a real, opaque color rather than trapping on a divide-by-zero.
        let resolved = rgba(color)
        XCTAssertEqual(resolved.a, 1.0, accuracy: 0.001)
    }
}
