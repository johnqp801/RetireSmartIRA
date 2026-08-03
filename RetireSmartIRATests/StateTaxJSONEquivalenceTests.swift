import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("State tax JSON loader (Phase 1)")
struct StateTaxJSONLoaderTests {

    @Test("Loader returns all 51 jurisdictions")
    func loadsAllJurisdictions() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        #expect(configs.count == 51)
        for state in USState.allCases {
            #expect(configs[state] != nil, "missing \(state.abbreviation)")
        }
    }

    @Test("Loader throws for a tax year with no bundled data")
    func throwsForUnknownYear() {
        #expect(throws: (any Error).self) {
            try StateTaxDataLoader.load(taxYear: 1999)
        }
    }

    @Test("configs2026 static property is pre-populated with all 51 jurisdictions")
    func configs2026StaticPropertyLoads() {
        #expect(StateTaxDataLoader.configs2026.count == 51)
        for state in USState.allCases {
            #expect(StateTaxDataLoader.configs2026[state] != nil, "missing \(state.abbreviation)")
        }
    }

    // MARK: - Real-file survival checks (Task 9 item 5)
    //
    // The highest-value test here is that all 51 real bundled files genuinely
    // load and decode (loadsAllJurisdictions, above). These two go further:
    // they prove specific behaviorally-inert fields survive the ACTUAL file on
    // disk, not just a synthetic fixture. New Jersey's stepped phaseout upper
    // bound was nearly lost silently in Task 5 (an .infinity sentinel that a
    // naive Double decode would have turned into 0), so it is the highest-risk
    // field to re-check now that real, generated JSON is the input.

    @Test("New Jersey's pension exemption keeps its .infinity upper bound after loading the real bundled file")
    func newJerseyPensionExemptionInfinityUpperBoundSurvivesRealFile() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        let nj = try #require(configs[.newJersey])
        guard case .steppedPhaseoutByFilingStatus(_, _, let tiers) = nj.retirementExemptions.pensionExemption else {
            Issue.record("expected NJ pensionExemption to be steppedPhaseoutByFilingStatus, got \(nj.retirementExemptions.pensionExemption)")
            return
        }
        let lastTier = try #require(tiers.last)
        #expect(lastTier.upperBound.isInfinite, "NJ pensionExemption's last tier upperBound should be .infinity")
    }

    @Test("New Jersey's IRA withdrawal exemption keeps its .infinity upper bound after loading the real bundled file")
    func newJerseyIRAExemptionInfinityUpperBoundSurvivesRealFile() throws {
        let configs = try StateTaxDataLoader.load(taxYear: 2026)
        let nj = try #require(configs[.newJersey])
        guard case .steppedPhaseoutByFilingStatus(_, _, let tiers) = nj.retirementExemptions.iraWithdrawalExemption else {
            Issue.record("expected NJ iraWithdrawalExemption to be steppedPhaseoutByFilingStatus, got \(nj.retirementExemptions.iraWithdrawalExemption)")
            return
        }
        let lastTier = try #require(tiers.last)
        #expect(lastTier.upperBound.isInfinite, "NJ iraWithdrawalExemption's last tier upperBound should be .infinity")
    }

    // MARK: - estimatedPaymentSchedule quarters validation (Task 9 item 4)
    //
    // EstimatedPaymentSchedule's hand-written initializer enforces
    // `precondition(abs(q1+q2+q3+q4 - 1.0) < 0.001)`, but Codable's
    // compiler-synthesized init(from:) assigns stored properties directly and
    // bypasses that precondition entirely (PlanningModels.swift:100-113). The
    // table this loader replaces could never produce a bad schedule because
    // every instance went through the throwing initializer; JSON has no such
    // guarantee; a hand-edited or corrupted file could silently short (or
    // overpay) a whole state's estimated tax. This is the first code that
    // decodes the type from real files, so it is the first place the gap can
    // bite -- the loader must close it itself.

    @Test("decode throws a specific, state-naming error when estimatedPaymentSchedule quarters do not sum to 1.0")
    func decodeThrowsOnInvalidPaymentSchedule() throws {
        let malformed = Data("""
        {
            "state": "CA",
            "taxSystem": {"kind": "flat", "rate": 0.05},
            "retirementExemptions": {"socialSecurityExempt": true,
                                     "pensionExemption": {"kind": "none"},
                                     "iraWithdrawalExemption": {"kind": "none"}},
            "stateDeduction": {"kind": "none"},
            "estimatedPaymentSchedule": {"q1Pct": 0.5, "q2Pct": 0.5, "q3Pct": 0.5, "q4Pct": 0.5}
        }
        """.utf8)

        #expect(throws: StateTaxDataLoader.LoadError.self) {
            _ = try StateTaxDataLoader.decode(malformed, state: .california, taxYear: 2026)
        }

        do {
            _ = try StateTaxDataLoader.decode(malformed, state: .california, taxYear: 2026)
            Issue.record("expected decode to throw for a schedule summing to 2.0")
        } catch let error as StateTaxDataLoader.LoadError {
            guard case .invalidPaymentSchedule(let state, let taxYear, let sum) = error else {
                Issue.record("expected .invalidPaymentSchedule, got \(error)")
                return
            }
            #expect(state == .california)
            #expect(taxYear == 2026)
            #expect(abs(sum - 2.0) < 0.0001)
            #expect(error.errorDescription?.contains("CA") == true,
                    "error message should name the state, got: \(error.errorDescription ?? "nil")")
        } catch {
            Issue.record("expected StateTaxDataLoader.LoadError, got \(error)")
        }
    }

    @Test("decode succeeds when estimatedPaymentSchedule quarters sum to exactly 1.0")
    func decodeSucceedsOnValidPaymentSchedule() throws {
        let valid = Data("""
        {
            "state": "CA",
            "taxSystem": {"kind": "flat", "rate": 0.05},
            "retirementExemptions": {"socialSecurityExempt": true,
                                     "pensionExemption": {"kind": "none"},
                                     "iraWithdrawalExemption": {"kind": "none"}},
            "stateDeduction": {"kind": "none"},
            "estimatedPaymentSchedule": {"q1Pct": 0.30, "q2Pct": 0.40, "q3Pct": 0.0, "q4Pct": 0.30}
        }
        """.utf8)
        let config = try StateTaxDataLoader.decode(valid, state: .california, taxYear: 2026)
        #expect(config.state == .california)
    }

    @Test("decode throws a specific, state-naming error for malformed JSON")
    func decodeThrowsOnMalformedJSON() throws {
        let malformed = Data("not valid json at all".utf8)
        #expect(throws: StateTaxDataLoader.LoadError.self) {
            _ = try StateTaxDataLoader.decode(malformed, state: .wyoming, taxYear: 2026)
        }
    }
}

// MARK: - PHASE 1 GATE, Layer A: numeric equivalence

/// A scenario shaped to exercise the dimensions that differ between states:
/// SS taxability, pension and IRA exemptions, filing status, and bracket position.
private struct EquivalenceScenario {
    let name: String
    let income: Double
    let filingStatus: FilingStatus
    let taxableSocialSecurity: Double
    let retirementDistributions: Double
    let rothConversion: Double
    let primaryAge: Int
    let spouseAge: Int
    /// Exercises the NJ personal-exemption path, which is the only current
    /// consumer of postExemptionDeduction and is dropped entirely by the
    /// multi-year engine (backlog I2). Phase 1 only proves the migration is
    /// faithful; I2 itself is corrected in Phase 5d.
    let postExemptionDeduction: Double
}

@Suite("PHASE 1 GATE: JSON configs are behaviorally identical to the legacy table")
struct StateTaxJSONEquivalenceTests {

    /// Deliberately spans the age, income and filing-status boundaries where
    /// the 2026-08-02 audit found defects, so the migration is proven across
    /// the same surface those defects live on.
    private static let scenarios: [EquivalenceScenario] = [
        .init(name: "modest single 67", income: 40_000, filingStatus: .single,
              taxableSocialSecurity: 12_000, retirementDistributions: 20_000, rothConversion: 0,
              primaryAge: 67, spouseAge: 67, postExemptionDeduction: 0),
        .init(name: "modest MFJ 67", income: 80_000, filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 24_000, retirementDistributions: 40_000, rothConversion: 0,
              primaryAge: 67, spouseAge: 67, postExemptionDeduction: 2_000),
        .init(name: "early retiree 57, below the 59.5 gate", income: 70_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 30_000, rothConversion: 25_000,
              primaryAge: 57, spouseAge: 57, postExemptionDeduction: 0),
        .init(name: "age-tier boundary 63", income: 90_000, filingStatus: .single,
              taxableSocialSecurity: 18_000, retirementDistributions: 40_000, rothConversion: 0,
              primaryAge: 63, spouseAge: 63, postExemptionDeduction: 0),
        .init(name: "mid single + conversion", income: 150_000, filingStatus: .single,
              taxableSocialSecurity: 30_000, retirementDistributions: 40_000, rothConversion: 60_000,
              primaryAge: 66, spouseAge: 66, postExemptionDeduction: 0),
        .init(name: "high MFJ + large conversion", income: 300_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 40_000, retirementDistributions: 60_000, rothConversion: 150_000,
              primaryAge: 70, spouseAge: 68, postExemptionDeduction: 2_000),
        .init(name: "mixed-age MFJ, one spouse under the gate", income: 120_000,
              filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 50_000, rothConversion: 0,
              primaryAge: 61, spouseAge: 56, postExemptionDeduction: 0),
        .init(name: "pension only MFJ", income: 95_000, filingStatus: .marriedFilingJointly,
              taxableSocialSecurity: 0, retirementDistributions: 95_000, rothConversion: 0,
              primaryAge: 68, spouseAge: 68, postExemptionDeduction: 2_000),
        .init(name: "zero income", income: 0, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              primaryAge: 65, spouseAge: 65, postExemptionDeduction: 0)
    ]

    @Test("Every jurisdiction computes identical state tax from JSON and from the legacy table",
          arguments: USState.allCases)
    func jsonMatchesLegacy(state: USState) throws {
        let jsonConfigs = try StateTaxDataLoader.load(taxYear: 2026)
        guard let jsonConfig = jsonConfigs[state],
              let legacyConfig = StateTaxData.configs2026Legacy[state] else {
            Issue.record("Missing config for \(state.abbreviation)")
            return
        }

        for scenario in Self.scenarios {
            func stateTax(using config: StateTaxConfig) -> Double {
                TaxCalculationEngine.calculateStateTax(
                    income: scenario.income,
                    forState: state,
                    filingStatus: scenario.filingStatus,
                    taxableSocialSecurity: scenario.taxableSocialSecurity,
                    incomeSources: [],
                    currentAge: scenario.primaryAge,
                    enableSpouse: scenario.filingStatus == .marriedFilingJointly,
                    spouseBirthYear: 2026 - scenario.spouseAge,
                    currentYear: 2026,
                    scenarioRetirementDistributions: scenario.retirementDistributions,
                    scenarioRothConversionAmount: scenario.rothConversion,
                    scenarioRothConversionWithholdingAmount: 0,
                    postExemptionDeduction: scenario.postExemptionDeduction,
                    localIncomeTaxRate: 0,
                    configOverride: config
                )
            }
            let fromJSON = stateTax(using: jsonConfig)
            let fromLegacy = stateTax(using: legacyConfig)
            #expect(
                fromJSON == fromLegacy,
                """
                \(state.abbreviation) / \(scenario.name): JSON \(fromJSON) != legacy \(fromLegacy).
                Phase 1 must change no computed value. This is a migration defect, \
                not a tax correction. Corrections happen in Phase 5.
                """
            )
        }
    }
}

// MARK: - PHASE 1 GATE, Layer B: structural equivalence (decode is lossless)
//
// Layer A proves the engine computes the same number from both configs, but
// a field the engine's scenario grid never happens to touch can still be
// lost, defaulted, or corrupted by decode without moving any computed value
// -- see the five worked examples in the Task 10 brief (NJ's .infinity
// sentinel, the NJ maxExempt cap swap, socialSecurityExempt falling back to
// its own default, a CodingKeys swap between two same-valued booleans, and
// safeHarborRule, which governs estimated-tax PENALTY timing and is never
// consulted by calculateStateTax at all). This layer closes that gap
// directly: encode both configs with the same settings and require the
// bytes to match. If decode silently substituted a default or dropped a
// field decode itself is aware of, the two objects diverge structurally
// even when `calculateStateTax` cannot tell the difference.

@Suite("PHASE 1 GATE: Layer B, structural equivalence (decode is lossless)")
struct StateTaxJSONStructuralEquivalenceTests {

    /// Matches the settings the Task 9 generator used to write the bundled
    /// files, so this is an apples-to-apples re-encoding, not a different
    /// serialization convention.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// First line at which two re-encoded JSON documents diverge, for a
    /// failure message that names the field instead of dumping two full
    /// documents.
    private static func firstDivergence(_ a: Data, _ b: Data) -> String {
        let aLines = String(decoding: a, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false)
        let bLines = String(decoding: b, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false)
        for i in 0..<max(aLines.count, bLines.count) {
            let al = i < aLines.count ? aLines[i].trimmingCharacters(in: .whitespaces) : "<missing line>"
            let bl = i < bLines.count ? bLines[i].trimmingCharacters(in: .whitespaces) : "<missing line>"
            if al != bl {
                return "line \(i): JSON=[\(al)] LEGACY=[\(bl)]"
            }
        }
        return "no line-level divergence found despite unequal Data (formatting-only difference?)"
    }

    @Test("Re-encoding the JSON-loaded config is byte-identical to re-encoding the legacy config",
          arguments: USState.allCases)
    func structurallyIdentical(state: USState) throws {
        let jsonConfigs = try StateTaxDataLoader.load(taxYear: 2026)
        guard let jsonConfig = jsonConfigs[state],
              let legacyConfig = StateTaxData.configs2026Legacy[state] else {
            Issue.record("Missing config for \(state.abbreviation)")
            return
        }

        let encoder = Self.makeEncoder()
        let jsonEncoded = try encoder.encode(jsonConfig)
        let legacyEncoded = try encoder.encode(legacyConfig)

        #expect(
            jsonEncoded == legacyEncoded,
            """
            \(state.abbreviation): re-encoding the JSON-loaded config does not byte-match \
            re-encoding the legacy config. Decode dropped, defaulted, or reordered a field \
            even though Layer A's computed-tax comparison can still pass.
            First divergence: \(Self.firstDivergence(jsonEncoded, legacyEncoded))
            """
        )
    }
}

// MARK: - PHASE 1 GATE, Layer C: key completeness (encode is complete)
//
// Layer B has a blind spot: a field that `encode(to:)` never writes at all
// is absent from BOTH re-encoded documents and compares equal, so Layer B
// cannot tell "correctly round-tripped" apart from "silently never
// serialized." This layer closes it independently of Layer B, by reading
// the real bundled file's raw top-level keys (not a decoded, default-filled
// `StateTaxConfig`) and requiring the set to match exactly -- catching both
// a key the encoder forgot and a stray key nothing consumes.

@Suite("PHASE 1 GATE: Layer C, key completeness (encode is complete)")
struct StateTaxJSONKeyCompletenessTests {

    /// Every top-level key `StateTaxConfig.encode(to:)` is expected to
    /// write, taken from its `CodingKeys` in StateTaxCodable.swift.
    private static let expectedTopLevelKeys: Set<String> = [
        "state", "taxSystem", "retirementExemptions", "stateDeduction",
        "estimatedPaymentSchedule", "safeHarborRule", "currentYearSafeHarborRate",
        "hsaContributionsTaxableForState", "traditionalIRAContributionsTaxableForState",
        "otherPreTaxDeductionsTaxableForState", "pretax401kContributionsTaxableForState",
        "capitalLossesClassIsolated", "verification"
    ]

    @Test("Each bundled JSON file's top-level keys exactly match the expected set, no more, no fewer",
          arguments: USState.allCases)
    func exactTopLevelKeySet(state: USState) throws {
        // Reads the real file through the loader's own bundle-resolution
        // logic (StateTaxDataLoader.fileURL), not a hand-written path guess,
        // so this stays true to what actually ships in the bundle.
        let url = try StateTaxDataLoader.fileURL(for: state, taxYear: 2026)
        let data = try Data(contentsOf: url)
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let object = raw as? [String: Any] else {
            Issue.record("\(state.abbreviation): top-level JSON at \(url.lastPathComponent) is not an object")
            return
        }

        let actualKeys = Set(object.keys)
        let missing = Self.expectedTopLevelKeys.subtracting(actualKeys).sorted()
        let unexpected = actualKeys.subtracting(Self.expectedTopLevelKeys).sorted()

        #expect(
            actualKeys == Self.expectedTopLevelKeys,
            """
            \(state.abbreviation) (\(url.lastPathComponent)): top-level keys diverge from the \
            expected set. Missing: \(missing). Unexpected: \(unexpected).
            """
        )
    }
}
