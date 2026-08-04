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

@MainActor
@Suite("PHASE 3b TASK 2 GATE: pre-3b persistence fixture")
struct Phase3bPersistenceTests {

    struct FixtureBlob {
        let incomeSources: [IncomeSource]
        let iraAccounts: [IRAAccount]
    }

    /// Loads the checked-in fixture and decodes its two sub-arrays through
    /// the REAL production load path, `PersistenceManager.loadAll`, not a
    /// hand-rolled `JSONDecoder().decode(...)` call that merely happens to
    /// match `PersistenceManager.swift`'s own decode calls today. Routing
    /// through `loadAll` itself means this gate keeps covering production
    /// even if `loadAll` later gains a configured decoder or a post-decode
    /// fixup; a direct `JSONDecoder` call here would stay green while
    /// silently no longer proving anything about the shipped path.
    static func loadFixture() throws -> FixtureBlob {
        let here = URL(fileURLWithPath: #filePath)
        let url = here.deletingLastPathComponent().appendingPathComponent("Fixtures/pre-phase3b-save.json")
        let data = try Data(contentsOf: url)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let incomeJSON = try #require(object["incomeSources"])
        let accountsJSON = try #require(object["iraAccounts"])
        let incomeData = try JSONSerialization.data(withJSONObject: incomeJSON)
        let accountsData = try JSONSerialization.data(withJSONObject: accountsJSON)

        let defaults = UserDefaults(suiteName: "phase3b-persistence-fixture-\(UUID().uuidString)")!
        defaults.set(incomeData, forKey: PersistenceManager.StorageKey.incomeSources)
        defaults.set(accountsData, forKey: PersistenceManager.StorageKey.iraAccounts)
        let dm = DataManager()
        PersistenceManager.loadAll(into: dm, defaults: defaults)
        return FixtureBlob(incomeSources: dm.incomeSources, iraAccounts: dm.iraAccounts)
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

    /// `TaxCalculationEngine` does not consume planStructure/planSource in
    /// THIS phase (that lands in Task 4), so this proves the migration is
    /// tax-neutral today: computing state tax from the fixture's DECODED
    /// income sources must equal computing it from the SAME logical rows
    /// built fresh via `IncomeSource.init`, which never goes through
    /// `decodeIfPresent` at all. Equal output means decoding introduced no
    /// divergence in anything the engine reads FOR THIS FIXTURE.
    ///
    /// LIMITATION, proven by a reviewer's mutation and left here as the
    /// reason `computedStateTaxUnchangedByMigrationForAClassifiedNewYorkPension`
    /// below exists: the pre-3b fixture's `.pension` row carries no
    /// `planStructure`/`planSource` KEY at all, so it always takes the
    /// "key absent -> inferredFallback" branch of
    /// `PlanClassificationUserSaveDecoding.decode`, landing on
    /// `.unknown`/`.unknown` -- the exact same value `freshSources`' own
    /// classification-less `.pension` row resolves to via the identical
    /// inference function. The two sides therefore agree regardless of what
    /// decoding actually does with a PRESENT value: a reviewer mutated every
    /// decoded classification to a wrong value and this test still passed.
    /// It proves decode did not corrupt the OTHER fields; it does not prove
    /// classification decodes correctly, because nothing here reads
    /// `planStructure`/`planSource` for any tax purpose yet.
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

    // MARK: - Phase 3b Task 4, Step 5a: re-pointed at a scenario the migration gate can actually fail

    /// STEP 5a (folded in from Task 3's review, carried into Task 4): after
    /// this task, New York's Line 26 rule genuinely CONSUMES
    /// `planStructure`/`planSource` -- a wrong decoded classification now
    /// produces a wrong computed tax, which
    /// `computedStateTaxUnchangedByMigration` above cannot detect because its
    /// fixture never carries an explicit classification key. This test
    /// decodes a POST-3b saved row (explicit `"planStructure":
    /// "definedBenefit"`, `"planSource": "nyStateOrLocal"` keys present,
    /// unlike the pre-3b fixture) through the REAL `PersistenceManager.loadAll`
    /// path and asserts the computed New York tax matches a freshly
    /// constructed `IncomeSource` carrying the identical classification.
    /// Proven by mutation to actually discriminate (see the task report):
    /// corrupting the saved JSON's `planSource` to `"otherStateOrLocal"`
    /// (a real, valid `PlanSource` case -- New York's rule just does not
    /// match it) now changes the computed tax and fails this test, which it
    /// could not have done before this task.
    @Test("Computed New York tax for a classified saved pension row is unchanged by decoding through PersistenceManager")
    func computedStateTaxUnchangedByMigrationForAClassifiedNewYorkPension() throws {
        let classifiedJSON = """
        [
          {"id": "\(UUID().uuidString)", "name": "NYC Pension", "type": "Pension", "annualAmount": 45000,
           "federalWithholding": 4000, "stateWithholding": 0, "owner": "You",
           "planStructure": "definedBenefit", "planSource": "nyStateOrLocal"}
        ]
        """.data(using: .utf8)!

        let defaults = UserDefaults(suiteName: "phase3b-classified-ny-pension-\(UUID().uuidString)")!
        defaults.set(classifiedJSON, forKey: PersistenceManager.StorageKey.incomeSources)
        let dm = DataManager()
        PersistenceManager.loadAll(into: dm, defaults: defaults)

        let freshSources: [IncomeSource] = [
            IncomeSource(name: "NYC Pension", type: .pension, annualAmount: 45_000,
                         federalWithholding: 4_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .nyStateOrLocal)
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

        let decoded = dm.incomeSources
        #expect(decoded.count == 1)
        #expect(decoded.first?.planStructure == .definedBenefit)
        #expect(decoded.first?.planSource == .nyStateOrLocal)

        let actual = tax(for: decoded)
        let expected = tax(for: freshSources)
        #expect(actual == expected)
        // The load-bearing half: this is now a NON-TRIVIAL number (New
        // York's Line 26 excludes the full $45,000 pension), not $0 or an
        // unrelated coincidence -- confirms the assertion above is actually
        // exercising the per-source rule, not two sides that happen to agree
        // some other way.
        #expect(actual < tax(for: [
            IncomeSource(name: "NYC Pension", type: .pension, annualAmount: 45_000,
                         federalWithholding: 4_000, owner: .primary,
                         planStructure: .definedBenefit, planSource: .otherStateOrLocal)
        ]), "an uncapped NY government pension must compute LESS tax than the same pension classified as out-of-state (capped at $20,000)")
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

    // MARK: - Review fix: a corrupted user-saved row must not discard the rest

    /// REVIEW FIX PROOF. Before this fix, `IncomeSource.init(from:)` decoded
    /// `planStructure`/`planSource` with a bare `decodeIfPresent(...) ??
    /// inference`, which throws a typed `DecodingError` for a PRESENT but
    /// unrecognised raw value. `PersistenceManager.loadAll` wraps its
    /// `[IncomeSource]` decode in `try?` (`PersistenceManager.swift:161-163`),
    /// so that one bad row took down the whole array decode: FIVE rows in,
    /// ZERO rows out. This seeds a genuine `UserDefaults` suite (not a
    /// hand-rolled decode) with five income rows, one carrying a
    /// planStructure value no shipped build has ever written, and runs it
    /// through the real `PersistenceManager.loadAll`.
    @Test("A corrupted planStructure value on one saved income row does not discard the other four")
    func corruptedIncomeSourceRowDoesNotDiscardTheRest() throws {
        let corruptedJSON = """
        [
          {"id": "\(UUID().uuidString)", "name": "RMD", "type": "RMD", "annualAmount": 20000,
           "federalWithholding": 0, "stateWithholding": 0, "owner": "You",
           "planStructure": "notARealStructureFromAFutureBuild", "planSource": "individual"},
          {"id": "\(UUID().uuidString)", "name": "Pension", "type": "Pension", "annualAmount": 45000,
           "federalWithholding": 4000, "stateWithholding": 0, "owner": "You",
           "planStructure": "unknown", "planSource": "unknown"},
          {"id": "\(UUID().uuidString)", "name": "Social Security", "type": "Social Security", "annualAmount": 30000,
           "federalWithholding": 0, "stateWithholding": 0, "owner": "Spouse",
           "planStructure": "unknown", "planSource": "unknown"},
          {"id": "\(UUID().uuidString)", "name": "Consulting", "type": "Employment/Other Income", "annualAmount": 15000,
           "federalWithholding": 0, "stateWithholding": 0, "owner": "You",
           "planStructure": "unknown", "planSource": "unknown"},
          {"id": "\(UUID().uuidString)", "name": "Interest", "type": "Interest", "annualAmount": 2000,
           "federalWithholding": 0, "stateWithholding": 0, "owner": "Joint",
           "planStructure": "unknown", "planSource": "unknown"}
        ]
        """.data(using: .utf8)!

        let defaults = UserDefaults(suiteName: "phase3b-corrupted-income-row-\(UUID().uuidString)")!
        defaults.set(corruptedJSON, forKey: PersistenceManager.StorageKey.incomeSources)

        let dm = DataManager()
        PersistenceManager.loadAll(into: dm, defaults: defaults)

        #expect(dm.incomeSources.count == 5,
                "one corrupted row must not discard the other four; this is the bug the fix removes")
        let corrupted = try #require(dm.incomeSources.first { $0.name == "RMD" })
        #expect(corrupted.planStructure == .unknown,
                "an unrecognised raw value falls back to .unknown, not to the RMD inference or a thrown error")
        #expect(PlanClassificationUserSaveDecoding.unrecognisedClassificationEncountered,
                "the diagnostic flag must be set when a user-saved row carries an unrecognised classification")
    }

    /// Same proof, `IRAAccount` side (`AccountModels.swift`'s `init(from:)`
    /// gets the identical fix). One corrupted planSource on one of five
    /// accounts must not take the other four down with it.
    @Test("A corrupted planSource value on one saved account row does not discard the other four")
    func corruptedIRAAccountRowDoesNotDiscardTheRest() throws {
        let corruptedJSON = """
        [
          {"id": "\(UUID().uuidString)", "name": "Traditional IRA", "accountType": "Traditional IRA",
           "balance": 100000, "institution": "", "owner": "You",
           "planStructure": "ira", "planSource": "notARealSourceFromAFutureBuild"},
          {"id": "\(UUID().uuidString)", "name": "401k", "accountType": "Traditional 401(k)",
           "balance": 200000, "institution": "", "owner": "You",
           "planStructure": "definedContribution", "planSource": "privateEmployer"},
          {"id": "\(UUID().uuidString)", "name": "Roth IRA", "accountType": "Roth IRA",
           "balance": 50000, "institution": "", "owner": "Spouse",
           "planStructure": "unknown", "planSource": "unknown"},
          {"id": "\(UUID().uuidString)", "name": "Roth 401k", "accountType": "Roth 401(k)",
           "balance": 75000, "institution": "", "owner": "You",
           "planStructure": "unknown", "planSource": "unknown"},
          {"id": "\(UUID().uuidString)", "name": "Inherited IRA", "accountType": "Inherited Traditional IRA",
           "balance": 30000, "institution": "", "owner": "You",
           "planStructure": "unknown", "planSource": "unknown"}
        ]
        """.data(using: .utf8)!

        let defaults = UserDefaults(suiteName: "phase3b-corrupted-account-row-\(UUID().uuidString)")!
        defaults.set(corruptedJSON, forKey: PersistenceManager.StorageKey.iraAccounts)

        let dm = DataManager()
        PersistenceManager.loadAll(into: dm, defaults: defaults)

        #expect(dm.iraAccounts.count == 5,
                "one corrupted row must not discard the other four; this is the bug the fix removes")
        let corrupted = try #require(dm.iraAccounts.first { $0.name == "Traditional IRA" })
        #expect(corrupted.planSource == .unknown,
                "an unrecognised raw value falls back to .unknown, not to the IRA inference or a thrown error")
        #expect(PlanClassificationUserSaveDecoding.unrecognisedClassificationEncountered,
                "the diagnostic flag must be set when a user-saved row carries an unrecognised classification")
    }
}
