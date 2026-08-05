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

    /// Expected flag, per CASE and per ROW POSITION within that case.
    ///
    /// Keyed on a distinguishing substring of each scenario's name rather than
    /// on its index, so reordering the fixture does not silently re-point an
    /// expectation at the wrong case. Each substring must match exactly one
    /// scenario, which `dcFixtureFlagsEachSurvivorRowByCase` asserts.
    ///
    /// `nil` means the key is absent, which is the only correct encoding for
    /// "not a survivor benefit": absent means not stated, and no row may
    /// assert `false`.
    static let dcExpectedFlags: [(nameContains: String, flags: [Bool?])] = [
        // DC-1: survivor, but aged 55, so the age gate makes it taxable. Still
        // a survivor benefit, and flagged, because it is the case that proves
        // the age gate does the work.
        ("age 55", [true]),
        // DC-2: survivor, 65, the District's own government pension.
        ("age 65 (62+)", [true]),
        // DC-3: MFJ, both spouses survivors.
        ("both survivors", [true, true]),
        // DC-4: survivor spouse, then the other spouse's OWN private pension.
        ("one spouse (65)", [true, nil]),
        // DC-5: the holder's OWN federal civilian pension. The designated
        // NEGATIVE of DC's survivor rule. It must never carry the flag.
        ("OWN federal civil service pension", [nil])
    ]

    /// The fixture-level guard. The unit tests above prove the TYPE can carry
    /// the flag; this proves DC's actual bundled file does, end to end through
    /// `GoldenScenario.load`. Without it, someone could delete the field from
    /// the type and only the unit tests would notice, while DC's fixture went
    /// back to carrying its survivor stipulation in prose alone.
    ///
    /// Asserts CASE IDENTITY, not totals. An earlier version of this test
    /// asserted only that the file carried five flagged rows and two unflagged
    /// ones, and that was not good enough: DC-1's row and DC-5's row are
    /// byte-identical apart from the flag, so SWAPPING the two leaves both
    /// counts unchanged and a count-based test green, with DC-5 (the survivor
    /// rule's designated negative) wrongly flagged and DC-1 wrongly bare. That
    /// swap is not hypothetical. It is the exact slip that happened while this
    /// fixture was being edited, caught by reading the file back rather than
    /// by any test. This version fails on it.
    @Test("DC's bundled fixture flags each survivor row, case by case, and never DC-5")
    func dcFixtureFlagsEachSurvivorRowByCase() throws {
        let file = try GoldenScenario.load(abbreviation: "DC")
        #expect(file.scenarios.count == Self.dcExpectedFlags.count,
                """
                DC's fixture has \(file.scenarios.count) scenarios, but this test carries \
                \(Self.dcExpectedFlags.count) expectations. A case was added or removed \
                without deciding what its survivor flag should be.
                """)

        for expectation in Self.dcExpectedFlags {
            let matches = file.scenarios.filter { $0.name.contains(expectation.nameContains) }
            #expect(matches.count == 1,
                    """
                    "\(expectation.nameContains)" matches \(matches.count) DC scenarios, \
                    expected exactly 1. A renamed case would otherwise drop out of this \
                    sweep silently, taking its flag assertion with it.
                    """)
            guard let scenario = matches.first else { continue }
            let flags = (scenario.classifiedPensionSources ?? []).map(\.isSurvivorBenefit)
            #expect(flags == expectation.flags,
                    """
                    DC / \(scenario.name)
                    survivor flags \(flags), expected \(expectation.flags).
                    A `true` where `nil` belongs means an OWN pension is being claimed as a \
                    survivor benefit, which is exactly the distinction D.C. Code \
                    47-1803.02(a)(2)(N)(ii) turns on.
                    """)
        }

        let rows = file.scenarios.flatMap { $0.classifiedPensionSources ?? [] }
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
            // `try`, not `try?`: a fixture that stops decoding must fail this
            // sweep, not drop out of it. Every abbreviation in `covered` is
            // guaranteed to load by
            // `GoldenScenarioCoverageTests.everyJurisdictionHasAFixture`, so
            // a throw here is a real regression, and swallowing it would make
            // this test quietly stop checking whatever file broke.
            let file = try GoldenScenario.load(abbreviation: abbreviation)
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
