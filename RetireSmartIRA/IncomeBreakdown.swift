import Foundation

/// Single source of truth for the single-year income "chain" shown on the Income, Tax Summary,
/// Scenarios, and Quarterly tabs. Composes existing DataManager figures so every tab reads the same
/// numbers under precise, self-explanatory labels (fixes the "four different income totals" problem).
struct IncomeBreakdown: Equatable, Sendable {
    struct Step: Identifiable, Equatable, Sendable {
        let id: Int
        let label: String
        let amount: Double
        /// Subtotals render bold with a divider above them.
        let isSubtotal: Bool
    }

    /// Each equals what a tab currently displays as its headline income figure.
    let allSources: Double          // Income tab
    let totalWithRMDs: Double        // Tax Summary
    let taxableFromSources: Double   // Scenarios
    let grossWithScenario: Double    // Quarterly

    let steps: [Step]

    init(allSources: Double, inheritedRMD: Double, taxExempt: Double,
         taxableFromSources: Double, scenarioAdditions: Double, grossWithScenario: Double) {
        self.allSources = allSources
        self.totalWithRMDs = allSources + inheritedRMD
        self.taxableFromSources = taxableFromSources
        self.grossWithScenario = grossWithScenario

        var out: [Step] = []
        func add(_ label: String, _ amount: Double, subtotal: Bool = false) {
            out.append(Step(id: out.count, label: label, amount: amount, isSubtotal: subtotal))
        }
        add("Income from all sources", allSources)
        add("Inherited-IRA RMD", inheritedRMD)
        add("Total income (sources + RMDs)", allSources + inheritedRMD, subtotal: true)
        add("Less tax-exempt interest", -taxExempt)
        add("Taxable income from sources", taxableFromSources, subtotal: true)
        add("Scenario withdrawals / conversions", scenarioAdditions)
        add("Gross income (with scenario)", grossWithScenario, subtotal: true)
        self.steps = out
    }
}
