import XCTest
@testable import RetireSmartIRA

final class WidowPlanningEngineTests: XCTestCase {
    func test_survivorPaysMoreThanMFJ_atModerateIncome() {
        let mfj = TaxCalculationEngine.widowMFJAnnualTax(rmdIncome: 120_000)
        let single = TaxCalculationEngine.widowSurvivorAnnualTax(rmdIncome: 120_000)
        XCTAssertGreaterThan(single, mfj)
    }
    func test_taxesEqual_atZeroIncome() {
        XCTAssertEqual(TaxCalculationEngine.widowMFJAnnualTax(rmdIncome: 0), 0, accuracy: 0.5)
        XCTAssertEqual(TaxCalculationEngine.widowSurvivorAnnualTax(rmdIncome: 0), 0, accuracy: 0.5)
    }
    func test_singleFilerBracketCompression_visibleAt100k() {
        let mfj = TaxCalculationEngine.widowMFJAnnualTax(rmdIncome: 100_000)
        let single = TaxCalculationEngine.widowSurvivorAnnualTax(rmdIncome: 100_000)
        XCTAssertGreaterThan(single - mfj, 1_000)
    }
}
