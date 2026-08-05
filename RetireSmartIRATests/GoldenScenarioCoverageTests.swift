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

    /// Jurisdictions with a bundled fixture today. This list grows as each
    /// batch task lands, so a half-finished phase still gates on what it has
    /// actually delivered. Task 10 switches `covered` to a full
    /// `USState.allCases` sweep and adds a dedicated completeness test
    /// (`everyJurisdictionHasAFixture`) once this list reaches 51; that test
    /// does not exist yet.
    static let covered: [String] = ["PA", "IL", "MS", "NJ", "NY", "AK", "FL", "NV", "SD", "TN", "TX", "WY", "NH", "CA", "NE", "ND", "IN", "OR", "CO", "KY", "GA", "MO", "IA", "MI", "CT", "VA", "WI", "AL", "RI", "ME", "MD"]

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
