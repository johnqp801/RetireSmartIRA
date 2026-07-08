import Foundation

/// Pure model for the account-balances-over-time chart. Optional pessimistic/optimistic paths
/// supply a GROWTH-rate sensitivity band on the total balance (not a risk/probability band).
struct BalancesChart: Equatable, Sendable {
    struct Point: Identifiable, Equatable, Sendable {
        let id: Int
        let year: Int
        let traditional: Double
        let roth: Double
        let taxable: Double
        let totalLow: Double?
        let totalHigh: Double?
    }
    let points: [Point]

    var hasBand: Bool { points.contains { $0.totalLow != nil && $0.totalHigh != nil } }

    init(path: [YearRecommendation],
         pessimistic: [YearRecommendation]? = nil,
         optimistic: [YearRecommendation]? = nil) {
        let lowByYear = Dictionary((pessimistic ?? []).map { ($0.year, $0.endOfYearBalances.total) },
                                   uniquingKeysWith: { first, _ in first })
        let highByYear = Dictionary((optimistic ?? []).map { ($0.year, $0.endOfYearBalances.total) },
                                    uniquingKeysWith: { first, _ in first })
        self.points = path.map { rec in
            // Inherited balances display inside the trad/Roth series (they lived in those
            // buckets before the 2.1 inherited split), keeping the stack consistent with
            // the .total band.
            Point(id: rec.year, year: rec.year,
                  traditional: rec.endOfYearBalances.traditional + rec.endOfYearBalances.inheritedTraditional,
                  roth: rec.endOfYearBalances.roth + rec.endOfYearBalances.inheritedRoth,
                  taxable: rec.endOfYearBalances.taxable,
                  totalLow: lowByYear[rec.year],
                  totalHigh: highByYear[rec.year])
        }
    }
}
