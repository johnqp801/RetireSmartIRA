//
//  SSWithholdingRateTests.swift
//  RetireSmartIRATests
//
//  Alan feedback #5a: Social Security federal withholding replaces the
//  free-form dollar entry with an IRS Form W-4V rate picker (None/7/10/12/22%).
//  The engine still consumes dollars — `effectiveFederalWithholding` resolves
//  the rate to dollars at the consumption point.
//
//  Back-compat is LAZY: legacy SS sources decode with `ssWithholdingRate ==
//  nil` and keep their exact stored dollar `federalWithholding` until the
//  user next edits the source. No eager snap-on-load, no silent data change,
//  no rebaseline of existing withholding/safe-harbor/quarterly tests.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("SS Withholding Rate (Alan feedback #5a)")
struct SSWithholdingRateTests {

    // MARK: - (a) Rate resolves to dollars, and flows through totalFederalWithholding

    @Test("SS source with .twelve rate resolves to 12% of the benefit")
    func twelvePercentResolvesToDollars() {
        let source = IncomeSource(
            name: "Social Security",
            type: .socialSecurity,
            annualAmount: 20_000,
            ssWithholdingRate: .twelve
        )
        #expect(source.effectiveFederalWithholding == 2_400)
    }

    @MainActor
    @Test("totalFederalWithholding reflects the resolved SS rate dollars")
    func totalFederalWithholdingReflectsRate() {
        let manager = IncomeDeductionsManager()
        manager.incomeSources = [
            IncomeSource(
                name: "Social Security",
                type: .socialSecurity,
                annualAmount: 20_000,
                ssWithholdingRate: .twelve
            )
        ]
        #expect(manager.totalFederalWithholding == 2_400)
    }

    // MARK: - (b) nearest-rate helper

    @Test("nearest(toFraction:) snaps 0.105 to the closer legal rate")
    func nearestSnapsToClosestRate() {
        // |0.105 - 0.10| = 0.005, |0.105 - 0.12| = 0.015 -> .ten is closer.
        #expect(SSWithholdingRate.nearest(toFraction: 0.105) == .ten)
    }

    @Test("nearest(toFraction:) matches an exact legal rate")
    func nearestMatchesExactRate() {
        #expect(SSWithholdingRate.nearest(toFraction: 0.07) == .seven)
    }

    @Test("nearest(toFraction:) maps zero to .none")
    func nearestMapsZeroToNone() {
        #expect(SSWithholdingRate.nearest(toFraction: 0) == .none)
    }

    // MARK: - (c) .none rate

    @Test(".none rate resolves to $0 regardless of benefit amount")
    func noneRateIsZero() {
        let source = IncomeSource(
            name: "Social Security",
            type: .socialSecurity,
            annualAmount: 30_000,
            ssWithholdingRate: .none
        )
        #expect(source.effectiveFederalWithholding == 0)
    }

    // MARK: - (d) LAZY back-compat

    @Test("Legacy SS source (rate nil) keeps exact stored dollar withholding")
    func legacySSSourceKeepsExactDollars() {
        let source = IncomeSource(
            name: "Social Security",
            type: .socialSecurity,
            annualAmount: 20_000,
            federalWithholding: 1_500,
            ssWithholdingRate: nil
        )
        #expect(source.effectiveFederalWithholding == 1_500)
    }

    @Test("Decoding legacy JSON without the ssWithholdingRate key yields rate == nil and exact dollars")
    func decodeLegacyJSONWithoutRateKey() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Social Security",
          "type": "Social Security",
          "annualAmount": 20000,
          "federalWithholding": 1500,
          "stateWithholding": 0,
          "owner": "You"
        }
        """.data(using: .utf8)!

        let source = try JSONDecoder().decode(IncomeSource.self, from: json)
        #expect(source.ssWithholdingRate == nil)
        #expect(source.effectiveFederalWithholding == 1_500)
    }

    // MARK: - (e) Round-trip

    @Test("Encoding then decoding an SS source preserves the rate")
    func roundTripPreservesRate() throws {
        let original = IncomeSource(
            name: "Social Security",
            type: .socialSecurity,
            annualAmount: 20_000,
            ssWithholdingRate: .ten
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IncomeSource.self, from: data)
        #expect(decoded.ssWithholdingRate == .ten)
        #expect(decoded.effectiveFederalWithholding == 2_000)
    }

    // MARK: - Non-SS unchanged

    @Test("Non-SS source ignores ssWithholdingRate entirely; effective == stored dollars")
    func nonSSSourceUnchanged() {
        let source = IncomeSource(
            name: "Pension",
            type: .pension,
            annualAmount: 40_000,
            federalWithholding: 6_000
        )
        #expect(source.effectiveFederalWithholding == 6_000)
    }
}
