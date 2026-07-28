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

    /// Minimal archived-scenario JSON, matching the field set real saves contain.
    /// `fundingRaw == nil` omits the key entirely (a pre-field save).
    private func archivedJSON(fundingRaw: String?) -> Data {
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
            fields.append("\"rothTaxFundingMode\":\"\(raw)\"")
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
