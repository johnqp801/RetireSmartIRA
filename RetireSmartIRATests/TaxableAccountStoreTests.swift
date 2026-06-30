import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("TaxableAccount store")
struct TaxableAccountStoreTests {
    @Test("DataManager forwards taxableAccounts to AccountsManager")
    func forwarding() {
        let dm = DataManager()
        #expect(dm.taxableAccounts.isEmpty)
        dm.taxableAccounts = [TaxableAccount(name: "Brokerage", balance: 100_000, costBasis: 80_000)]
        #expect(dm.taxableAccounts.count == 1)
        #expect(dm.accounts.taxableAccounts.count == 1)
    }
}
