import XCTest
@testable import RetireSmartIRA

final class MultiYearAssumptionsTests: XCTestCase {

    func test_default_horizonEndAge_isNinetyFive() {
        XCTAssertEqual(MultiYearAssumptions.default.horizonEndAge, 95)
    }

    func test_default_cpiRate_is2Point5Percent() {
        XCTAssertEqual(MultiYearAssumptions.default.cpiRate, 0.025, accuracy: 0.0001)
    }

    func test_default_investmentGrowthRate_is6Percent() {
        XCTAssertEqual(MultiYearAssumptions.default.investmentGrowthRate, 0.06, accuracy: 0.0001)
    }

    func test_default_withdrawalOrderingRule_isTaxEfficient() {
        XCTAssertEqual(MultiYearAssumptions.default.withdrawalOrderingRule, .taxEfficient)
    }

    func test_default_stressTestEnabled_isTrue() {
        XCTAssertTrue(MultiYearAssumptions.default.stressTestEnabled)
    }

    func test_default_horizonEndAgeSpouse_isNil() {
        XCTAssertNil(MultiYearAssumptions.default.horizonEndAgeSpouse)
    }

    func test_default_perYearExpenseOverrides_isEmpty() {
        XCTAssertTrue(MultiYearAssumptions.default.perYearExpenseOverrides.isEmpty)
    }

    func test_default_currentTaxableBalance_isZero() {
        XCTAssertEqual(MultiYearAssumptions.default.currentTaxableBalance, 0)
    }

    func test_default_currentHSABalance_isZero() {
        XCTAssertEqual(MultiYearAssumptions.default.currentHSABalance, 0)
    }

    func test_codableRoundTrip_withOverrides() throws {
        var assumptions = MultiYearAssumptions.default
        assumptions.cpiRate = 0.03
        assumptions.investmentGrowthRate = 0.05
        assumptions.horizonEndAgeSpouse = 92
        assumptions.perYearExpenseOverrides = [2027: 120_000, 2030: 150_000]
        assumptions.currentTaxableBalance = 25_000
        assumptions.currentHSABalance = 8_000

        let data = try JSONEncoder().encode(assumptions)
        let decoded = try JSONDecoder().decode(MultiYearAssumptions.self, from: data)
        XCTAssertEqual(decoded, assumptions)
    }

    func test_horizonEndAge_forSpouse_returnsOverrideWhenSet() {
        var assumptions = MultiYearAssumptions.default
        assumptions.horizonEndAgeSpouse = 92
        XCTAssertEqual(assumptions.horizonEndAge(for: .primary), 95)
        XCTAssertEqual(assumptions.horizonEndAge(for: .spouse), 92)
    }

    func test_horizonEndAge_forSpouse_fallsBackToPrimaryWhenNoOverride() {
        let assumptions = MultiYearAssumptions.default
        XCTAssertEqual(assumptions.horizonEndAge(for: .primary), 95)
        XCTAssertEqual(assumptions.horizonEndAge(for: .spouse), 95)
    }
}
