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

    // MARK: - TaxImpactChart

    @Test("tax-impact commentary: title + even when empty")
    func taxImpactEmpty() {
        let c = TaxImpactChart(plan: [], doingNothing: []).commentary
        #expect(c.title == "Cumulative tax: your plan vs doing nothing")
        #expect(c.body.lowercased().contains("even"))
        #expect(!c.body.contains("\u{2014}"))
    }

    @Test("tax-impact commentary reports the plan ahead when it pays less")
    func taxImpactAhead() {
        let plan    = [rec(2026, tax: 10_000), rec(2027, tax: 10_000)]   // cumulative 20k
        let nothing = [rec(2026, tax: 30_000), rec(2027, tax: 30_000)]   // cumulative 60k
        let c = TaxImpactChart(plan: plan, doingNothing: nothing).commentary
        #expect(c.body.lowercased().contains("ahead"))
    }

    // MARK: - ConversionLadderChart

    @Test("ladder commentary says none when there are no conversions")
    func ladderNone() {
        let c = ConversionLadderChart(path: [rec(2026, conv: 0), rec(2027, conv: 0)]).commentary
        #expect(c.title == "Modeled conversions by year")
        #expect(c.body.lowercased().contains("no roth conversions"))
        #expect(!c.body.contains("$"))   // no dollar amount when there are none
    }

    @Test("ladder commentary reports total and year count")
    func ladderReports() {
        let c = ConversionLadderChart(path: [rec(2026, conv: 50_000), rec(2027, conv: 50_000)]).commentary
        #expect(c.body.contains("$"))
        #expect(c.body.contains("2 years"))
    }

    // MARK: - ThresholdMapChart

    @Test("threshold commentary: title + base mentions medicare and brackets")
    func thresholdBase() {
        let c = ThresholdMapChart(path: [], magiLines: [], bracketLines: []).commentary
        #expect(c.title == "Income vs tax cliffs by year")
        #expect(c.body.lowercased().contains("medicare"))
        #expect(c.body.lowercased().contains("bracket"))
        #expect(!c.body.contains("\u{2014}"))
    }

    @Test("threshold commentary adds the stay-under note when lines are present")
    func thresholdLines() {
        let line = ThresholdMapChart.Line(id: "irmaa1", label: "IRMAA tier 1", value: 206_000)
        let c = ThresholdMapChart(path: [], magiLines: [line], bracketLines: []).commentary
        #expect(c.body.lowercased().contains("under a line"))
    }
}
