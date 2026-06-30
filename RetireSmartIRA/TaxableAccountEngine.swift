import Foundation

struct TaxableBucket: Equatable {
    var balance: Double
    var costBasis: Double
    let input: TaxableAccountInput

    var availableBalance: Double { max(0, balance - input.protectedAmount) }
    var gainFraction: Double { balance > 0 ? max(0, (balance - costBasis) / balance) : 0 }
}

enum TaxableAccountEngine {
    /// Annual income on the current balances, split by tax character. `spendableCash` is the
    /// income from accounts available for spending (walled accounts are taxed but reinvested).
    static func annualIncome(_ buckets: [TaxableBucket]) -> (ordinary: Double, preferential: Double, taxExempt: Double, spendableCash: Double) {
        var ord = 0.0, pref = 0.0, exempt = 0.0, cash = 0.0
        for b in buckets {
            let o = b.input.ordinaryIncomeYield * b.balance
            let p = (b.input.qualifiedDividendYield + b.input.realizedLongTermGainYield) * b.balance
            let e = b.input.taxExemptYield * b.balance
            ord += o; pref += p; exempt += e
            if b.input.availableForExpenses { cash += o + p + e }
        }
        return (ord, pref, exempt, cash)
    }

    /// Funding order: explicit fundingPriority ascending first, then highest basis (lowest gain) first.
    private static func order(_ idxs: [Int], _ buckets: [TaxableBucket]) -> [Int] {
        idxs.sorted { a, b in
            switch (buckets[a].input.fundingPriority, buckets[b].input.fundingPriority) {
            case let (pa?, pb?): if pa != pb { return pa < pb }
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): break
            }
            return buckets[a].gainFraction < buckets[b].gainFraction
        }
    }

    /// Sells up to `amount` from eligible buckets (respecting the available-for-taxes/expenses flag
    /// and each account's reserve), realizing a proportional long-term gain and reducing basis
    /// proportionally. Returns the cash raised and the realized gain (taxed at the LTCG schedule).
    static func sell(amount: Double, from buckets: inout [TaxableBucket], forTaxes: Bool) -> (raised: Double, realizedGain: Double) {
        guard amount > 0 else { return (0, 0) }
        let eligible = buckets.indices.filter {
            forTaxes ? buckets[$0].input.availableForConversionTaxes : buckets[$0].input.availableForExpenses
        }
        var remaining = amount
        var gain = 0.0
        for i in order(eligible, buckets) {
            guard remaining > 0 else { break }
            let take = min(remaining, buckets[i].availableBalance)
            guard take > 0 else { continue }
            gain += take * buckets[i].gainFraction
            let basisFraction = buckets[i].balance > 0 ? buckets[i].costBasis / buckets[i].balance : 0
            buckets[i].costBasis -= take * basisFraction
            buckets[i].balance -= take
            remaining -= take
        }
        return (amount - remaining, gain)
    }
}
