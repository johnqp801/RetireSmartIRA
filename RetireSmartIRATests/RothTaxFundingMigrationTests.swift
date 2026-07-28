//
//  RothTaxFundingMigrationTests.swift
//  RetireSmartIRATests
//
//  V2.3: decoding saved scenarios written before the enum rename.
//  A silent fallback would change a saved plan's funding strategy without telling
//  anyone, which is worse than a loud failure. These tests pin that.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("MultiYearAssumptions funding-mode migration", .serialized)
struct RothTaxFundingMigrationTests {

    /// The key a pre-V2.3 build actually wrote. The property was renamed to
    /// `rothTaxFundingMode` in V2.3, so a genuinely old file on disk carries THIS spelling.
    private static let legacyKey = "taxPaymentSource"
    private static let currentKey = "rothTaxFundingMode"

    /// Minimal archived-scenario JSON, matching the field set real saves contain.
    /// `fundingRaw == nil` omits the key entirely (a pre-field save). `key` selects which
    /// JSON key carries the value, so tests can exercise the real legacy-file shape rather
    /// than only legacy VALUES written under the current key.
    private func archivedJSON(fundingRaw: String?, key: String = currentKey) -> Data {
        var fields: [String] = [
            "\"horizonEndAge\":95",
            "\"cpiRate\":0.025",
            "\"investmentGrowthRate\":0.06",
            "\"withdrawalOrderingRule\":\"tax_efficient\"",
            "\"stressTestEnabled\":true",
            "\"perYearExpenseOverrides\":{}",
            "\"currentTaxableBalance\":0",
            "\"currentHSABalance\":0",
            "\"terminalLiquidationTaxRate\":0.22",
            "\"cliffBuffer\":5000"
        ]
        if let raw = fundingRaw {
            fields.append("\"\(key)\":\"\(raw)\"")
        }
        return "{\(fields.joined(separator: ","))}".data(using: .utf8)!
    }

    private func decode(_ data: Data) throws -> MultiYearAssumptions {
        try JSONDecoder().decode(MultiYearAssumptions.self, from: data)
    }

    @Test("Legacy taxableThenGrossUp maps to fundedFromAccounts (behavior preserved)")
    func legacyGrossUpMigrates() throws {
        let a = try decode(archivedJSON(fundingRaw: "taxableThenGrossUp"))
        #expect(a.rothTaxFundingMode == .fundedFromAccounts)
    }

    @Test("Legacy external maps to paidFromOutsideMoney (behavior preserved)")
    func legacyExternalMigrates() throws {
        let a = try decode(archivedJSON(fundingRaw: "external"))
        #expect(a.rothTaxFundingMode == .paidFromOutsideMoney)
    }

    // MARK: - Real pre-V2.3 files, which carry the OLD key

    @Test("Old key with external decodes to paidFromOutsideMoney")
    func legacyKeyExternalMigrates() throws {
        // This is the shape a real pre-V2.3 save has on disk. Reading it as the default
        // would silently convert an outside-money plan into an account-funded one, which
        // is a materially different projection.
        let a = try decode(archivedJSON(fundingRaw: "external", key: Self.legacyKey))
        #expect(a.rothTaxFundingMode == .paidFromOutsideMoney)
    }

    @Test("Old key with taxableThenGrossUp decodes to fundedFromAccounts")
    func legacyKeyGrossUpMigrates() throws {
        let a = try decode(archivedJSON(fundingRaw: "taxableThenGrossUp", key: Self.legacyKey))
        #expect(a.rothTaxFundingMode == .fundedFromAccounts)
    }

    @Test("Old key with an unknown value still records the warning")
    func legacyKeyUnknownValueWarns() throws {
        MultiYearAssumptionsMigration.lastUnknownFundingModeRawValue = nil
        let a = try decode(archivedJSON(fundingRaw: "someRetiredMode", key: Self.legacyKey))
        #expect(MultiYearAssumptionsMigration.lastUnknownFundingModeRawValue == "someRetiredMode")
        #expect(a.rothTaxFundingMode == .fundedFromAccounts)
    }

    @Test("Current key wins when a file somehow carries both")
    func currentKeyWinsOverLegacy() throws {
        let json = """
        {"horizonEndAge":95,"cpiRate":0.025,"investmentGrowthRate":0.06,\
        "withdrawalOrderingRule":"tax_efficient","stressTestEnabled":true,\
        "currentTaxableBalance":0,"currentHSABalance":0,\
        "terminalLiquidationTaxRate":0.22,"cliffBuffer":5000,\
        "rothTaxFundingMode":"withheldFromConversion","taxPaymentSource":"external"}
        """.data(using: .utf8)!
        #expect(try decode(json).rothTaxFundingMode == .withheldFromConversion)
    }

    @Test("Absent field uses the existing default")
    func absentFieldDefaults() throws {
        let a = try decode(archivedJSON(fundingRaw: nil))
        #expect(a.rothTaxFundingMode == .fundedFromAccounts)
    }

    @Test("Current values decode normally")
    func currentValuesDecode() throws {
        #expect(try decode(archivedJSON(fundingRaw: "withheldFromConversion")).rothTaxFundingMode == .withheldFromConversion)
        #expect(try decode(archivedJSON(fundingRaw: "fundedFromAccounts")).rothTaxFundingMode == .fundedFromAccounts)
        #expect(try decode(archivedJSON(fundingRaw: "paidFromOutsideMoney")).rothTaxFundingMode == .paidFromOutsideMoney)
    }

    @Test("Unknown value records a migration warning instead of defaulting silently")
    func unknownValueWarns() throws {
        MultiYearAssumptionsMigration.lastUnknownFundingModeRawValue = nil
        // Simulates a scenario written by a FUTURE build, opened by this one.
        let a = try decode(archivedJSON(fundingRaw: "someFutureMode"))
        #expect(MultiYearAssumptionsMigration.lastUnknownFundingModeRawValue == "someFutureMode")
        // It still resolves to the safe default so the app stays usable.
        #expect(a.rothTaxFundingMode == .fundedFromAccounts)
    }

    @Test("Known values do NOT record a warning")
    func knownValuesDoNotWarn() throws {
        MultiYearAssumptionsMigration.lastUnknownFundingModeRawValue = nil
        _ = try decode(archivedJSON(fundingRaw: "taxableThenGrossUp"))
        #expect(MultiYearAssumptionsMigration.lastUnknownFundingModeRawValue == nil)
        _ = try decode(archivedJSON(fundingRaw: nil))
        #expect(MultiYearAssumptionsMigration.lastUnknownFundingModeRawValue == nil)
    }

    @Test("Round-trip encode/decode is stable")
    func roundTrips() throws {
        var a = MultiYearAssumptions()
        a.rothTaxFundingMode = .withheldFromConversion
        a.federalWithholdingRate = 0.22
        let back = try JSONDecoder().decode(
            MultiYearAssumptions.self,
            from: try JSONEncoder().encode(a))
        #expect(back.rothTaxFundingMode == .withheldFromConversion)
        #expect(back.federalWithholdingRate == 0.22)
    }

    @Test("Default assumption is the pre-V2.3 behavior")
    func defaultUnchanged() {
        #expect(MultiYearAssumptions().rothTaxFundingMode == .fundedFromAccounts)
        #expect(MultiYearAssumptions().federalWithholdingRate == 0.24)
    }
}
