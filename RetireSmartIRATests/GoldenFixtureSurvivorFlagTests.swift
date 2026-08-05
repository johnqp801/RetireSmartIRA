import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 5b Task 2. Pins that the TEST FIXTURE type `ClassifiedPensionSource`
/// can actually CARRY the survivor-benefit flag that Task 1 added to the
/// PRODUCTION type `RetirementPlanClassification`.
///
/// This suite exists because of a measured silent loss, not a hypothetical
/// one. Swift's synthesized `Codable` ignores unknown JSON keys without
/// error, so before the field was added a fixture writing
/// `"isSurvivorBenefit": true` decoded clean and carried nothing. That was
/// established by running `roundTripCarriesTheFlag` below against the
/// three-field version of the type: the row decoded and re-encoded as
/// `{"planSource":"federalCivilian","amount":50000,"planStructure":"definedBenefit"}`,
/// the key simply gone. Task 1's own Critical finding was a variant of the
/// same class (a `let` with a default value is excluded from the synthesized
/// `init(from:)`, so it too decoded as `nil` however the JSON was written).
///
/// Nothing CONSUMES the flag yet. `GoldenScenarioSingleYearTests
/// .singleYearStateTax` does not forward it, `PerSourceExemptionRule` has no
/// `matchIsSurvivorBenefit`, and no shipped state configuration matches on
/// it: that chain is Task 9's work. What these tests guarantee is that DC's
/// fixture is STATING the fact in structured form, so Task 9 has something
/// real to read rather than prose.
@Suite("Golden fixture survivor-benefit flag")
struct GoldenFixtureSurvivorFlagTests {

    static let survivorRowJSON = """
        {"amount": 50000, "planStructure": "definedBenefit", \
        "planSource": "federalCivilian", "isSurvivorBenefit": true}
        """

    static let ownPensionRowJSON = """
        {"amount": 50000, "planStructure": "definedBenefit", \
        "planSource": "federalCivilian"}
        """

    @Test("A fixture row that sets isSurvivorBenefit decodes it as true")
    func presentKeyDecodesAsTrue() throws {
        let row = try JSONDecoder().decode(
            ClassifiedPensionSource.self, from: Data(Self.survivorRowJSON.utf8))
        #expect(row.isSurvivorBenefit == true,
                """
                A fixture row that explicitly sets "isSurvivorBenefit": true decoded as \
                \(String(describing: row.isSurvivorBenefit)). The key is being silently \
                discarded, which is the exact failure this field was added to fix.
                """)
    }

    @Test("A fixture row that omits isSurvivorBenefit decodes it as nil")
    func absentKeyDecodesAsNil() throws {
        let row = try JSONDecoder().decode(
            ClassifiedPensionSource.self, from: Data(Self.ownPensionRowJSON.utf8))
        #expect(row.isSurvivorBenefit == nil,
                """
                A row with no isSurvivorBenefit key decoded as \
                \(String(describing: row.isSurvivorBenefit)) rather than nil. Every \
                pre-Phase-5b fixture row omits this key and must keep meaning "not \
                stated", never "false" and never "true".
                """)
    }

    @Test("A decode/encode round trip preserves isSurvivorBenefit")
    func roundTripCarriesTheFlag() throws {
        let row = try JSONDecoder().decode(
            ClassifiedPensionSource.self, from: Data(Self.survivorRowJSON.utf8))
        let reencoded = String(decoding: try JSONEncoder().encode(row), as: UTF8.self)
        #expect(reencoded.contains("isSurvivorBenefit"),
                """
                ClassifiedPensionSource silently DROPPED the isSurvivorBenefit key. \
                Re-encoded as: \(reencoded)
                """)
    }

    /// The fixture-level guard. The unit tests above prove the TYPE can carry
    /// the flag; this proves DC's actual bundled file does, end to end through
    /// `GoldenScenario.load`. Without it, someone could delete the field from
    /// the type and only the unit tests would notice, while DC's fixture went
    /// back to carrying its survivor stipulation in prose alone.
    ///
    /// Counts rather than names: DC-1 (age 55, fails the age gate), DC-2 (age
    /// 65), DC-3 (both MFJ spouses) and DC-4 (one of two spouses) contribute
    /// five survivor rows between them. DC-4's second row is the other
    /// spouse's OWN private pension and DC-5 is the holder's OWN federal
    /// civilian pension, so exactly two rows must carry no flag.
    @Test("DC's bundled fixture carries the survivor flag on its survivor rows and only those")
    func dcFixtureCarriesTheFlag() throws {
        let file = try GoldenScenario.load(abbreviation: "DC")
        let rows = file.scenarios.flatMap { $0.classifiedPensionSources ?? [] }
        let survivors = rows.filter { $0.isSurvivorBenefit == true }
        let unflagged = rows.filter { $0.isSurvivorBenefit == nil }

        #expect(survivors.count == 5,
                """
                DC's fixture carries \(survivors.count) survivor-flagged rows, expected 5. \
                If the flag stopped decoding, this is where it shows up: the JSON still \
                says "isSurvivorBenefit": true and the loaded value would be nil.
                """)
        #expect(unflagged.count == 2,
                """
                DC's fixture carries \(unflagged.count) unflagged rows, expected 2 (DC-4's \
                private-pension spouse and DC-5's own federal civilian pension). A third \
                would mean a survivor row lost its flag; a first would mean an own-pension \
                row wrongly gained one, which is the distinction DC's rule turns on.
                """)
        #expect(rows.allSatisfy { $0.isSurvivorBenefit != false },
                "No DC row should assert isSurvivorBenefit: false; absent means not stated.")
    }

    /// Every other bundled fixture predates the flag and must still decode
    /// with it absent. This is the regression that would catch a default of
    /// `false` (or `true`) creeping in, which would silently reclassify 50
    /// jurisdictions' worth of rows.
    @Test("No fixture outside DC carries a survivor flag")
    func onlyDCUsesTheFlagToday() throws {
        var offenders: [String] = []
        for abbreviation in GoldenScenarioCoverageTests.covered where abbreviation != "DC" {
            guard let file = try? GoldenScenario.load(abbreviation: abbreviation) else { continue }
            for scenario in file.scenarios {
                for row in scenario.classifiedPensionSources ?? []
                where row.isSurvivorBenefit != nil {
                    offenders.append("\(abbreviation) / \(scenario.name)")
                }
            }
        }
        #expect(offenders.isEmpty,
                """
                Rows outside DC now carry isSurvivorBenefit: \(offenders.joined(separator: ", ")). \
                That may be legitimate once another jurisdiction's survivor rule is written, \
                but it is a change a reviewer has to see, not a side effect.
                """)
    }
}
