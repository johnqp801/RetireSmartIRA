// RetireSmartIRATests/PerYearOverrideMigrationTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("Per-year override migration")
struct PerYearOverrideMigrationTests {
    // baseline $100k, cpi 0 → originalBaseline(any year) == 100k
    @Test("legacy absolute total migrates to additive delta (legacy - baseline)")
    func legacyToDelta() {
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [2030: 120_000],
            baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(out[2030]?.livingExpenses?.oneTimeAmount == 20_000)
        #expect(out[2030]?.livingExpenses?.recurringLevel == nil)   // legacy never re-anchors
    }

    @Test("legacy below baseline yields a negative delta")
    func legacyBelow() {
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [2030: 60_000],
            baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(out[2030]?.livingExpenses?.oneTimeAmount == -40_000)
    }

    @Test("legacy equal to the CPI-grown baseline yields zero delta")
    func legacyEqualsGrownBaseline() {
        // baseline 100k, cpi 10%, 2 years → 121k; legacy 121k → delta 0
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [2028: 121_000],
            baselineAnnualExpenses: 100_000, cpiRate: 0.10, baseYear: 2026)
        #expect(abs((out[2028]?.livingExpenses?.oneTimeAmount ?? .nan)) < 0.001)
    }

    @Test("multiple legacy years all migrate")
    func multiple() {
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [2030: 120_000, 2031: 90_000],
            baselineAnnualExpenses: 100_000, cpiRate: 0, baseYear: 2026)
        #expect(out.count == 2)
        #expect(out[2030]?.livingExpenses?.oneTimeAmount == 20_000)
        #expect(out[2031]?.livingExpenses?.oneTimeAmount == -10_000)
    }

    @Test("empty legacy map migrates to empty (the production case)")
    func emptyStaysEmpty() {
        let out = PerYearOverrideMigration.migrate(
            legacyExpenseOverrides: [:], baselineAnnualExpenses: 100_000, cpiRate: 0.02, baseYear: 2026)
        #expect(out.isEmpty)
    }
}
