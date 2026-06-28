import Testing
@testable import RetireSmartIRA

@Suite("BalancesChart")
struct BalancesChartTests {
    private func rec(_ year: Int, trad: Double, roth: Double, taxable: Double) -> YearRecommendation {
        YearRecommendation(year: year, agi: 0, acaMagi: nil, irmaaMagi: nil, taxableIncome: 0,
            taxBreakdown: .zero,
            endOfYearBalances: AccountSnapshot(traditional: trad, roth: roth, taxable: taxable, hsa: 0),
            actions: [])
    }

    @Test("maps per-year balances; band present only when bands supplied")
    func maps() {
        let path = [rec(2026, trad: 100, roth: 10, taxable: 5)]
        let plain = BalancesChart(path: path)
        #expect(plain.points.count == 1)
        #expect(plain.points[0].traditional == 100)
        #expect(plain.points[0].roth == 10)
        #expect(plain.points[0].taxable == 5)
        #expect(!plain.hasBand)
        #expect(plain.points[0].totalLow == nil)

        let banded = BalancesChart(
            path: path,
            pessimistic: [rec(2026, trad: 80, roth: 8, taxable: 4)],   // total 92
            optimistic:  [rec(2026, trad: 120, roth: 12, taxable: 6)]) // total 138
        #expect(banded.hasBand)
        #expect(banded.points[0].totalLow == 92)
        #expect(banded.points[0].totalHigh == 138)
    }
}
