// RetireSmartIRATests/TaxableAccountTests.swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("TaxableAccount")
struct TaxableAccountTests {
    @Test("availableBalance subtracts the reserve and floors at zero")
    func availableBalance() {
        var a = TaxableAccount(name: "Brokerage", balance: 300_000, costBasis: 200_000)
        a.protectedAmount = 250_000
        #expect(a.availableBalance == 50_000)
        a.protectedAmount = 400_000
        #expect(a.availableBalance == 0)
    }

    @Test("unrealizedGainFraction is gain over balance, zero when no gain or empty")
    func gainFraction() {
        let a = TaxableAccount(name: "B", balance: 100_000, costBasis: 70_000)
        #expect(abs(a.unrealizedGainFraction - 0.3) < 1e-9)
        let flat = TaxableAccount(name: "C", balance: 100_000, costBasis: 100_000)
        #expect(flat.unrealizedGainFraction == 0)
        let empty = TaxableAccount(name: "D", balance: 0, costBasis: 0)
        #expect(empty.unrealizedGainFraction == 0)
    }

    @Test("Codable round-trips all fields including new ones")
    func codable() throws {
        var a = TaxableAccount(name: "Muni", balance: 500_000, costBasis: 500_000)
        a.category = .muniBond
        a.taxExemptYield = 0.03
        a.fundingPriority = 2
        a.availableForConversionTaxes = false
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(TaxableAccount.self, from: data)
        #expect(back == a)
    }
}
