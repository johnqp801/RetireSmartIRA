// RetireSmartIRATests/PerYearOverrideUpgradeTests.swift
import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Per-year override upgrade — idempotent & atomic")
struct PerYearOverrideUpgradeTests {
    /// Build a schema-0 assumptions blob carrying a legacy expense override, via JSON.
    private func schema0WithLegacy(_ legacy: [Int: Double]) throws -> MultiYearAssumptions {
        let legacyJSON = legacy.map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",")
        let json = "{\"horizonEndAge\":95,\"cpiRate\":0.0,\"investmentGrowthRate\":0.06,\"perYearExpenseOverrides\":{\(legacyJSON)},\"terminalLiquidationTaxRate\":0.22,\"cliffBuffer\":5000}".data(using: .utf8)!
        return try JSONDecoder().decode(MultiYearAssumptions.self, from: json)
    }

    @Test("schema-0 plan with a legacy override upgrades to the correct delta and stamps schema 1")
    func upgradesOnce() throws {
        let a = try schema0WithLegacy([2030: 120_000])
        #expect(a.perYearOverridesSchema == 0)
        let up = a.upgradedOverrides(baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(up.perYearOverridesSchema == 1)
        #expect(up.perYearOverrides[2030]?.livingExpenses?.oneTimeAmount == 20_000)
    }

    @Test("upgrading an already-upgraded plan is a no-op (never subtracts twice)")
    func idempotent() throws {
        let a = try schema0WithLegacy([2030: 120_000])
        let once = a.upgradedOverrides(baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        let twice = once.upgradedOverrides(baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(twice.perYearOverrides[2030]?.livingExpenses?.oneTimeAmount == 20_000)   // unchanged
        #expect(twice == once)
    }

    @Test("empty legacy (the production case) upgrades to empty + schema 1")
    func emptyUpgrades() throws {
        let a = try schema0WithLegacy([:])
        let up = a.upgradedOverrides(baselineAnnualExpenses: 100_000, cpiRate: 0.02, baseYear: 2026)
        #expect(up.perYearOverrides.isEmpty)
        #expect(up.perYearOverridesSchema == 1)
    }
}
