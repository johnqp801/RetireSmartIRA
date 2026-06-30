import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("presentValue", .serialized)
struct PresentValueTests {
    @Test("discounts by (1+r)^-years") func discounts() {
        #expect(abs(EngineMath.presentValue(1000, yearsFromBase: 0, realDiscountRate: 0.03) - 1000) < 1e-9)
        #expect(abs(EngineMath.presentValue(1000, yearsFromBase: 10, realDiscountRate: 0.03) - 1000 / pow(1.03, 10)) < 1e-6)
    }
}
