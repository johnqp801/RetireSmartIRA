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

    @Test("Year-keyed access returns the same configs as the 2026 accessor")
    func yearKeyedAccessMatches2026() throws {
        let byYear = StateTaxDataLoader.configs(for: 2026)
        #expect(byYear.count == 51)
        for state in USState.allCases {
            #expect(byYear[state]?.state == state, "\(state.abbreviation) mismatched")
        }
        // The memoized 2026 accessor and the year-keyed one must agree exactly.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for state in USState.allCases {
            let a = try encoder.encode(byYear[state])
            let b = try encoder.encode(StateTaxDataLoader.configs2026[state])
            #expect(a == b, "\(state.abbreviation) differs between accessors")
        }
    }

    @Test("Year-keyed access returns empty for a year with no bundled data")
    func yearKeyedAccessEmptyForUnknownYear() {
        #expect(StateTaxDataLoader.configs(for: 1999).isEmpty)
    }

    @Test("StateTaxData.config(for:taxYear:) resolves every state to itself")
    func stateTaxDataYearKeyedResolvesSelf() {
        for state in USState.allCases {
            #expect(StateTaxData.config(for: state, taxYear: 2026).state == state)
        }
    }

    // MARK: - Task 2 (Phase 2): constant-law extrapolation is observable

    @Test("Latest bundled tax year is 2026")
    func latestBundledYearIs2026() {
        #expect(StateTaxYearAvailability.latestBundledTaxYear == 2026)
    }

    @Test("Years at or before the latest bundled year are not extrapolated")
    func bundledYearsNotExtrapolated() {
        #expect(StateTaxYearAvailability.isExtrapolated(taxYear: 2026) == false)
        #expect(StateTaxYearAvailability.disclosure(forProjectionYear: 2026) == nil)
    }

    @Test("Years past the latest bundled year are disclosed as extrapolated")
    func futureYearsDisclosed() throws {
        #expect(StateTaxYearAvailability.isExtrapolated(taxYear: 2044) == true)
        let text = try #require(StateTaxYearAvailability.disclosure(forProjectionYear: 2044))
        #expect(text.contains("2026"), "the disclosure must name the year whose law is held constant")
        #expect(text.contains("2044"), "the disclosure must name the year being projected")
    }

    // MARK: - isBundledButUnloadable: the signal `configs(for:).isEmpty` alone cannot give
    //
    // `StateTaxDataLoader.load(taxYear:)` throws on the FIRST missing or
    // malformed jurisdiction file, and the year cache turns that throw into
    // an empty dictionary. A year that was never bundled and a year that WAS
    // bundled but has one broken file both produce `configs(for:).isEmpty ==
    // true`. Treating those as the same fact would let a disclosure tell a
    // user "assumes prior-year law" about a year whose law actually shipped
    // and merely failed to load -- a build defect masquerading as a
    // modeling choice. These tests hold the two apart.

    @Test("A genuinely unbundled year, with no files at all, is not reported as bundled-but-unloadable")
    func trulyUnbundledYearIsNotUnloadable() {
        // Tax year 1999 has zero bundled files for any of the 51
        // jurisdictions (same fixture year `throwsForUnknownYear` and
        // `yearKeyedAccessEmptyForUnknownYear` already use). Absence, not
        // breakage.
        #expect(StateTaxYearAvailability.isBundledButUnloadable(taxYear: 1999) == false)
    }

    @Test("The real 2026 bundle, which loads cleanly, is not reported as bundled-but-unloadable")
    func cleanlyLoadingYearIsNotUnloadable() {
        #expect(StateTaxYearAvailability.isBundledButUnloadable(taxYear: 2026) == false)
    }

    @Test("Pure decision logic: files present but the full load came back empty is a build defect, not an extrapolation")
    func brokenBundleLogicIsUnloadable() {
        // hasBundledData=true + empty configs is exactly the "shipped but
        // broke" shape that a single all-or-nothing `configs(for:).isEmpty`
        // check cannot distinguish from "never shipped".
        #expect(StateTaxYearAvailability.isBundledButUnloadable(hasBundledData: true, configs: [:]) == true)
        // No bundled files at all: not unloadable, just absent.
        #expect(StateTaxYearAvailability.isBundledButUnloadable(hasBundledData: false, configs: [:]) == false)
        // Files present AND the load actually produced something: not unloadable.
        let nonEmptyConfigs: [USState: StateTaxConfig] = [.california: StateTaxData.configs2026Legacy[.california]!]
        #expect(StateTaxYearAvailability.isBundledButUnloadable(hasBundledData: true, configs: nonEmptyConfigs) == false)
    }

    @Test("isBundledButUnloadable is a signal distinct from isExtrapolated: a broken current year is not extrapolated")
    func unloadableAndExtrapolatedAreIndependentSignals() {
        // A broken CURRENT year (taxYear == latestBundledTaxYear) is not "in
        // the future" relative to itself, so isExtrapolated must stay false
        // even when isBundledButUnloadable's pure logic would report true for
        // the same inputs. Phase 6 needs both facts, and needs them not to
        // collapse into one boolean.
        #expect(StateTaxYearAvailability.isExtrapolated(taxYear: StateTaxYearAvailability.latestBundledTaxYear) == false)
        #expect(StateTaxYearAvailability.isBundledButUnloadable(hasBundledData: true, configs: [:]) == true)
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

        var observedDivergence = false

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
            if fromJSON != fromLegacy {
                observedDivergence = true
            }
            // Phase 5 jurisdictions on `phase5CorrectedJurisdictions`
            // (StateTaxJSONStructuralEquivalenceTests, Layer B) are
            // DELIBERATELY corrected in the bundled JSON while
            // `configs2026Legacy` stays frozen at pre-Phase-5 law. This
            // scenario grid was written for Phase 1's pure-migration
            // guarantee and was never updated for that divergence, so a
            // corrected jurisdiction whose fix happens to be exercised by
            // one of these scenarios (Iowa's is; Kansas's personalExemption
            // fix is not, which is why Kansas alone never tripped this gate)
            // now legitimately disagrees with the frozen legacy table. The
            // golden fixture and the baseline movement ledger are the
            // authoritative, attributed record of what changed and why for
            // those states, so the per-scenario identity check is skipped
            // for them; see below the loop for what replaces it.
            if StateTaxJSONStructuralEquivalenceTests.phase5CorrectedJurisdictions.contains(state) {
                continue
            }
            #expect(
                fromJSON == fromLegacy,
                """
                \(state.abbreviation) / \(scenario.name): JSON \(fromJSON) != legacy \(fromLegacy).
                Phase 1 must change no computed value. This is a migration defect, \
                not a tax correction. Corrections happen in Phase 5.
                """
            )
        }

        // A blanket skip for every corrected jurisdiction would be too
        // coarse: it would also pass if a correction were silently reverted
        // from the bundled JSON, so long as the jurisdiction stayed on
        // `phase5CorrectedJurisdictions`. For jurisdictions where this
        // scenario grid is known to exercise the corrected field(s) --
        // listed in `layerAProvenDivergentJurisdictions` -- assert instead
        // that AT LEAST ONE scenario actually diverged, closing that hole.
        //
        // Kansas is deliberately NOT in that list: none of the 10 scenarios
        // above read `postExemptionDeduction` from config, so Kansas
        // computes identically through both tables whether its
        // `personalExemption` correction is present, reverted, or garbled.
        // A "must diverge" assertion would fail Kansas forever in its
        // correct state, so it stays on the plain skip above with no
        // further check here; its correction is guarded by Layer B
        // (`structurallyIdentical`) and Kansas's own targeted unit tests
        // instead. To slot in the next corrected jurisdiction: if this grid
        // exercises its corrected field(s), add it to
        // `layerAProvenDivergentJurisdictions` and it gets this assertion
        // for free; if not (Kansas's situation), leave it out and say why,
        // as here.
        if Self.layerAProvenDivergentJurisdictions.contains(state) {
            #expect(
                observedDivergence,
                """
                \(state.abbreviation) is listed in layerAProvenDivergentJurisdictions, \
                so at least one of the scenarios above must compute a different tax \
                from the JSON config than from the frozen legacy table. None diverged. \
                Either the correction was reverted from the bundled JSON, or this \
                scenario grid no longer exercises the corrected field -- both are \
                regressions to investigate, not silence.
                """
            )
        }
    }

    /// Corrected jurisdictions whose fix this Layer A scenario grid is known
    /// to exercise, so "at least one scenario diverges from the frozen
    /// legacy table" can be positively asserted rather than merely skipped.
    /// See the comment below the scenario loop in `jsonMatchesLegacy` for
    /// how this differs from `phase5CorrectedJurisdictions` and why Kansas
    /// is not here.
    ///
    /// - Iowa: Phase 5a Task 3 touches `scenarioRetirementDistributions`,
    ///   `scenarioRothConversionAmount`, `pensionIncome`, and
    ///   `primaryAge`/`spouseAge` directly, all of which this grid varies;
    ///   9 of its 10 scenarios (all but "zero income") diverge.
    static let layerAProvenDivergentJurisdictions: Set<USState> = [.iowa]
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

    /// PHASE 5 CORRECTED-JURISDICTIONS LIST. Append here, and only here, as
    /// each Phase 5 task corrects a jurisdiction's bundled JSON.
    ///
    /// `configs2026Legacy` (`StateTaxData.swift`) is frozen at pre-Phase-5
    /// law by decision: it is a defensive fallback reached only when the
    /// bundled JSON fails to load, and it is deliberately NOT updated
    /// alongside corrections (see that declaration's doc comment for the
    /// full rationale). That means every jurisdiction named here is EXPECTED
    /// to diverge from its legacy counterpart, permanently, not skipped.
    ///
    /// This list does not silence `structurallyIdentical` for these states;
    /// it flips its assertion. A jurisdiction on this list that re-encodes
    /// IDENTICALLY to its legacy entry is a failure, not a pass, because
    /// that means either the correction was reverted from the JSON or
    /// someone edited the legacy table to match it. Both need fixing.
    ///
    /// - Kansas: Phase 5a Task 2, `personalExemption` added (SB1, 2024
    ///   special session).
    /// - Indiana: Phase 5a Task 7, `personalExemption` added (IT-40 Booklet
    ///   2025, page 24, Schedule 3 line 1).
    static let phase5CorrectedJurisdictions: Set<USState> = [.kansas, .iowa, .indiana]

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

    @Test("""
          Re-encoding the JSON-loaded config is byte-identical to re-encoding the legacy \
          config, except for jurisdictions Phase 5 has corrected, which must diverge
          """,
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

        if Self.phase5CorrectedJurisdictions.contains(state) {
            #expect(
                jsonEncoded != legacyEncoded,
                """
                \(state.abbreviation) is listed in phase5CorrectedJurisdictions, so its \
                corrected JSON is expected to diverge permanently from the frozen legacy \
                table (configs2026Legacy is deliberately not updated alongside \
                corrections). Byte-identical here means either the correction was \
                reverted from the JSON or the legacy table was edited to match it; both \
                are failures that need fixing, not this test.
                """
            )
        } else {
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

    /// Keys every shipped file must carry.
    private static let requiredTopLevelKeys: Set<String> = [
        "state", "taxSystem", "retirementExemptions", "stateDeduction",
        "estimatedPaymentSchedule", "safeHarborRule", "currentYearSafeHarborRate",
        "hsaContributionsTaxableForState", "traditionalIRAContributionsTaxableForState",
        "otherPreTaxDeductionsTaxableForState", "pretax401kContributionsTaxableForState",
        "capitalLossesClassIsolated", "verification"
    ]

    /// Keys a file MAY carry. `personalExemption` is written only for states
    /// that grant one (New Jersey since Phase 3a, Kansas since Phase 5a Task
    /// 2, Indiana since Phase 5a Task 7), so requiring it everywhere would
    /// force 50 files to carry a key with no meaning. A key outside both
    /// sets is still a failure: this widens the assertion by exactly one
    /// name, it does not weaken it into an allow-anything check.
    private static let optionalTopLevelKeys: Set<String> = ["personalExemption"]

    @Test("Each bundled JSON file carries every required top-level key and no unknown ones",
          arguments: USState.allCases)
    func topLevelKeysAreCompleteAndKnown(state: USState) throws {
        let url = try StateTaxDataLoader.fileURL(for: state, taxYear: 2026)
        let data = try Data(contentsOf: url)
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let object = raw as? [String: Any] else {
            Issue.record("\(state.abbreviation): top-level JSON at \(url.lastPathComponent) is not an object")
            return
        }

        let actualKeys = Set(object.keys)
        let missing = Self.requiredTopLevelKeys.subtracting(actualKeys).sorted()
        let unknown = actualKeys
            .subtracting(Self.requiredTopLevelKeys)
            .subtracting(Self.optionalTopLevelKeys).sorted()

        #expect(missing.isEmpty,
                "\(state.abbreviation) (\(url.lastPathComponent)) is missing required keys: \(missing)")
        #expect(unknown.isEmpty,
                "\(state.abbreviation) (\(url.lastPathComponent)) carries unknown keys: \(unknown)")
    }

    @Test("Exactly New Jersey, Kansas, and Indiana ship a personalExemption key")
    func onlyNewJerseyAndKansasShipAPersonalExemptionKey() throws {
        var carriers: [String] = []
        for state in USState.allCases {
            let url = try StateTaxDataLoader.fileURL(for: state, taxYear: 2026)
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: url)) as? [String: Any]
            if object?["personalExemption"] != nil { carriers.append(state.abbreviation) }
        }
        // Phase 3a shipped New Jersey's. Phase 5a Task 2 added Kansas's (SB1,
        // 2024 special session), correcting Steve Nicolai's reported defect.
        // Phase 5a Task 7 added Indiana's (IT-40 Booklet 2025, page 24,
        // Schedule 3 line 1).
        #expect(carriers.sorted() == ["IN", "KS", "NJ"],
                "Expected only New Jersey, Kansas, and Indiana to carry personalExemption. Found: \(carriers)")
    }
}
