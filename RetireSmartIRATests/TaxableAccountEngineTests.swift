import Testing
@testable import RetireSmartIRA

@Suite("TaxableAccountEngine")
struct TaxableAccountEngineTests {
    private func input(bal: Double, basis: Double, ordYield: Double = 0, qDiv: Double = 0,
                       muni: Double = 0, ltGain: Double = 0, reserve: Double = 0,
                       expenses: Bool = true, taxes: Bool = true, priority: Int? = nil) -> TaxableAccountInput {
        TaxableAccountInput(balance: bal, costBasis: basis, protectedAmount: reserve,
            appreciationRate: 0, qualifiedDividendYield: qDiv, ordinaryIncomeYield: ordYield,
            taxExemptYield: muni, realizedLongTermGainYield: ltGain,
            availableForExpenses: expenses, availableForConversionTaxes: taxes, fundingPriority: priority)
    }
    private func bucket(_ i: TaxableAccountInput) -> TaxableBucket {
        TaxableBucket(balance: i.balance, costBasis: i.costBasis, input: i)
    }

    @Test("annualIncome splits by character; spendable cash sums available account income")
    func income() {
        let b = [bucket(input(bal: 100_000, basis: 50_000, ordYield: 0.02, qDiv: 0.03, muni: 0))]
        let r = TaxableAccountEngine.annualIncome(b)
        #expect(r.ordinary == 2_000)
        #expect(r.preferential == 3_000)
        #expect(r.taxExempt == 0)
        #expect(r.spendableCash == 5_000)
    }

    @Test("walled account income is taxed (counted) but not spendable")
    func walled() {
        let b = [bucket(input(bal: 100_000, basis: 100_000, ordYield: 0.04, expenses: false, taxes: false))]
        let r = TaxableAccountEngine.annualIncome(b)
        #expect(r.ordinary == 4_000)
        #expect(r.spendableCash == 0)
    }

    @Test("sell realizes proportional gain, reduces basis, respects reserve and funding order")
    func sell() {
        // A: 50% gain, priority 2.  B: 0% gain, priority 1 (used first).  Reserve 10k on B.
        var buckets = [
            bucket(input(bal: 100_000, basis: 50_000, priority: 2)),
            bucket(input(bal: 60_000, basis: 60_000, reserve: 10_000, priority: 1)),
        ]
        let out = TaxableAccountEngine.sell(amount: 70_000, from: &buckets, forTaxes: true)
        #expect(out.raised == 70_000)
        // B contributes its available 50k (no gain), A contributes 20k (50% gain = 10k).
        #expect(out.realizedGain == 10_000)
        #expect(buckets[1].balance == 10_000)              // B floored at its reserve
        #expect(abs(buckets[0].balance - 80_000) < 1e-6)
        #expect(abs(buckets[0].costBasis - 40_000) < 1e-6) // basis reduced proportionally
    }
}
