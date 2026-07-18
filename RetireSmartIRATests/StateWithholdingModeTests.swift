//
//  StateWithholdingModeTests.swift
//  RetireSmartIRATests
//
//  Alan feedback (2nd round): state withholding should support a percent entry
//  like federal already does (#5b). This mirrors `federalWithholdingMode` /
//  `federalWithholdingPercent` / `effectiveFederalWithholding` for state, reusing
//  the same $/% `FederalWithholdingMode` enum.
//
//  Difference from federal: there is no state analogue of the IRS W-4V SS rate
//  set, so `effectiveStateWithholding` applies the percent uniformly across ALL
//  source types (including Social Security) — a state percent election on an SS
//  source resolves as percent × amount, not via ssWithholdingRate (federal-only).
//
//  Back-compat is LAZY, same as federal: legacy sources decode with
//  `stateWithholdingMode == nil`, resolving as `.dollars` and keeping the exact
//  stored dollar `stateWithholding` — no silent data change, no rebaseline.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State Withholding Mode (Alan 2nd-round feedback)")
struct StateWithholdingModeTests {

    @Test("Source in state .percent mode resolves 5% of a $40,000 pension to $2,000")
    func percentModeResolvesToDollars() {
        let source = IncomeSource(
            name: "Pension", type: .pension, annualAmount: 40_000,
            stateWithholdingMode: .percent, stateWithholdingPercent: 5)
        #expect(source.effectiveStateWithholding == 2_000)
    }

    @MainActor
    @Test("totalStateWithholding reflects the resolved percent-mode dollars")
    func totalStateWithholdingReflectsPercent() {
        let manager = IncomeDeductionsManager()
        manager.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 40_000,
                         stateWithholdingMode: .percent, stateWithholdingPercent: 5)
        ]
        #expect(manager.totalStateWithholding == 2_000)
    }

    @Test("State .dollars mode ignores percent; effective == stored dollars")
    func dollarsModeIsByteIdentical() {
        let source = IncomeSource(
            name: "Pension", type: .pension, annualAmount: 40_000,
            stateWithholding: 1_500, stateWithholdingMode: .dollars, stateWithholdingPercent: 50)
        #expect(source.effectiveStateWithholding == 1_500)
    }

    @Test("Legacy source (state mode nil) keeps exact stored dollar state withholding")
    func legacyModeNilKeepsExactDollars() {
        let source = IncomeSource(
            name: "Pension", type: .pension, annualAmount: 40_000, stateWithholding: 1_500)
        #expect(source.stateWithholdingMode == nil)
        #expect(source.effectiveStateWithholding == 1_500)
    }

    @Test("Decoding legacy JSON without the new state keys yields mode nil, percent 0, exact dollars")
    func decodeLegacyJSONWithoutNewKeys() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Pension", "type": "Pension", "annualAmount": 40000,
          "federalWithholding": 4000, "stateWithholding": 1500, "owner": "You"
        }
        """.data(using: .utf8)!
        let source = try JSONDecoder().decode(IncomeSource.self, from: json)
        #expect(source.stateWithholdingMode == nil)
        #expect(source.stateWithholdingPercent == 0)
        #expect(source.effectiveStateWithholding == 1_500)
    }

    @Test("State percent mode with 0% resolves to $0")
    func percentZeroResolvesToZero() {
        let source = IncomeSource(
            name: "Pension", type: .pension, annualAmount: 40_000,
            stateWithholdingMode: .percent, stateWithholdingPercent: 0)
        #expect(source.effectiveStateWithholding == 0)
    }

    @Test("Encoding then decoding preserves state mode + percent")
    func roundTripPreservesModeAndPercent() throws {
        let original = IncomeSource(
            name: "IRA Distribution", type: .rmd, annualAmount: 20_000,
            stateWithholdingMode: .percent, stateWithholdingPercent: 10)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IncomeSource.self, from: data)
        #expect(decoded.stateWithholdingMode == .percent)
        #expect(decoded.stateWithholdingPercent == 10)
        #expect(decoded.effectiveStateWithholding == 2_000)
    }

    // Unlike federal (W-4V), a state percent election DOES apply to an SS source.
    @Test("State percent applies to a Social Security source (no state W-4V override)")
    func statePercentAppliesToSocialSecurity() {
        let source = IncomeSource(
            name: "Social Security", type: .socialSecurity, annualAmount: 20_000,
            ssWithholdingRate: .twelve,
            stateWithholdingMode: .percent, stateWithholdingPercent: 5)
        // Federal still uses the W-4V rate; state uses the percent election.
        #expect(source.effectiveFederalWithholding == 2_400)
        #expect(source.effectiveStateWithholding == 1_000)
    }

    // Federal and state withholding modes are independent.
    @Test("Federal percent + state dollars resolve independently on the same source")
    func federalAndStateModesAreIndependent() {
        let source = IncomeSource(
            name: "Pension", type: .pension, annualAmount: 40_000,
            stateWithholding: 800,
            federalWithholdingMode: .percent, federalWithholdingPercent: 15,
            stateWithholdingMode: .dollars, stateWithholdingPercent: 0)
        #expect(source.effectiveFederalWithholding == 6_000)
        #expect(source.effectiveStateWithholding == 800)
    }
}
