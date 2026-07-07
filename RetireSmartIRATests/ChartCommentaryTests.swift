import Testing
@testable import RetireSmartIRA

@Suite("ChartCommentary")
struct ChartCommentaryTests {
    // Shared fixture: a YearRecommendation carrying only the fields these charts read.
    // Reused by every task in this suite.
    private func rec(_ year: Int, trad: Double = 0, roth: Double = 0, taxable: Double = 0,
                     tax: Double = 0, conv: Double = 0) -> YearRecommendation {
        YearRecommendation(year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: TaxBreakdown(federal: tax, state: 0, irmaa: 0, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: trad, roth: roth, taxable: taxable, hsa: 0),
            actions: conv > 0 ? [.rothConversion(amount: conv)] : [])
    }

    // MARK: - BalancesChart

    @Test("balances commentary: title + base, no band on empty")
    func balancesBase() {
        let c = BalancesChart(path: []).commentary
        #expect(c.title == "Account balances over time")
        #expect(c.body.contains("Traditional"))
        #expect(c.body.contains("Roth"))
        #expect(c.body.contains("taxable"))
        #expect(!c.body.lowercased().contains("shaded band"))
        #expect(!c.body.contains("\u{2014}"))   // never an em dash
    }

    @Test("balances commentary mentions the sensitivity band when present")
    func balancesBand() {
        let path = [rec(2026, trad: 100, roth: 10, taxable: 5)]
        let low  = [rec(2026, trad: 80,  roth: 8,  taxable: 4)]
        let high = [rec(2026, trad: 120, roth: 12, taxable: 6)]
        let chart = BalancesChart(path: path, pessimistic: low, optimistic: high)
        #expect(chart.hasBand)
        #expect(chart.commentary.body.contains("sensitivity"))
    }

    @Test("balances commentary notes the still-taxable Traditional balance when it leads")
    func balancesTraditionalLeads() {
        let chart = BalancesChart(path: [rec(2026, trad: 100, roth: 10, taxable: 5)])
        #expect(chart.commentary.body.contains("still faces income tax"))
    }
}
