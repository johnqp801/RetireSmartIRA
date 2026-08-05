import Testing
import Foundation
@testable import RetireSmartIRA

/// Coverage and shape invariants for the golden fixture set.
///
/// Kept separate from the assertion suites because these tests are about the
/// FIXTURES, not about any state's tax. A failure here means a fixture is
/// malformed or missing, which is a different diagnosis from a state being wrong.
@Suite("Golden scenarios, coverage and shape")
struct GoldenScenarioCoverageTests {

    /// All 51 jurisdictions minus the ones in `cannotVerify`. Derived, not
    /// hand-listed: Task 10 closed the phase by switching this from a
    /// hand-grown literal to a full `USState.allCases` sweep, because a
    /// literal list is a liability once the phase is done -- a jurisdiction
    /// silently falling out of it would read as "not yet reached" forever
    /// instead of failing a test. `everyJurisdictionHasAFixture` below is
    /// the completeness gate this list feeds.
    static let covered: [String] = USState.allCases
        .map(\.abbreviation)
        .filter { abbreviation in !cannotVerify.map(\.abbreviation).contains(abbreviation) }
        .sorted()

    /// Jurisdictions for which Phase 4 deliberately shipped NO golden fixture,
    /// because the TY2026 rule cannot be established from a primary source.
    ///
    /// This is DATA, not a comment. Phase 6's disclosure UI is specified to
    /// render exactly this distinction -- a jurisdiction with no fixture must
    /// be visibly UNVERIFIED, never silently treated as "assumed correct" --
    /// and it has to read that distinction from something other than a code
    /// comment. `everyJurisdictionHasAFixture` and
    /// `cannotVerifyListIsExactlyWhatPhase4Shipped` are what keep this list
    /// honest: the first can never pass by quietly shrinking `covered`
    /// instead of fixing a gap, and the second can never pass by quietly
    /// growing this list to make the first one pass.
    struct UnverifiedJurisdiction {
        let abbreviation: String
        /// Why no fixture exists, and what would resolve it. Written for
        /// Phase 6 to show a user, not just for a future engineer.
        let reason: String
    }

    static let cannotVerify: [UnverifiedJurisdiction] = [
        UnverifiedJurisdiction(
            abbreviation: "MT",
            reason: """
                Montana's mechanism is confirmed: the old income-gated \
                .partial(4_640) deduction was repealed effective TY2025 and \
                replaced with a flat age-65 subtraction (Montana DOR Form 2 \
                2025 Instructions, page 6, opened directly by the Task 6 \
                batch). The exact TY2026 INDEXED dollar figure for that flat \
                subtraction has not been published by Montana DOR as of \
                2026-08-04. Recorded CANNOT_VERIFY per spec 3.4 rather than \
                interpolated or guessed. A reviewer independently examined \
                this call and agreed with it. Revisit once Montana DOR \
                publishes the TY2026 figure.
                """
        )
    ]

    /// The pension amount that contributes to `federalAGI`'s component sum.
    ///
    /// When `classifiedPensionSources` is present at all, even as an EMPTY
    /// array, it wins over `pensionIncome`: `[ClassifiedPensionSource]().reduce(0) { ... }`
    /// evaluates to `0`, which is a value, not `nil`, so `??` never falls
    /// back to `pensionIncome`. This mirrors the rule `noDoubleCountedPension`
    /// enforces below and is extracted here so that rule is unit-testable
    /// without loading a fixture from disk.
    static func pensionComponent(_ scenario: GoldenScenario) -> Double {
        scenario.classifiedPensionSources?.reduce(0) { $0 + $1.amount } ?? scenario.pensionIncome
    }

    /// Whether `noDoubleCountedPension` requires `pensionIncome == 0` for this
    /// scenario. True whenever `classifiedPensionSources` is present AT ALL,
    /// including a present-but-EMPTY array, because that is exactly when
    /// `pensionComponent(_:)` stops reading `pensionIncome`. Extracted so the
    /// guard itself, not just its downstream effect, is directly testable.
    static func requiresZeroPensionIncome(_ scenario: GoldenScenario) -> Bool {
        scenario.classifiedPensionSources != nil
    }

    @Test("Every covered jurisdiction has a bundled, decodable fixture",
          arguments: GoldenScenarioCoverageTests.covered)
    func fixtureLoads(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        #expect(file.state == abbreviation)
        #expect(file.taxYear == 2026)
        #expect(!file.scenarios.isEmpty)
    }

    /// The Task 10 completeness gate. Sweeps ALL 51 jurisdictions, not just
    /// `covered`, so a half-finished phase (or a jurisdiction that silently
    /// falls out of `covered` later) cannot pass by construction. Every
    /// jurisdiction not in `cannotVerify` must load a real fixture; every
    /// jurisdiction IN `cannotVerify` is deliberately allowed to have none,
    /// because it is unverifiable, not unfinished.
    ///
    /// Read literally, the brief's version of this test (`USState.allCases`
    /// swept with no exclusion) fails on Montana. That failure would be
    /// correct only if Montana's absence were an oversight. It is not: the
    /// mechanism is confirmed and only the TY2026 indexed dollar figure is
    /// unpublished (see `cannotVerify`). Weakening this test to pass on a
    /// silently-missing state would be the failure the phase exists to
    /// prevent; carrying the exclusion as reviewed, documented DATA is what
    /// keeps the test strict while making a real exception.
    @Test("Every one of the 51 jurisdictions has a fixture or a documented CANNOT_VERIFY reason")
    func everyJurisdictionHasAFixture() throws {
        let excluded = Set(GoldenScenarioCoverageTests.cannotVerify.map(\.abbreviation))
        var missing: [String] = []
        for state in USState.allCases {
            guard !excluded.contains(state.abbreviation) else { continue }
            if (try? GoldenScenario.load(abbreviation: state.abbreviation)) == nil {
                missing.append(state.abbreviation)
            }
        }
        #expect(missing.isEmpty,
                """
                No golden fixture bundled for: \(missing.sorted().joined(separator: ", ")).
                Phase 4's deliverable is all 51 jurisdictions, less any documented
                CANNOT_VERIFY exclusion. A jurisdiction with no fixture and no entry in
                `cannotVerify` is not "assumed correct", it is an unfinished phase.
                """)
        #expect(USState.allCases.count == 51)
    }

    /// Without this, `everyJurisdictionHasAFixture` could be made to pass by
    /// quietly ADDING an abbreviation to `cannotVerify` instead of writing the
    /// fixture -- the exact silent-drop failure mode the completeness gate
    /// exists to catch, just moved one layer up. Pinning the list's exact
    /// membership means growing it (or shrinking it) is a change a reviewer
    /// has to see and approve, not a side effect nobody notices.
    @Test("The CANNOT_VERIFY exclusion list is exactly what Phase 4 shipped, not silently grown")
    func cannotVerifyListIsExactlyWhatPhase4Shipped() {
        let abbreviations = GoldenScenarioCoverageTests.cannotVerify.map(\.abbreviation).sorted()
        #expect(abbreviations == ["MT"],
                """
                cannotVerify now lists \(abbreviations), expected exactly ["MT"]. If a
                jurisdiction was deliberately added or removed, update this pin along with
                the reviewed reason in `cannotVerify` itself -- do not let this list drift
                silently.
                """)
        for entry in GoldenScenarioCoverageTests.cannotVerify {
            #expect(!entry.reason.isEmpty, "\(entry.abbreviation): CANNOT_VERIFY with no reason recorded")
        }
    }

    /// The invariant that makes a whole class of false finding unrepresentable.
    ///
    /// The single-year runner reads `federalAGI` directly; the multi-year runner
    /// derives its own AGI from the income components and never reads
    /// `federalAGI` at all (ProjectionEngine.swift:680-690). A fixture where the
    /// two disagree produces a cross-path gap that looks like an engine defect
    /// and is actually an authoring mistake. Phase 2 shipped exactly that and it
    /// cost a $210 phantom divergence.
    ///
    /// The pension component comes from `pensionComponent(_:)`. When
    /// `classifiedPensionSources` is present but EMPTY, that helper returns
    /// `0`, not `pensionIncome`: a fixture that sets both an empty classified
    /// array and a nonzero `pensionIncome` will silently drop `pensionIncome`
    /// from this sum. `noDoubleCountedPension` below is what stops such a
    /// fixture from existing in the first place.
    @Test("federalAGI equals the sum of its components",
          arguments: GoldenScenarioCoverageTests.covered)
    func federalAGIIsInternallyConsistent(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            let pension = GoldenScenarioCoverageTests.pensionComponent(scenario)
            let components = pension + scenario.iraWithdrawals + scenario.rothConversion
                + scenario.taxableSocialSecurity + (scenario.otherOrdinaryIncome ?? 0)
            #expect(abs(scenario.federalAGI - components) < 0.01,
                    """
                    \(abbreviation) / \(scenario.name): federalAGI \(scenario.federalAGI) \
                    against components summing to \(components).
                    The multi-year runner never reads federalAGI, so this mismatch would surface
                    as a phantom cross-path divergence. Fix the fixture, not the engine.
                    If the excess is deliberate unmodelled ordinary income, DECLARE it in
                    otherOrdinaryIncome rather than leaving it implicit.
                    """)
        }
    }

    @Test("Every fixture carries a source and an https sourceURL",
          arguments: GoldenScenarioCoverageTests.covered)
    func citationsAreWellFormed(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            #expect(!scenario.source.isEmpty, "\(abbreviation) / \(scenario.name): empty source")
            #expect(scenario.sourceURL.hasPrefix("https://"),
                    "\(abbreviation) / \(scenario.name): sourceURL is not https")
        }
    }

    /// Guards on `requiresZeroPensionIncome(_:)`, i.e. on mere PRESENCE of
    /// `classifiedPensionSources`, not on it being non-empty. An EMPTY array
    /// is still present, and `pensionComponent(_:)` treats a present-but-empty
    /// array the same as a present-and-populated one: it wins over
    /// `pensionIncome` and the sum comes out `0`. A fixture with
    /// `classifiedPensionSources: []` and a nonzero `pensionIncome` would
    /// otherwise pass this check while silently dropping that income from
    /// `federalAGIIsInternallyConsistent`'s component sum. See
    /// `emptyClassifiedPensionSourcesStillRequiresZeroPensionIncome` for the
    /// pinned regression.
    @Test("Fixtures never set both pensionIncome and classifiedPensionSources",
          arguments: GoldenScenarioCoverageTests.covered)
    func noDoubleCountedPension(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            if GoldenScenarioCoverageTests.requiresZeroPensionIncome(scenario) {
                #expect(scenario.pensionIncome == 0,
                        "\(abbreviation) / \(scenario.name): both set, would double count")
            }
        }
    }

    /// Regression for the loophole above: a present-but-EMPTY
    /// `classifiedPensionSources` used to slip past `noDoubleCountedPension`
    /// (its old guard required `!classified.isEmpty`, so `requiresZeroPensionIncome`
    /// would have returned `false` here) while still winning over
    /// `pensionIncome` in `pensionComponent(_:)`, silently dropping a nonzero
    /// `pensionIncome` from the component sum. This builds a `GoldenScenario`
    /// directly (no fixture file involved) so the case can be pinned without
    /// adding a malformed fixture to disk, and asserts both halves of the
    /// bug directly: the guard must fire, and the component sum must not
    /// silently include `pensionIncome` once it does.
    @Test("Empty classifiedPensionSources still requires pensionIncome == 0")
    func emptyClassifiedPensionSourcesStillRequiresZeroPensionIncome() {
        let scenario = GoldenScenario(
            name: "regression: empty classifiedPensionSources",
            source: "n/a, synthetic regression fixture",
            sourceURL: "https://example.com/regression",
            filingStatus: "single",
            primaryAge: 65,
            spouseAge: nil,
            federalAGI: 0,
            taxableSocialSecurity: 0,
            pensionIncome: 50_000,
            iraWithdrawals: 0,
            rothConversion: 0,
            expectedStateTax: 0,
            classifiedPensionSources: [],
            knownDefect: nil,
            otherOrdinaryIncome: nil
        )

        // The empty array is present, so the guard must require
        // pensionIncome == 0 for this scenario, exactly as it would for a
        // populated array.
        #expect(GoldenScenarioCoverageTests.requiresZeroPensionIncome(scenario))

        // And the component sum backs that up: it is 0, not the 50_000
        // sitting in pensionIncome, so a fixture failing the guard above
        // would also be silently wrong here.
        #expect(GoldenScenarioCoverageTests.pensionComponent(scenario) == 0)
    }
}
