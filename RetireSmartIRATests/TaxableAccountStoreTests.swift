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

    @Test("removing the last taxable account zeroes the legacy scalar (no phantom bucket)")
    func removeLastZeroesLegacyScalar() {
        let dm = DataManager()
        let a = TaxableAccount(name: "Brokerage", balance: 400_000, costBasis: 300_000)
        dm.taxableAccounts = [a]
        dm.multiYearAssumptions.currentTaxableBalance = 400_000   // stale legacy value
        dm.removeTaxableAccount(id: a.id)
        #expect(dm.taxableAccounts.isEmpty)
        #expect(dm.multiYearAssumptions.currentTaxableBalance == 0) // can't resurrect as a phantom
    }

    @Test("removing one of several taxable accounts leaves the rest")
    func removeOneKeepsOthers() {
        let dm = DataManager()
        let a = TaxableAccount(name: "A", balance: 100_000, costBasis: 100_000)
        let b = TaxableAccount(name: "B", balance: 200_000, costBasis: 200_000)
        dm.taxableAccounts = [a, b]
        dm.removeTaxableAccount(id: a.id)
        #expect(dm.taxableAccounts.map(\.name) == ["B"])
    }
}
