import Foundation

enum TaxableAccountCategory: String, Codable, CaseIterable, Sendable {
    case brokerage = "Brokerage"
    case cashMoneyMarket = "Cash / Money Market"
    case dividendFund = "Dividend Fund"
    case muniBond = "Muni Bond Account"
    case trustRestricted = "Trust / Restricted"
    case otherTaxable = "Other Taxable"
}

/// A non-retirement (taxable) account: brokerage, cash, muni ladder, grantor trust, etc.
/// First-class peer of IRAAccount, consumed by the multi-year engine.
struct TaxableAccount: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var owner: Owner
    var institution: String
    var category: TaxableAccountCategory

    var balance: Double
    var costBasis: Double
    var protectedAmount: Double

    var expectedAppreciationRate: Double   // price growth, EXCLUDING income yield

    var qualifiedDividendYield: Double     // preferential rate
    var ordinaryIncomeYield: Double        // non-qual dividends + interest
    var taxExemptYield: Double             // muni: MAGI add-back only
    var realizedLongTermGainYield: Double  // fund cap-gain distributions; preferential

    var availableForExpenses: Bool
    var availableForConversionTaxes: Bool
    var fundingPriority: Int?              // lower used first; nil -> highest-basis-first

    /// True until the user confirms basis; surfaces the "Confirm basis" badge.
    var basisNeedsConfirmation: Bool

    init(id: UUID = UUID(),
         name: String,
         owner: Owner = .primary,
         institution: String = "",
         category: TaxableAccountCategory = .brokerage,
         balance: Double,
         costBasis: Double,
         protectedAmount: Double = 0,
         expectedAppreciationRate: Double = 0,
         qualifiedDividendYield: Double = 0,
         ordinaryIncomeYield: Double = 0,
         taxExemptYield: Double = 0,
         realizedLongTermGainYield: Double = 0,
         availableForExpenses: Bool = true,
         availableForConversionTaxes: Bool = true,
         fundingPriority: Int? = nil,
         basisNeedsConfirmation: Bool = false) {
        self.id = id
        self.name = name
        self.owner = owner
        self.institution = institution
        self.category = category
        self.balance = balance
        self.costBasis = costBasis
        self.protectedAmount = protectedAmount
        self.expectedAppreciationRate = expectedAppreciationRate
        self.qualifiedDividendYield = qualifiedDividendYield
        self.ordinaryIncomeYield = ordinaryIncomeYield
        self.taxExemptYield = taxExemptYield
        self.realizedLongTermGainYield = realizedLongTermGainYield
        self.availableForExpenses = availableForExpenses
        self.availableForConversionTaxes = availableForConversionTaxes
        self.fundingPriority = fundingPriority
        self.basisNeedsConfirmation = basisNeedsConfirmation
    }

    var availableBalance: Double { max(0, balance - protectedAmount) }

    var unrealizedGainFraction: Double {
        guard balance > 0 else { return 0 }
        return max(0, (balance - costBasis) / balance)
    }
}
