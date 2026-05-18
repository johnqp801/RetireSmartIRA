import XCTest
@testable import RetireSmartIRA

final class LTCGHarvestingTests: XCTestCase {
    func test_top_MFJ_2026() {
        XCTAssertEqual(TaxCalculationEngine.ltcg0PercentTop(filingStatus: .marriedFilingJointly), 98_900, accuracy: 0.5)
    }
    func test_top_single_2026() {
        XCTAssertEqual(TaxCalculationEngine.ltcg0PercentTop(filingStatus: .single), 49_450, accuracy: 0.5)
    }
    func test_headroom_positive_whenBelowTop() {
        let h = TaxCalculationEngine.ltcg0PercentHeadroom(taxableIncome: 60_000, filingStatus: .marriedFilingJointly)
        XCTAssertEqual(h, 38_900, accuracy: 0.5)
    }
    func test_headroom_zero_whenAtTop() {
        let h = TaxCalculationEngine.ltcg0PercentHeadroom(taxableIncome: 98_900, filingStatus: .marriedFilingJointly)
        XCTAssertEqual(h, 0, accuracy: 0.5)
    }
    func test_headroom_zero_whenAboveTop() {
        let h = TaxCalculationEngine.ltcg0PercentHeadroom(taxableIncome: 120_000, filingStatus: .marriedFilingJointly)
        XCTAssertEqual(h, 0, accuracy: 0.5)
    }
    // Property: each $1 of conversion reduces headroom by exactly $1, clamped at 0.
    func test_property_conversionReducesHeadroomOneForOne() {
        let base = 60_000.0
        for delta in stride(from: 0.0, through: 40_000.0, by: 5_000.0) {
            let h0 = TaxCalculationEngine.ltcg0PercentHeadroom(taxableIncome: base, filingStatus: .marriedFilingJointly)
            let h1 = TaxCalculationEngine.ltcg0PercentHeadroom(taxableIncome: base + delta, filingStatus: .marriedFilingJointly)
            XCTAssertEqual(h0 - h1, min(delta, h0), accuracy: 0.5)
        }
    }
}
