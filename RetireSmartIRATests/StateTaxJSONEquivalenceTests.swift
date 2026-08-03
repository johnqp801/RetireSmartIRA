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

    // MARK: - Task 11: production path routing

    @Test("config(for:) reads JSON, not the legacy table")
    func productionPathUsesJSON() throws {
        // What this test can and cannot show: all 51 generated JSON files
        // carry exactly `.unverified`, and the legacy table's initializer
        // also defaults `verification` to `.unverified`, so a value-based
        // comparison of `.verification` (or any other field) cannot tell
        // JSON and legacy apart here -- both sides produce `.unverified ==
        // .unverified` regardless of which table actually served the
        // config. That is by design, not a test gap: the Phase 1 gate's
        // whole purpose (StateTaxJSONEquivalenceTests, this file) is
        // proving JSON and legacy compute identical values, so no
        // value-based assertion can ever distinguish which one supplied a
        // given config. The real evidence that `config(for:)` reads JSON is
        // by inspection: `StateTaxData.configs2026` is a one-line accessor
        // onto `StateTaxDataLoader.configs2026` (StateTaxData.swift), not a
        // copy or a re-derivation.
        let iowa = StateTaxData.config(for: .iowa)
        #expect(iowa.state == .iowa)

        // What this test DOES verify: config(for:) resolves every state to
        // itself and returns a well-formed config (checked via the JSON
        // loader's own output for the same state, so the two calls agree on
        // shape even though they cannot be told apart by value).
        let jsonIowa = try StateTaxDataLoader.load(taxYear: 2026)[.iowa]
        #expect(iowa.verification == jsonIowa?.verification)

        // Genuine, non-vacuous evidence that the loader path actually ran
        // and succeeded (rather than merely being present in the source):
        // force the static initializer, then assert no per-state fallback
        // occurred. This cannot exclude the accessor being rewired to some
        // other source, but it does prove the JSON load path executed and
        // read all 51 jurisdictions without falling back.
        _ = StateTaxDataLoader.configs2026
        #expect(StateTaxDataLoader.legacyFallbackFired == false,
                "the JSON load path ran and succeeded for all 51 jurisdictions")
    }

    @Test("config(for:) no longer substitutes California for an unknown state")
    func noCaliforniaSubstitution() {
        // Every USState case must resolve to itself, never to a stand-in.
        for state in USState.allCases {
            #expect(StateTaxData.config(for: state).state == state,
                    "\(state.abbreviation) resolved to a different jurisdiction")
        }
    }

    @Test("legacy fallback flag is false when the bundle loads cleanly")
    func legacyFallbackDidNotFireInNormalOperation() {
        // The bundled JSON is well-formed in this environment, so the
        // release-path fallback to configs2026Legacy should never engage.
        // Swift Testing parallelizes tests, so reading the flag alone would
        // be vacuous if nothing else happened to force configs2026's
        // static-let initializer first: an untouched loader also reads
        // `false`, and the test would pass proving nothing. Forcing the
        // initializer here is what makes this a real exercise of the flag
        // being wired into the real static-let initializer, not just
        // declared. The fallback-firing branch itself still cannot be
        // exercised here: it starts with a debug assertionFailure, which
        // traps the test process by design (see
        // StateTaxDataLoader.configs2026's doc comment).
        _ = StateTaxDataLoader.configs2026
        #expect(StateTaxDataLoader.legacyFallbackFired == false)
    }

    @Test("resolveConfigs reports no fallback states when the bundle loads cleanly")
    func resolveConfigsNoFallbackForRealBundle() {
        let result = StateTaxDataLoader.resolveConfigs(taxYear: 2026)
        #expect(result.fallbackStates.isEmpty)
        #expect(result.configs.count == 51)
    }

    @Test("resolveConfigs falls back each failing state to its OWN legacy entry, never a different state's, without touching the debug trap")
    func resolveConfigsFallsBackPerStateToItsOwnLegacyEntry() {
        // resolveConfigs is the fallback-assignment logic extracted out of
        // configs2026, specifically so it can be exercised without
        // triggering configs2026's assertionFailure, which traps the test
        // process by design and cannot be run inside a passing test.
        //
        // Tax year 1999 has no bundled files for any state (same seam as
        // throwsForUnknownYear above), so every state exercises the
        // fallback-assignment branch here.
        let result = StateTaxDataLoader.resolveConfigs(taxYear: 1999)

        #expect(Set(result.fallbackStates) == Set(USState.allCases),
                "expected every state to report a fallback for the nonexistent 1999 bundle")
        #expect(result.configs.count == 51,
                "the fallback assignment must still populate every state, not leave failures nil")

        for state in USState.allCases {
            // Decisive cross-contamination check: if the fallback ever
            // substituted a different state's legacy entry (the exact bug
            // this task removes from config(for:)), this would catch it,
            // because a wrong-state entry's .state would not equal `state`.
            #expect(result.configs[state]?.state == state,
                    "\(state.abbreviation)'s fallback entry resolved to a different jurisdiction")
            #expect(result.configs[state]?.verification == StateTaxData.configs2026Legacy[state]?.verification,
                    "\(state.abbreviation)'s fallback entry did not come from its OWN legacy config")
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
    /// A `.pension`-typed `IncomeSource` amount, when > 0. Defaults to 0 so
    /// the original 9 scenarios are unaffected.
    ///
    /// Every prior scenario passed `incomeSources: []`, which forces
    /// `pensionIncome == 0` at `TaxCalculationEngine.swift`'s
    /// `applyRetirementExemptions`, which in turn forces
    /// `excludedAmount(eligibleIncome: 0, ...)` to return 0 for every state's
    /// `pensionExemption` regardless of its configured cap or kind --
    /// `min(0, anything)` is always 0. That left `pensionExemption`
    /// completely unreached by Layer A for the 47 states where
    /// `pensionAndIRAShareSingleCap == false`, and for Arizona, Maryland,
    /// Maine, and Montana specifically -- whose ONLY non-`.none` exemption
    /// field is `pensionExemption` -- essentially nothing beyond
    /// `socialSecurityExempt` and `taxSystem` was exercised at all. This
    /// field closes that: set on the scenario below, large enough to bind
    /// New Jersey's $75,000 single-filer cap and each of AZ/MD/ME/MT's caps.
    var pensionIncome: Double = 0
}

@Suite("PHASE 1 GATE: JSON configs are behaviorally identical to the legacy table")
struct StateTaxJSONEquivalenceTests {

    /// Deliberately spans the age, income and filing-status boundaries where
    /// the 2026-08-02 audit found defects, so the migration is proven across
    /// the same surface those defects live on. The final scenario carries a
    /// `.pension`-typed `IncomeSource` specifically to reach `pensionExemption`
    /// (see `EquivalenceScenario.pensionIncome`'s doc comment for why the
    /// other 8 scenarios, all built with `incomeSources: []`, cannot).
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
              primaryAge: 65, spouseAge: 65, postExemptionDeduction: 0),
        // $80,000 pension income, age 65 (>= NJ's 62 minimum), total income
        // $95,000 (inside NJ's first phaseout band, so its retained
        // percentage is 100% and the $75,000 single cap is the only thing
        // doing any clamping). $80,000 also exceeds AZ's $2,500, MD's
        // $41,200, ME's $25,000, and MT's $4,640 caps, so this single
        // scenario binds all five states' pensionExemption fields at once.
        .init(name: "NJ pension cap binds; also exercises AZ/MD/ME/MT partial caps",
              income: 95_000, filingStatus: .single,
              taxableSocialSecurity: 0, retirementDistributions: 0, rothConversion: 0,
              primaryAge: 65, spouseAge: 65, postExemptionDeduction: 0,
              pensionIncome: 80_000)
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
            let incomeSources: [IncomeSource] = scenario.pensionIncome > 0
                ? [IncomeSource(name: "Pension", type: .pension, annualAmount: scenario.pensionIncome)]
                : []
            func stateTax(using config: StateTaxConfig) -> Double {
                TaxCalculationEngine.calculateStateTax(
                    income: scenario.income,
                    forState: state,
                    filingStatus: scenario.filingStatus,
                    taxableSocialSecurity: scenario.taxableSocialSecurity,
                    incomeSources: incomeSources,
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
//
// IMPORTANT -- this layer's validity depends on the encoder, and that
// dependency is not symmetric with Layer C: an `encode(to:)` field drop
// does not merely evade this layer, it BLINDS it for that field. Once a
// key is missing from both re-encoded documents, a *simultaneous*
// decode-side loss of the same field would also compare equal here --
// there is nothing left on either side for the bytes to disagree about.
// So encoder completeness is a PRECONDITION for this layer's validity, not
// an independent, parallel concern the way it might first read. The
// actual guard against an encode-side drop is the unit-level JSON-shape
// assertions in `StateTaxCodableRoundTripTests.swift`
// (`retirementExemptionsEncodesExpectedJSONShape`,
// `stateTaxConfigEncodesExpectedJSONShape`,
// `stateTaxConfigBooleanKeysAreMutuallyDistinguishable`), plus Layer C
// below for the outermost `StateTaxConfig` keys specifically.
//
// One more nuance worth recording here: encode-side completeness for 3 of
// the 13 top-level keys -- `taxSystem`, `retirementExemptions`, and
// `stateDeduction` -- currently rests on `StateTaxConfig.init(from:)` using
// required `c.decode(...)` for those three (StateTaxCodable.swift), not on
// any shape assertion, so a missing key throws instead of silently
// defaulting. A future maintainer relaxing those three to
// `decodeIfPresent(...) ?? someDefault`, matching every other field in that
// initializer, would remove the only guard for those keys without any test
// here failing.

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

// MARK: - PHASE 1 GATE, Layer C: file key completeness (the shipped data is complete)
//
// NAMING NOTE: this layer does NOT test the encoder, despite an earlier
// version of this comment implying it did. It reads the CHECKED-IN, already
// generated files from disk -- a code-only `encode(to:)` drop, with no
// regeneration, leaves those files untouched and this layer green. What it
// actually proves is that the 51 files that SHIP match the expected shape,
// which is a distinct question from "the encoder is correct in isolation."
//
// The layer this closes a blind spot in is Layer B, which has one: a field
// that `encode(to:)` never writes at all is absent from BOTH of Layer B's
// re-encoded documents and compares equal, so Layer B cannot tell "correctly
// round-tripped" apart from "silently never serialized." This layer closes
// that independently, by reading the real bundled file's raw top-level keys
// (not a decoded, default-filled `StateTaxConfig`) and requiring the set to
// match exactly -- catching both a key the encoder forgot to write into the
// shipped files and a stray key nothing consumes.
//
// The encoder's actual guard -- the thing that would catch a dropped
// `encode(to:)` line before it ever reaches a generated file -- is the
// unit-level JSON-shape assertions in `StateTaxCodableRoundTripTests.swift`:
// `retirementExemptionsEncodesExpectedJSONShape`,
// `stateTaxConfigEncodesExpectedJSONShape`, and
// `stateTaxConfigBooleanKeysAreMutuallyDistinguishable`. Weakening or
// deleting those tests would silently reopen the gap this layer's name
// might otherwise suggest it covers.

@Suite("PHASE 1 GATE: Layer C, file key completeness (the shipped data is complete)")
struct StateTaxJSONFileKeyCompletenessTests {

    /// Every top-level key expected in the SHIPPED, checked-in JSON files,
    /// taken from `StateTaxConfig`'s `CodingKeys` in StateTaxCodable.swift.
    /// This does not assert the encoder currently writes these keys (that is
    /// `StateTaxCodableRoundTripTests.swift`'s job); it asserts the files on
    /// disk today have them.
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
