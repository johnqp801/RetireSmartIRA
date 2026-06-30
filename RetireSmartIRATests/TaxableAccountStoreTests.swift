import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("TaxableAccount store")
struct TaxableAccountStoreTests {
    @Test("DataManager forwards taxableAccounts get/set to AccountsManager")
    func forwarding() {
        // Note: in DEBUG a fresh DataManager() loads demo data, which may migrate a legacy
        // balance into a seeded account — so we assert the forward, not initial emptiness.
        let dm = DataManager()
        let acct = TaxableAccount(name: "Brokerage", balance: 100_000, costBasis: 80_000)
        dm.taxableAccounts = [acct]
        #expect(dm.taxableAccounts.count == 1)
        #expect(dm.accounts.taxableAccounts.count == 1)
        #expect(dm.accounts.taxableAccounts[0].id == acct.id)
        dm.taxableAccounts = []
        #expect(dm.accounts.taxableAccounts.isEmpty)   // setter forwards clears too
    }
}
