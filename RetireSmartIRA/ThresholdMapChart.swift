import Foundation

/// Pure model for the threshold/cliff map: each year's income plotted against the tax cliffs it
/// navigates. Two measures (kept on separate axes via a view toggle, never overlaid):
///   - magiCliffs: MAGI vs IRMAA tiers / NIIT / ACA cliff
///   - incomeTaxBrackets: taxable income vs federal bracket thresholds
struct ThresholdMapChart: Equatable, Sendable {
    enum Measure: Equatable, Sendable { case magiCliffs, incomeTaxBrackets }

    struct IncomePoint: Identifiable, Equatable, Sendable {
        let id: Int
        let year: Int
        let value: Double
    }
    struct Line: Identifiable, Equatable, Sendable {
        let id: String
        let label: String
        let value: Double
    }

    let magiPoints: [IncomePoint]
    let bracketPoints: [IncomePoint]
    let magiLines: [Line]
    let bracketLines: [Line]

    init(path: [YearRecommendation], magiLines: [Line], bracketLines: [Line]) {
        self.magiPoints = path.map {
            IncomePoint(id: $0.year, year: $0.year, value: $0.irmaaMagi ?? $0.acaMagi ?? $0.agi)
        }
        self.bracketPoints = path.map {
            IncomePoint(id: $0.year, year: $0.year, value: $0.taxableIncome)
        }
        self.magiLines = magiLines
        self.bracketLines = bracketLines
    }

    func points(for measure: Measure) -> [IncomePoint] {
        measure == .magiCliffs ? magiPoints : bracketPoints
    }
    func lines(for measure: Measure) -> [Line] {
        measure == .magiCliffs ? magiLines : bracketLines
    }
}
