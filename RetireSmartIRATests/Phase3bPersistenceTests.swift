//
//  Phase3bPersistenceTests.swift
//  RetireSmartIRATests
//
//  PHASE 3b TASK 2 GATE: a save written before this phase decodes with no
//  user intervention and preserves current calculated behavior.
//
//  `Fixtures/pre-phase3b-save.json` is a genuine PersistenceManager.saveAll
//  encode of a spread of IncomeSource and IRAAccount rows, captured from a
//  real DataManager BEFORE IncomeSource/IRAAccount gained planStructure /
//  planSource (commit 4d829ef, see that file's own "_meta" header for the
//  capture method and what was normalised). Neither field name appears
//  anywhere in the fixture.
//
//  See docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
//  section 3.6, whose migration table is the source of every expected
//  classification below.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("PHASE 3b TASK 2 GATE: pre-3b persistence fixture")
struct Phase3bPersistenceTests {

    struct FixtureBlob {
        let incomeSources: [IncomeSource]
        let iraAccounts: [IRAAccount]
    }

    /// Loads the checked-in fixture and decodes its two sub-arrays through
    /// the SAME `JSONDecoder().decode([IncomeSource].self, ...)` /
    /// `decode([IRAAccount].self, ...)` calls `PersistenceManager.loadAll`
    /// uses in production, so this test exercises the real decode path, not
    /// a hand-rolled stand-in for it.
    static func loadFixture() throws -> FixtureBlob {
        let here = URL(fileURLWithPath: #filePath)
        let url = here.deletingLastPathComponent().appendingPathComponent("Fixtures/pre-phase3b-save.json")
        let data = try Data(contentsOf: url)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let incomeJSON = try #require(object["incomeSources"])
        let accountsJSON = try #require(object["iraAccounts"])
        let incomeData = try JSONSerialization.data(withJSONObject: incomeJSON)
        let accountsData = try JSONSerialization.data(withJSONObject: accountsJSON)
        let incomeSources = try JSONDecoder().decode([IncomeSource].self, from: incomeData)
        let iraAccounts = try JSONDecoder().decode([IRAAccount].self, from: accountsData)
        return FixtureBlob(incomeSources: incomeSources, iraAccounts: iraAccounts)
    }

    @Test("Every income source in the pre-3b fixture infers its classification per spec 3.6")
    func incomeSourcesInferClassification() throws {
        let blob = try Self.loadFixture()
        #expect(blob.incomeSources.count == 5, "fixture shape changed; update this test's expectations")
        let byName = Dictionary(uniqueKeysWithValues: blob.incomeSources.map { ($0.name, $0) })

        // `.rmd` is the one IncomeType spec 3.6 maps explicitly.
        let rmd = try #require(byName["RMD"])
        #expect(rmd.planStructure == .ira)
        #expect(rmd.planSource == .individual)

        // `.pension` is deliberately left unknown/unknown, prompted at the
        // presentation layer (out of scope for this task).
        let pension = try #require(byName["Pension"])
        #expect(pension.planStructure == .unknown)
        #expect(pension.planSource == .unknown)

        // Everything else -> unknown/unknown.
        let socialSecurity = try #require(byName["Social Security"])
        #expect(socialSecurity.planStructure == .unknown)
        #expect(socialSecurity.planSource == .unknown)

        let consulting = try #require(byName["Consulting"])
        #expect(consulting.planStructure == .unknown)
        #expect(consulting.planSource == .unknown)

        let interest = try #require(byName["Interest"])
        #expect(interest.planStructure == .unknown)
        #expect(interest.planSource == .unknown)
    }

    @Test("Every IRA account in the pre-3b fixture infers its classification per spec 3.6")
    func accountsInferClassification() throws {
        let blob = try Self.loadFixture()
        #expect(blob.iraAccounts.count == 5, "fixture shape changed; update this test's expectations")
        let byName = Dictionary(uniqueKeysWithValues: blob.iraAccounts.map { ($0.name, $0) })

        // `traditionalIRA` and `traditional401k` are the two AccountTypes
        // spec 3.6 maps explicitly.
        let traditionalIRA = try #require(byName["Traditional IRA"])
        #expect(traditionalIRA.planStructure == .ira)
        #expect(traditionalIRA.planSource == .individual)

        let traditional401k = try #require(byName["401k"])
        #expect(traditional401k.planStructure == .definedContribution)
        #expect(traditional401k.planSource == .privateEmployer)

        // Everything else -> unknown/unknown, INCLUDING an inherited IRA,
        // which carries the full separate inherited-IRA field set and is
        // deliberately not given special treatment by spec 3.6's table.
        let rothIRA = try #require(byName["Roth IRA"])
        #expect(rothIRA.planStructure == .unknown)
        #expect(rothIRA.planSource == .unknown)

        let roth401k = try #require(byName["Roth 401k"])
        #expect(roth401k.planStructure == .unknown)
        #expect(roth401k.planSource == .unknown)

        let inherited = try #require(byName["Inherited IRA"])
        #expect(inherited.planStructure == .unknown)
        #expect(inherited.planSource == .unknown)
        // Confirm decoding the new fields didn't disturb the inherited-IRA
        // fields already carried by this row.
        #expect(inherited.beneficiaryType == .spouse)
        #expect(inherited.decedentRBDStatus == .afterRBD)
        #expect(inherited.yearOfInheritance == 2023)
    }

    /// The real guarantee. `TaxCalculationEngine` does not consume
    /// planStructure/planSource in this phase (that lands in Task 3), so
    /// this proves the migration is tax-neutral today: computing state tax
    /// from the fixture's DECODED income sources must equal computing it
    /// from the SAME logical rows built fresh via `IncomeSource.init`,
    /// which never goes through `decodeIfPresent` at all. Equal output means
    /// decoding introduced no divergence in anything the engine reads.
    @Test("Computed state tax for the pre-3b fixture's income is unchanged by migration")
    func computedStateTaxUnchangedByMigration() throws {
        let blob = try Self.loadFixture()

        let freshSources: [IncomeSource] = [
            IncomeSource(name: "RMD", type: .rmd, annualAmount: 20_000, owner: .primary),
            IncomeSource(name: "Pension", type: .pension, annualAmount: 45_000,
                         federalWithholding: 4_000, owner: .primary),
            IncomeSource(name: "Social Security", type: .socialSecurity, annualAmount: 30_000,
                         owner: .spouse, ssWithholdingRate: .ten),
            IncomeSource(name: "Consulting", type: .consulting, annualAmount: 15_000, owner: .primary),
            IncomeSource(name: "Interest", type: .interest, annualAmount: 2_000, owner: .joint)
        ]

        func tax(for sources: [IncomeSource]) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: 82_000,
                forState: .newYork,
                filingStatus: .marriedFilingJointly,
                taxableSocialSecurity: 25_500,
                incomeSources: sources,
                currentAge: 68,
                enableSpouse: true,
                spouseBirthYear: 1960,
                currentYear: 2026
            )
        }

        let actual = tax(for: blob.incomeSources)
        let expected = tax(for: freshSources)
        #expect(actual == expected)
    }

    /// The existing 1.7.2 `.rothConversion` migration (PersistenceManager.swift
    /// lines ~430-462, IncomeModels.swift's `IncomeSource.init(from:)`)
    /// resolves `type` to `.other` and prefixes `name` with the sentinel
    /// BEFORE this task's planStructure/planSource decoding ever runs, since
    /// both live in the same `init(from:)` call. This is the case named
    /// explicitly in the task brief: a legacy-sentinel row must still decode
    /// planStructure/planSource correctly.
    @Test("A legacy .rothConversion-sentinel row still infers unknown/unknown")
    func legacySentinelRowInfersUnknown() throws {
        let json = """
        [
          {
            "id": "\(UUID().uuidString)",
            "name": "2025 conversion",
            "type": "Roth Conversion",
            "annualAmount": 40000,
            "federalWithholding": 0,
            "stateWithholding": 0,
            "owner": "You"
          }
        ]
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([IncomeSource].self, from: json)
        let legacy = try #require(decoded.first)
        #expect(legacy.type == .other)
        #expect(legacy.name.hasPrefix(IncomeSource.legacyRothConversionSentinelPrefix))
        #expect(legacy.planStructure == .unknown)
        #expect(legacy.planSource == .unknown)
    }
}
