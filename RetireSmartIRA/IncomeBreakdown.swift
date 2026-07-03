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

    /// The chain foots by construction: the two bridge steps are computed as residuals so the shown
    /// arithmetic always adds up, and each subtotal equals its tab's headline expression.
    ///
    /// - `allSources`: gross income from all sources (`totalAnnualIncome()`).
    /// - `regularRMD`: combined regular RMD (`calculateCombinedRMD()`); row hidden when 0.
    /// - `inheritedRMD`: inherited-IRA RMD total; row hidden when 0.
    /// - `taxableFromSources`: taxable baseline incl. RMDs (Scenarios headline expression).
    /// - `grossWithScenario`: gross incl. scenario conversions/withdrawals (`scenarioGrossIncome`).
    init(allSources: Double, regularRMD: Double, inheritedRMD: Double,
         taxableFromSources: Double, grossWithScenario: Double) {
        let totalWithRMDs = allSources + regularRMD + inheritedRMD
        self.allSources = allSources
        self.totalWithRMDs = totalWithRMDs
        self.taxableFromSources = taxableFromSources
        self.grossWithScenario = grossWithScenario

        var out: [Step] = []
        func add(_ label: String, _ amount: Double, subtotal: Bool = false) {
            out.append(Step(id: out.count, label: label, amount: amount, isSubtotal: subtotal))
        }
        add("Income from all sources", allSources)
        if regularRMD != 0 { add("Regular RMD", regularRMD) }
        if inheritedRMD != 0 { add("Inherited-IRA RMD", inheritedRMD) }
        add("Total income (sources + RMDs)", totalWithRMDs, subtotal: true)
        // Residual bridge: gross baseline minus tax-exempt interest AND the untaxed portion of Social
        // Security. Computed as a residual so the chain foots regardless of SS taxability / RMD age.
        // Hidden when 0 (fully-taxable SS, no tax-exempt interest) so we don't show a $0 subtraction.
        let taxExemptBridge = taxableFromSources - totalWithRMDs
        if taxExemptBridge != 0 {
            add("Less tax-exempt interest and untaxed Social Security", taxExemptBridge)
        }
        add("Taxable income from sources", taxableFromSources, subtotal: true)
        // Residual: scenario-driven additions (conversions + extra withdrawals, and any scenario-driven
        // change in SS taxability), so the final subtotal foots to grossWithScenario exactly. Hidden
        // when 0 (no active scenario) so we don't show a $0 addition.
        let scenarioBridge = grossWithScenario - taxableFromSources
        if scenarioBridge != 0 {
            add("Scenario additions (conversions, withdrawals)", scenarioBridge)
        }
        add("Gross income (with scenario)", grossWithScenario, subtotal: true)
        self.steps = out
    }
}
