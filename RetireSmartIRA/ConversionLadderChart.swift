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
        self.points = path.map { rec in
            let conv = rec.actions.reduce(0.0) { acc, action in
                if case let .rothConversion(amount) = action { return acc + amount }
                return acc
            }
            return Point(id: rec.year, year: rec.year, conversion: conv)
        }
    }

    var hasAnyConversion: Bool { points.contains { $0.conversion > 0 } }
}
