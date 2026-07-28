import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("RothTaxFundingMode assumption", .serialized)
struct TaxPaymentSourceTests {
    @Test("Default is account-funded")
    func defaultIsAccountFunded() {
        #expect(MultiYearAssumptions().rothTaxFundingMode == .fundedFromAccounts)
    }

    @Test("Round-trips through Codable")
    func roundTrips() throws {
        var a = MultiYearAssumptions(); a.rothTaxFundingMode = .paidFromOutsideMoney
        let back = try JSONDecoder().decode(
            MultiYearAssumptions.self, from: try JSONEncoder().encode(a))
        #expect(back.rothTaxFundingMode == .paidFromOutsideMoney)
    }
}
