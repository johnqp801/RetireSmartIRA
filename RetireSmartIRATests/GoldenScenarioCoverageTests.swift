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

    /// Jurisdictions with a bundled fixture today. Task 10 replaces the body of
    /// `everyJurisdictionHasAFixture` with a full `USState.allCases` sweep once
    /// this list reaches 51; until then it grows as each batch task lands, so a
    /// half-finished phase still gates on what it has actually delivered.
    static let covered: [String] = ["PA", "IL", "MS", "NJ", "NY"]

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
    @Test("federalAGI equals the sum of its components",
          arguments: GoldenScenarioCoverageTests.covered)
    func federalAGIIsInternallyConsistent(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            let pension = scenario.classifiedPensionSources?.reduce(0) { $0 + $1.amount }
                ?? scenario.pensionIncome
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

    @Test("Every fixture carries a resolvable https citation",
          arguments: GoldenScenarioCoverageTests.covered)
    func citationsAreWellFormed(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            #expect(!scenario.source.isEmpty, "\(abbreviation) / \(scenario.name): empty source")
            #expect(scenario.sourceURL.hasPrefix("https://"),
                    "\(abbreviation) / \(scenario.name): sourceURL is not https")
        }
    }

    @Test("Fixtures never set both pensionIncome and classifiedPensionSources",
          arguments: GoldenScenarioCoverageTests.covered)
    func noDoubleCountedPension(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        for scenario in file.scenarios {
            if let classified = scenario.classifiedPensionSources, !classified.isEmpty {
                #expect(scenario.pensionIncome == 0,
                        "\(abbreviation) / \(scenario.name): both set, would double count")
            }
        }
    }
}
