import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("TaxPaymentSource assumption", .serialized)
struct TaxPaymentSourceTests {
    @Test("default is taxableThenGrossUp") func def() {
        #expect(MultiYearAssumptions().taxPaymentSource == .taxableThenGrossUp)
    }
    @Test("survives a Codable round-trip; legacy JSON without the key defaults") func codable() throws {
        var a = MultiYearAssumptions(); a.taxPaymentSource = .external
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(MultiYearAssumptions.self, from: data)
        #expect(back.taxPaymentSource == .external)
    }
}
