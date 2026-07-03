import Foundation

/// Pure-value snapshot of a TaxableAccount for the engine. No UI/DataManager deps.
struct TaxableAccountInput: Equatable, Sendable {
    var balance: Double
    var costBasis: Double
    var protectedAmount: Double
    var appreciationRate: Double
    var qualifiedDividendYield: Double
    var ordinaryIncomeYield: Double
    var taxExemptYield: Double
    var realizedLongTermGainYield: Double
    var availableForExpenses: Bool
    var availableForConversionTaxes: Bool
    var fundingPriority: Int?

    var availableBalance: Double { max(0, balance - protectedAmount) }
    var gainFraction: Double { balance > 0 ? max(0, (balance - costBasis) / balance) : 0 }
}
