import Testing
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

    func testMultiYearAssumptions_BackwardCompatible_Decoding() throws {
        // JSON without baselineAnnualExpenses or dismissedInsightKeys —
        // simulates a 1.9-internal save before Plan B added these fields.
        let oldJSON = """
        {
            "horizonEndAge": 95,
            "cpiRate": 0.025,
            "investmentGrowthRate": 0.06,
            "withdrawalOrderingRule": "tax_efficient",
            "stressTestEnabled": true,
            "perYearExpenseOverrides": {},
            "currentTaxableBalance": 250000,
            "currentHSABalance": 30000,
            "terminalLiquidationTaxRate": 0.22,
            "cliffBuffer": 5000
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(MultiYearAssumptions.self, from: oldJSON)

        XCTAssertEqual(decoded.baselineAnnualExpenses, 60_000, "Should default to 60K when missing from old saves")
        XCTAssertEqual(decoded.dismissedInsightKeys, [], "Should default to empty set when missing from old saves")
        XCTAssertEqual(decoded.horizonEndAge, 95)
        XCTAssertEqual(decoded.cpiRate, 0.025)
    }

    func testMultiYearAssumptions_RoundTrip_NewFields() throws {
        var original = MultiYearAssumptions()
        original.baselineAnnualExpenses = 75_000
        original.dismissedInsightKeys = ["ss-nudge-67-23k", "widow-stress-major"]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MultiYearAssumptions.self, from: data)

        XCTAssertEqual(decoded.baselineAnnualExpenses, 75_000)
        XCTAssertEqual(decoded.dismissedInsightKeys, ["ss-nudge-67-23k", "widow-stress-major"])
    }
}

@Suite("MultiYearAssumptions — new fields", .serialized)
struct MultiYearAssumptionsNewFieldsTests {

    @Test("terminalLiquidationTaxRate defaults to 0.22")
    func terminalLiquidationTaxRateDefault() {
        let a = MultiYearAssumptions.default
        #expect(a.terminalLiquidationTaxRate == 0.22)
    }

    @Test("cliffBuffer defaults to 5_000")
    func cliffBufferDefault() {
        let a = MultiYearAssumptions.default
        #expect(a.cliffBuffer == 5_000)
    }

    @Test("MultiYearAssumptions accepts override for terminalLiquidationTaxRate")
    func terminalLiquidationTaxRateOverride() {
        let a = MultiYearAssumptions(terminalLiquidationTaxRate: 0.32)
        #expect(a.terminalLiquidationTaxRate == 0.32)
    }

    @Test("MultiYearAssumptions accepts override for cliffBuffer")
    func cliffBufferOverride() {
        let a = MultiYearAssumptions(cliffBuffer: 10_000)
        #expect(a.cliffBuffer == 10_000)
    }
}
