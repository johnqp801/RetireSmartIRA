import XCTest
@testable import RetireSmartIRA

final class YearRecommendationTests: XCTestCase {

    private func sampleRec() -> YearRecommendation {
        YearRecommendation(
            year: 2026,
            agi: 150_000,
            acaMagi: 155_000,
            irmaaMagi: 150_000,
            taxableIncome: 120_000,
            taxBreakdown: TaxBreakdown(federal: 20_000, state: 5_000, irmaa: 0, acaPremiumImpact: -3_000),
            endOfYearBalances: AccountSnapshot(traditional: 480_000, roth: 220_000, taxable: 145_000, hsa: 38_000),
            actions: [.rothConversion(amount: 20_000), .hsaContribution(amount: 4_300)]
        )
    }

    func test_YearRecommendation_codableRoundTrip() throws {
        let rec = sampleRec()
        let data = try JSONEncoder().encode(rec)
        let decoded = try JSONDecoder().decode(YearRecommendation.self, from: data)
        XCTAssertEqual(decoded, rec)
    }

    func test_YearRecommendation_optionalAGIVariants_canBeNil() {
        let rec = YearRecommendation(
            year: 2030, agi: 100_000, acaMagi: nil, irmaaMagi: 100_000,
            taxableIncome: 85_000, taxBreakdown: .zero,
            endOfYearBalances: .zero, actions: []
        )
        XCTAssertNil(rec.acaMagi)
        XCTAssertNotNil(rec.irmaaMagi)
    }

    func test_YearRecommendation_optionalAGIVariants_bothCanBeNil() {
        let rec = YearRecommendation(
            year: 2050, agi: 50_000, acaMagi: nil, irmaaMagi: nil,
            taxableIncome: 30_000, taxBreakdown: .zero,
            endOfYearBalances: .zero, actions: []
        )
        XCTAssertNil(rec.acaMagi)
        XCTAssertNil(rec.irmaaMagi)
    }

    func test_YearRecommendation_actionsArray_preservesOrder() {
        let rec = sampleRec()
        XCTAssertEqual(rec.actions.count, 2)
        if case .rothConversion = rec.actions[0] { } else { XCTFail("expected rothConversion first") }
        if case .hsaContribution = rec.actions[1] { } else { XCTFail("expected hsaContribution second") }
    }

    func test_YearRecommendation_emptyActionsArray() {
        let rec = YearRecommendation(
            year: 2040, agi: 80_000, acaMagi: nil, irmaaMagi: 80_000,
            taxableIncome: 60_000, taxBreakdown: .zero,
            endOfYearBalances: .zero, actions: []
        )
        XCTAssertTrue(rec.actions.isEmpty)
    }
}
