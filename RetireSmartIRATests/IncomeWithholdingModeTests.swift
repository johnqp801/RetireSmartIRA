//
//  IncomeWithholdingModeTests.swift
//  RetireSmartIRATests
//
//  Alan feedback #5b: for NON-Social-Security income sources, federal
//  withholding can be entered as either a dollar amount or a percentage of
//  the source's annual amount. This mirrors the #5a SS W-4V rate model, but
//  is a free-form percentage rather than a fixed IRS rate set, because
//  non-SS payers (pensions, IRAs, W-2 employers) accept arbitrary elections.
//
//  Back-compat is LAZY, same as #5a: legacy sources decode with
//  `federalWithholdingMode == nil`, which resolves as `.dollars` and keeps
//  the exact stored dollar `federalWithholding` — no silent data change, no
//  rebaseline of existing withholding/safe-harbor/quarterly tests.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Income Withholding Mode (Alan feedback #5b)")
struct IncomeWithholdingModeTests {

    // MARK: - (a) Percent mode resolves rate × income

    @Test("Non-SS source in .percent mode resolves 15% of a $40,000 pension to $6,000")
    func percentModeResolvesToDollars() {
        let source = IncomeSource(
            name: "Pension",
            type: .pension,
            annualAmount: 40_000,
            federalWithholdingMode: .percent,
            federalWithholdingPercent: 15
        )
        #expect(source.effectiveFederalWithholding == 6_000)
    }

    @MainActor
    @Test("totalFederalWithholding reflects the resolved percent-mode dollars")
    func totalFederalWithholdingReflectsPercent() {
        let manager = IncomeDeductionsManager()
        manager.incomeSources = [
            IncomeSource(
                name: "Pension",
                type: .pension,
                annualAmount: 40_000,
                federalWithholdingMode: .percent,
                federalWithholdingPercent: 15
            )
        ]
        #expect(manager.totalFederalWithholding == 6_000)
    }

    // MARK: - (b) Dollar mode / legacy (mode nil) unchanged

    @Test("Non-SS source in .dollars mode ignores percent; effective == stored dollars")
    func dollarsModeIsByteIdentical() {
        let source = IncomeSource(
            name: "Pension",
            type: .pension,
            annualAmount: 40_000,
            federalWithholding: 4_000,
            federalWithholdingMode: .dollars,
            federalWithholdingPercent: 50 // deliberately wrong-looking, must be ignored in .dollars mode
        )
        #expect(source.effectiveFederalWithholding == 4_000)
    }

    @Test("Legacy non-SS source (mode nil) keeps exact stored dollar withholding")
    func legacyModeNilKeepsExactDollars() {
        let source = IncomeSource(
            name: "Pension",
            type: .pension,
            annualAmount: 40_000,
            federalWithholding: 4_000
        )
        #expect(source.federalWithholdingMode == nil)
        #expect(source.effectiveFederalWithholding == 4_000)
    }

    @Test("Decoding legacy JSON without the new keys yields mode nil, percent 0, and exact dollars")
    func decodeLegacyJSONWithoutNewKeys() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Pension",
          "type": "Pension",
          "annualAmount": 40000,
          "federalWithholding": 4000,
          "stateWithholding": 0,
          "owner": "You"
        }
        """.data(using: .utf8)!

        let source = try JSONDecoder().decode(IncomeSource.self, from: json)
        #expect(source.federalWithholdingMode == nil)
        #expect(source.federalWithholdingPercent == 0)
        #expect(source.effectiveFederalWithholding == 4_000)
    }

    // MARK: - (c) percent 0

    @Test("Percent mode with 0% resolves to $0")
    func percentZeroResolvesToZero() {
        let source = IncomeSource(
            name: "Pension",
            type: .pension,
            annualAmount: 40_000,
            federalWithholdingMode: .percent,
            federalWithholdingPercent: 0
        )
        #expect(source.effectiveFederalWithholding == 0)
    }

    // MARK: - (d) Round-trip

    @Test("Encoding then decoding a non-SS source preserves mode + percent")
    func roundTripPreservesModeAndPercent() throws {
        let original = IncomeSource(
            name: "IRA Distribution",
            type: .rmd,
            annualAmount: 20_000,
            federalWithholdingMode: .percent,
            federalWithholdingPercent: 10
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IncomeSource.self, from: data)
        #expect(decoded.federalWithholdingMode == .percent)
        #expect(decoded.federalWithholdingPercent == 10)
        #expect(decoded.effectiveFederalWithholding == 2_000)
    }

    // MARK: - (e) SS is unaffected — no interaction with the $/% toggle

    @Test("SS source with the $/% fields absent still resolves via ssWithholdingRate")
    func ssSourceUnaffectedByPercentFields() {
        let source = IncomeSource(
            name: "Social Security",
            type: .socialSecurity,
            annualAmount: 20_000,
            ssWithholdingRate: .twelve
        )
        #expect(source.federalWithholdingMode == nil)
        #expect(source.federalWithholdingPercent == 0)
        #expect(source.effectiveFederalWithholding == 2_400)
    }

    @Test("SS source with a stray percent mode set is still overridden by the SS rate (SS always wins)")
    func ssRateTakesPrecedenceOverPercentFields() {
        // Defensive: even if federalWithholdingMode/.percent were somehow set on an
        // SS source, the SS rate resolution path must take precedence per the
        // effectiveFederalWithholding contract (type == .socialSecurity check first).
        let source = IncomeSource(
            name: "Social Security",
            type: .socialSecurity,
            annualAmount: 20_000,
            ssWithholdingRate: .ten,
            federalWithholdingMode: .percent,
            federalWithholdingPercent: 50
        )
        #expect(source.effectiveFederalWithholding == 2_000)
    }
}
