import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite("TaxableAccount persistence")
struct TaxableAccountPersistenceTests {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "taxable-persist-\(UUID().uuidString)")!
    }

    @Test("saves and reloads taxable accounts")
    func roundTrip() {
        let d = freshDefaults()
        let dm = DataManager()
        dm.taxableAccounts = [TaxableAccount(name: "Brokerage", balance: 250_000, costBasis: 150_000)]
        PersistenceManager.saveAll(from: dm, defaults: d)

        let dm2 = DataManager()
        PersistenceManager.loadAll(into: dm2, defaults: d)
        #expect(dm2.taxableAccounts.count == 1)
        #expect(dm2.taxableAccounts[0].costBasis == 150_000)
    }

    @Test("migrates a legacy currentTaxableBalance into one account with basis=balance and confirm-basis flag")
    func migration() {
        let d = freshDefaults()
        // Model a true pre-feature save: the assumptions key (carrying a legacy taxable
        // balance) exists, but no taxableAccounts key was ever written. We persist ONLY the
        // assumptions blob rather than calling saveAll, which would write an empty-array key
        // and defeat the migration.
        let dm = DataManager()
        dm.multiYearAssumptions.currentTaxableBalance = 400_000
        let blob = try! JSONEncoder().encode(dm.multiYearAssumptions)
        d.set(blob, forKey: PersistenceManager.StorageKey.multiYearAssumptions)

        let dm2 = DataManager()
        PersistenceManager.loadAll(into: dm2, defaults: d)
        #expect(dm2.taxableAccounts.count == 1)
        let seeded = dm2.taxableAccounts[0]
        #expect(seeded.balance == 400_000)
        #expect(seeded.costBasis == 400_000)             // optimistic default, preserves behavior
        #expect(seeded.basisNeedsConfirmation == true)   // drives the "Confirm basis" badge
        #expect(seeded.availableForExpenses && seeded.availableForConversionTaxes)
    }
}
