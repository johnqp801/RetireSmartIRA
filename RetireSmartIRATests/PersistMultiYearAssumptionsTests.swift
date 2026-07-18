import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Persist MultiYearAssumptions", .serialized)
@MainActor
struct PersistMultiYearAssumptionsTests {

    private func ephemeralSuite() -> UserDefaults {
        UserDefaults(suiteName: "test-mya-\(UUID().uuidString)")!
    }

    @Test("assumptions round-trip through PersistenceManager")
    func roundTrips() {
        let suite = ephemeralSuite()
        let dm = DataManager(skipPersistence: true)
        dm.multiYearAssumptions.dismissedInsightKeys = ["survivor", "ssNudge"]
        dm.multiYearAssumptions.currentTaxableBalance = 250_000
        dm.multiYearAssumptions.terminalLiquidationTaxRate = 0.30
        PersistenceManager.saveAll(from: dm, defaults: suite)

        let reloaded = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: reloaded, defaults: suite)
        #expect(reloaded.multiYearAssumptions.dismissedInsightKeys == ["survivor", "ssNudge"])
        #expect(reloaded.multiYearAssumptions.currentTaxableBalance == 250_000)
        #expect(reloaded.multiYearAssumptions.terminalLiquidationTaxRate == 0.30)
    }

    @Test("missing key leaves default assumptions")
    func missingKeyDefaults() {
        let suite = ephemeralSuite()
        let dm = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: dm, defaults: suite)  // empty suite
        #expect(dm.multiYearAssumptions.dismissedInsightKeys.isEmpty)
        #expect(dm.multiYearAssumptions == MultiYearAssumptions())
    }

    // MARK: - I-2: eager load-time migration (final-review)
    //
    // A schema-0 plan carrying a non-empty legacy expense-override map must be migrated to
    // schema-1 the moment PersistenceManager.loadAll decodes it — NOT only lazily inside
    // MultiYearStrategyManager.attach(). attach() only runs once Multi-Year is opened; if a
    // schema-0 plan is edited and saved from a different tab first, saveAll would re-persist
    // schema 0 with an empty perYearOverrides map and no legacy key (encode(to:) never writes
    // legacyExpenseOverrides), silently erasing the legacy overrides. This test drives the real
    // schema-0-through-load-through-save path end to end.

    /// Writes a schema-0 MultiYearAssumptions blob (decode-only `perYearExpenseOverrides` key,
    /// no `perYearOverridesSchema` key) directly into `suite`, mirroring how `PerYearOverrideUpgradeTests`
    /// builds schema-0 fixtures, but persisted so `PersistenceManager.loadAll` decodes it.
    private func seedSchema0(legacy: [Int: Double], baselineAnnualExpenses: Double, into suite: UserDefaults) {
        let legacyJSON = legacy.map { "\"\($0.key)\":\($0.value)" }.joined(separator: ",")
        let json = """
        {"horizonEndAge":95,"cpiRate":0.0,"investmentGrowthRate":0.06,\
        "baselineAnnualExpenses":\(baselineAnnualExpenses),\
        "perYearExpenseOverrides":{\(legacyJSON)},\
        "terminalLiquidationTaxRate":0.22,"cliffBuffer":5000}
        """.data(using: .utf8)!
        suite.set(json, forKey: "multiYearAssumptions")
    }

    @Test("loadAll eagerly migrates a schema-0 legacy override before Multi-Year is ever opened")
    func loadAllMigratesEagerly() {
        let suite = ephemeralSuite()
        seedSchema0(legacy: [2030: 120_000], baselineAnnualExpenses: 100_000, into: suite)

        let dm = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: dm, defaults: suite)

        // Migrated in-memory at load time, not left schema-0 for attach() to fix lazily.
        #expect(dm.multiYearAssumptions.perYearOverridesSchema == 1)
        #expect(dm.multiYearAssumptions.perYearOverrides[2030]?.livingExpenses?.oneTimeAmount == 20_000)
        #expect(dm.multiYearAssumptions.legacyExpenseOverrides.isEmpty)
    }

    @Test("a schema-0 plan saved from a non-Multi-Year tab does not lose the legacy override")
    func saveBeforeMultiYearOpenedPreservesLegacyDelta() {
        let suite = ephemeralSuite()
        seedSchema0(legacy: [2030: 120_000], baselineAnnualExpenses: 100_000, into: suite)

        // Simulate: app launches, loadAll runs, user edits something in a non-Multi-Year tab and
        // triggers a save WITHOUT ever opening Multi-Year (so MultiYearStrategyManager.attach()
        // never runs). Prior to the I-2 fix this re-persisted schema 0 with an empty
        // perYearOverrides map and no legacy key, permanently losing the override.
        let dm = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: dm, defaults: suite)
        PersistenceManager.saveAll(from: dm, defaults: suite)

        // Reload (simulating the next launch) into a fresh DataManager.
        let reloaded = DataManager(skipPersistence: true)
        PersistenceManager.loadAll(into: reloaded, defaults: suite)

        #expect(reloaded.multiYearAssumptions.perYearOverridesSchema == 1)
        #expect(reloaded.multiYearAssumptions.perYearOverrides[2030]?.livingExpenses?.oneTimeAmount == 20_000)
    }
}
