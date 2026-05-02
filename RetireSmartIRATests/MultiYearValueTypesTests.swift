import XCTest
@testable import RetireSmartIRA

final class MultiYearValueTypesTests: XCTestCase {

    // MARK: TaxBreakdown
    func test_TaxBreakdown_total_sumsAllComponents() {
        let b = TaxBreakdown(federal: 20_000, state: 5_000, irmaa: 2_000, acaPremiumImpact: -3_000)
        XCTAssertEqual(b.total, 24_000, accuracy: 0.01)
    }
    func test_TaxBreakdown_zero() {
        XCTAssertEqual(TaxBreakdown.zero.total, 0)
    }
    func test_TaxBreakdown_codableRoundTrip() throws {
        let b = TaxBreakdown(federal: 1, state: 2, irmaa: 3, acaPremiumImpact: 4)
        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(TaxBreakdown.self, from: data)
        XCTAssertEqual(decoded, b)
    }

    // MARK: ConstraintHit
    func test_ConstraintHit_codableRoundTrip() throws {
        let hit = ConstraintHit(year: 2027, type: .irmaaTier(level: 1), cost: 2_100, acceptanceRationale: "savings > cost")
        let data = try JSONEncoder().encode(hit)
        let decoded = try JSONDecoder().decode(ConstraintHit.self, from: data)
        XCTAssertEqual(decoded, hit)
    }

    // MARK: TaxImpact
    func test_TaxImpact_delta_isScenarioMinusBaseline() {
        let i = TaxImpact(baselineLifetimeTax: 312_000, scenarioLifetimeTax: 380_000)
        XCTAssertEqual(i.delta, 68_000, accuracy: 0.01)
    }
    func test_TaxImpact_negativeDelta_meansScenarioBetter() {
        let i = TaxImpact(baselineLifetimeTax: 400_000, scenarioLifetimeTax: 350_000)
        XCTAssertEqual(i.delta, -50_000, accuracy: 0.01)
    }
    func test_TaxImpact_codableRoundTrip() throws {
        let i = TaxImpact(baselineLifetimeTax: 100_000, scenarioLifetimeTax: 110_000)
        let data = try JSONEncoder().encode(i)
        let decoded = try JSONDecoder().decode(TaxImpact.self, from: data)
        XCTAssertEqual(decoded, i)
    }

    // MARK: ClaimAgeFlag
    func test_ClaimAgeFlag_initialization() {
        let flag = ClaimAgeFlag(spouse: .primary, currentClaimAge: 64, suggestedClaimAge: 67, estimatedLifetimeTaxDelta: -23_000)
        XCTAssertEqual(flag.spouse, .primary)
        XCTAssertEqual(flag.suggestedClaimAge, 67)
        XCTAssertEqual(flag.estimatedLifetimeTaxDelta, -23_000, accuracy: 0.01)
    }
    func test_ClaimAgeFlag_codableRoundTrip() throws {
        let flag = ClaimAgeFlag(spouse: .spouse, currentClaimAge: 66, suggestedClaimAge: 68, estimatedLifetimeTaxDelta: -8_500)
        let data = try JSONEncoder().encode(flag)
        let decoded = try JSONDecoder().decode(ClaimAgeFlag.self, from: data)
        XCTAssertEqual(decoded, flag)
    }

    // MARK: SensitivityBands
    func test_SensitivityBands_initialization_withEmptyArrays() {
        let bands = SensitivityBands(optimistic: [], average: [], pessimistic: [])
        XCTAssertTrue(bands.optimistic.isEmpty)
        XCTAssertTrue(bands.average.isEmpty)
        XCTAssertTrue(bands.pessimistic.isEmpty)
    }
}
