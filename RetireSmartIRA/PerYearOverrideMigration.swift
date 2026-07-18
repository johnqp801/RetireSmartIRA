import Foundation

/// Converts the legacy expense-override map (an ABSOLUTE total per year) into the new ADDITIVE
/// representation. `expense(Y)` was `legacy(Y)`; it is now `recurringBaseline(Y) + oneTime(Y)`, so
/// the equivalent one-time delta is `legacy(Y) - originalBaseline(Y)`. Legacy overrides were single
/// years, so they carry no recurring level. Pure and side-effect-free.
enum PerYearOverrideMigration {
    static func migrate(legacyExpenseOverrides: [Int: Double],
                        baselineAnnualExpenses: Double,
                        cpiRate: Double,
                        baseYear: Int) -> [Int: YearOverride] {
        legacyExpenseOverrides.reduce(into: [:]) { acc, kv in
            let (year, legacy) = kv
            let originalBaseline = baselineAnnualExpenses * pow(1 + cpiRate, Double(max(0, year - baseYear)))
            let delta = legacy - originalBaseline
            acc[year] = YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: delta))
        }
    }
}
