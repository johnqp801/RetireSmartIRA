import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("LadderRow", .serialized)
struct LadderRowTests {
    private func rec(year: Int, agi: Double, conv: Double, irmaaMagi: Double?, acaMagi: Double?) -> YearRecommendation {
        YearRecommendation(
            year: year, agi: agi, acaMagi: acaMagi, irmaaMagi: irmaaMagi, taxableIncome: agi,
            taxBreakdown: TaxBreakdown(federal: 0, state: 0, irmaa: irmaaMagi == nil ? 0 : 1, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: conv > 0 ? [.rothConversion(amount: conv)] : [],
            medicareEnrolledCount: irmaaMagi == nil ? 0 : 1)
    }

    @Test("row exposes year, conversion, agi and an IRMAA flag")
    func basics() {
        let row = LadderRow(rec(year: 2027, agi: 198_000, conv: 80_000, irmaaMagi: 198_000, acaMagi: nil))
        #expect(row.year == 2027)
        #expect(row.conversion == 80_000)
        #expect(row.agi == 198_000)
        #expect(row.hasIRMAASurcharge == true)
    }

    @Test("no conversion and no IRMAA reads clean")
    func clean() {
        let row = LadderRow(rec(year: 2030, agi: 60_000, conv: 0, irmaaMagi: nil, acaMagi: nil))
        #expect(row.conversion == 0)
        #expect(row.hasIRMAASurcharge == false)
        #expect(row.irmaaLabel == "")
    }

    @Test("IRMAA surcharge amount and label are surfaced")
    func irmaaAmount() {
        let r = YearRecommendation(
            year: 2028, agi: 300_000, acaMagi: nil, irmaaMagi: 300_000, taxableIncome: 300_000,
            taxBreakdown: TaxBreakdown(federal: 0, state: 0, irmaa: 8_400, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0),
            actions: [], medicareEnrolledCount: 2)
        let row = LadderRow(r)
        #expect(row.irmaaSurcharge == 8_400)
        #expect(row.hasIRMAASurcharge == true)
        #expect(row.irmaaLabel == "IRMAA +$8k")
    }
}
