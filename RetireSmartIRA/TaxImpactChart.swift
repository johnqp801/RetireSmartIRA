import Foundation

/// Pure model for the cumulative tax-paid comparison (your plan vs doing nothing). Surfaces the
/// crossover where the plan, which pays more tax early, overtakes doing nothing.
struct TaxImpactChart: Equatable, Sendable {
    struct Point: Identifiable, Equatable, Sendable {
        let id: Int
        let year: Int
        let cumulativePlan: Double
        let cumulativeDoingNothing: Double
    }
    let points: [Point]

    /// Cumulative savings at the end of the horizon: doing-nothing total minus plan total.
    /// Positive = the plan pays less over the horizon.
    var totalSavings: Double {
        guard let last = points.last else { return 0 }
        return last.cumulativeDoingNothing - last.cumulativePlan
    }

    init(plan: [YearRecommendation], doingNothing: [YearRecommendation]) {
        let dnByYear = Dictionary(doingNothing.map { ($0.year, $0.taxBreakdown.total) },
                                  uniquingKeysWith: { first, _ in first })
        var cumPlan = 0.0, cumDN = 0.0
        var pts: [Point] = []
        for rec in plan {
            cumPlan += rec.taxBreakdown.total
            cumDN += dnByYear[rec.year] ?? 0
            pts.append(Point(id: rec.year, year: rec.year,
                             cumulativePlan: cumPlan, cumulativeDoingNothing: cumDN))
        }
        self.points = pts
    }
}
