import SwiftUI

/// Chart namespace — data visualization only.
/// See docs/superpowers/specs/2026-04-25-color-system-design.md §5.
///
/// **Hard rule:** `Color.Chart.*` NEVER overlaps `Color.Semantic.*`.
/// The chart palette is teal + neutral grays + warm sand. There is no green
/// chart bar (green means refund), no red chart bar (red means error), no
/// amber chart bar (amber means action required).
extension Color {
    enum Chart {
        // MARK: - Hero + accent
        /// Hero category color. Aliases brand teal — same hex, used in chart context.
        static let heroTeal        = Color.UI.brandTeal
        /// Warm-sand callout for "look here" highlights in categorical charts.
        static let callout         = Color("ChartCallout",        bundle: .main)
        static let calloutHover    = Color("ChartCalloutHover",   bundle: .main)
        static let calloutPressed  = Color("ChartCalloutPressed", bundle: .main)

        // MARK: - Neutral gray ramp (categorical context for non-hero categories)
        static let gray1           = Color("ChartGray1", bundle: .main)
        static let gray2           = Color("ChartGray2", bundle: .main)
        static let gray3           = Color("ChartGray3", bundle: .main)
        static let gray4           = Color("ChartGray4", bundle: .main)
        static let gray5           = Color("ChartGray5", bundle: .main)

        // MARK: - Teal ramp (sequential / ordered data — brackets, time series)
        static let tealRamp1       = Color("ChartTealRamp1", bundle: .main)
        static let tealRamp2       = Color("ChartTealRamp2", bundle: .main)
        static let tealRamp3       = Color("ChartTealRamp3", bundle: .main)
        static let tealRamp4       = Color("ChartTealRamp4", bundle: .main)
        static let tealRamp5       = Color("ChartTealRamp5", bundle: .main)
        static let tealRamp6       = Color("ChartTealRamp6", bundle: .main)

        // MARK: - Helpers

        /// Returns a categorical color series with hero in position 0,
        /// callout sand at the specified callout index, and neutral grays
        /// descending for the rest.
        ///
        /// - Parameters:
        ///   - count: number of categories (1–6)
        ///   - callout: index of the category to highlight with sand. Pass `nil` for no callout.
        /// - Returns: array of `Color` values matching `count`.
        static func categoricalSeries(count: Int, callout: Int? = nil) -> [Color] {
            let grays = [gray1, gray2, gray3, gray4, gray5]
            var result: [Color] = [heroTeal]
            for i in 0..<max(0, count - 1) {
                result.append(grays[min(i, grays.count - 1)])
            }
            if let calloutIdx = callout, calloutIdx < result.count {
                result[calloutIdx] = Self.callout
            }
            return Array(result.prefix(count))
        }

        /// Returns a sequential teal ramp for ordered data (e.g., tax brackets).
        ///
        /// - Parameter count: number of steps (1–6)
        /// - Returns: array of `Color` values from darkest (position 0) to lightest.
        static func sequentialRamp(count: Int) -> [Color] {
            let ramp = [tealRamp1, tealRamp2, tealRamp3, tealRamp4, tealRamp5, tealRamp6]
            return Array(ramp.prefix(count))
        }
    }
}
