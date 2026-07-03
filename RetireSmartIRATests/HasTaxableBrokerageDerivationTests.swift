// RetireSmartIRATests/HasTaxableBrokerageDerivationTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("hasTaxableBrokerage derivation")
struct HasTaxableBrokerageDerivationTests {
    @Test("derives from taxable accounts, not a stored toggle")
    func derives() {
        let dm = DataManager()
        dm.taxableAccounts = []
        #expect(dm.hasTaxableBrokerage == false)
        dm.taxableAccounts = [TaxableAccount(name: "B", balance: 100_000, costBasis: 100_000)]
        #expect(dm.hasTaxableBrokerage == true)
    }
}
