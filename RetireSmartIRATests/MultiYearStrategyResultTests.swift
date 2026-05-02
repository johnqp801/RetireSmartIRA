import XCTest
@testable import RetireSmartIRA

final class MultiYearStrategyResultTests: XCTestCase {

    func test_MultiYearStrategyResult_codableRoundTrip_emptyResult() throws {
        let result = MultiYearStrategyResult(
            recommendedPath: [],
            tradeOffsAccepted: [],
            sensitivityBands: SensitivityBands(optimistic: [], average: [], pessimistic: []),
            widowStressDelta: TaxImpact(baselineLifetimeTax: 312_000, scenarioLifetimeTax: 410_000),
            ssClaimNudge: nil
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(MultiYearStrategyResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func test_MultiYearStrategyResult_lifetimeTaxFromPath_sumsBreakdownTotals() {
        let years = [
            YearRecommendation(year: 2026, agi: 100_000, acaMagi: nil, irmaaMagi: nil, taxableIncome: 80_000,
                taxBreakdown: TaxBreakdown(federal: 10_000, state: 2_000, irmaa: 0, acaPremiumImpact: 0),
                endOfYearBalances: .zero, actions: []),
            YearRecommendation(year: 2027, agi: 110_000, acaMagi: nil, irmaaMagi: nil, taxableIncome: 90_000,
                taxBreakdown: TaxBreakdown(federal: 12_000, state: 2_500, irmaa: 0, acaPremiumImpact: 0),
                endOfYearBalances: .zero, actions: [])
        ]
        let result = MultiYearStrategyResult(
            recommendedPath: years,
            tradeOffsAccepted: [],
            sensitivityBands: SensitivityBands(optimistic: [], average: years, pessimistic: []),
            widowStressDelta: TaxImpact(baselineLifetimeTax: 0, scenarioLifetimeTax: 0),
            ssClaimNudge: nil
        )
        XCTAssertEqual(result.lifetimeTaxFromRecommendedPath, 26_500, accuracy: 0.01)
    }

    func test_MultiYearStrategyResult_emptyPath_lifetimeTaxIsZero() {
        let result = MultiYearStrategyResult(
            recommendedPath: [],
            tradeOffsAccepted: [],
            sensitivityBands: SensitivityBands(optimistic: [], average: [], pessimistic: []),
            widowStressDelta: TaxImpact(baselineLifetimeTax: 0, scenarioLifetimeTax: 0),
            ssClaimNudge: nil
        )
        XCTAssertEqual(result.lifetimeTaxFromRecommendedPath, 0)
    }

    func test_MultiYearStrategyResult_ssClaimNudge_canBeNonNil() {
        let flag = ClaimAgeFlag(spouse: .primary, currentClaimAge: 64, suggestedClaimAge: 67, estimatedLifetimeTaxDelta: -23_000)
        let result = MultiYearStrategyResult(
            recommendedPath: [],
            tradeOffsAccepted: [],
            sensitivityBands: SensitivityBands(optimistic: [], average: [], pessimistic: []),
            widowStressDelta: TaxImpact(baselineLifetimeTax: 0, scenarioLifetimeTax: 0),
            ssClaimNudge: flag
        )
        XCTAssertNotNil(result.ssClaimNudge)
        XCTAssertEqual(result.ssClaimNudge?.suggestedClaimAge, 67)
    }
}
