// RetireSmartIRATests/MultiYearAssumptionsOverrideCodableTests.swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("MultiYearAssumptions per-year override Codable")
struct MultiYearAssumptionsOverrideCodableTests {
    @Test("round-trips perYearOverrides and schema")
    func roundTrip() throws {
        var a = MultiYearAssumptions()
        a.perYearOverrides = [2030: YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: 40_000))]
        a.perYearOverridesSchema = 1
        let data = try JSONEncoder().encode(a)
        let back = try JSONDecoder().decode(MultiYearAssumptions.self, from: data)
        #expect(back.perYearOverrides[2030]?.livingExpenses?.recurringLevel == 90_000)
        #expect(back.perYearOverrides[2030]?.livingExpenses?.oneTimeAmount == 40_000)
        #expect(back.perYearOverridesSchema == 1)
    }

    @Test("legacy JSON without the new keys decodes to empty overrides + schema 0")
    func legacyDecode() throws {
        // A minimal older blob missing perYearOverrides / schema (and using the OLD key, which is
        // ignored). Includes the other fields the existing decoder already requires unconditionally
        // (withdrawalOrderingRule, stressTestEnabled, currentTaxableBalance, currentHSABalance) —
        // unrelated to this feature but necessary for this blob to decode at all.
        let json = #"{"horizonEndAge":95,"cpiRate":0.025,"investmentGrowthRate":0.06,"withdrawalOrderingRule":"tax_efficient","stressTestEnabled":true,"perYearExpenseOverrides":{},"currentTaxableBalance":0,"currentHSABalance":0,"terminalLiquidationTaxRate":0.22,"cliffBuffer":5000}"#.data(using: .utf8)!
        let back = try JSONDecoder().decode(MultiYearAssumptions.self, from: json)
        #expect(back.perYearOverrides.isEmpty)
        #expect(back.perYearOverridesSchema == 0)   // pre-feature marker → migration will run
    }
}
