import Foundation

/// Pure model for the recommended-conversions-by-year bar chart.
struct ConversionLadderChart: Equatable, Sendable {
    struct Point: Identifiable, Equatable, Sendable {
        let id: Int
        let year: Int
        let conversion: Double
        var yearLabel: String { String(year) }
    }
    let points: [Point]

    init(path: [YearRecommendation]) {
        let all = path.map { rec -> Point in
            let conv = rec.actions.reduce(0.0) { acc, action in
                if case let .rothConversion(amount) = action { return acc + amount }
                return acc
            }
            return Point(id: rec.year, year: rec.year, conversion: conv)
        }
        // Show only the conversion window: from the first year with a recommended
        // conversion through the last. The categorical (per-year) x-axis gives every
        // year an equal slot, so trailing/leading zero-conversion years would pad the
        // chart with empty bars and crowd the year labels into truncated "2..." stubs.
        // Interior zero years stay so a gap in the schedule still reads as a gap.
        if let first = all.firstIndex(where: { $0.conversion > 0 }),
           let last = all.lastIndex(where: { $0.conversion > 0 }) {
            self.points = Array(all[first...last])
        } else {
            self.points = all
        }
    }

    var hasAnyConversion: Bool { points.contains { $0.conversion > 0 } }
}
