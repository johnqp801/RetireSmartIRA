import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenario fixtures")
struct GoldenScenarioLoaderTests {

    /// The Phase 2 pilot. Phase 4 extends this to all 51 jurisdictions. NJ is
    /// included here (structural well-formedness only, not tax-value
    /// assertions) so its fixture is loaded and checked by something -- it was
    /// previously decoded by the cross-path suite but never asserted against.
    static let pilot = ["PA", "IL", "MS", "NJ"]

    @Test("Every pilot fixture loads and is internally well formed",
          arguments: GoldenScenarioLoaderTests.pilot)
    func pilotFixturesLoad(abbreviation: String) throws {
        let file = try GoldenScenario.load(abbreviation: abbreviation)
        #expect(file.state == abbreviation)
        #expect(file.taxYear == 2026)
        #expect(!file.scenarios.isEmpty, "\(abbreviation) has no scenarios")
        for scenario in file.scenarios {
            #expect(!scenario.name.isEmpty)
            #expect(!scenario.source.isEmpty,
                    "\(abbreviation)/\(scenario.name) has no citation, so its expected value is unverifiable")
            #expect(!scenario.sourceURL.isEmpty,
                    "\(abbreviation)/\(scenario.name) has no sourceURL, so its citation cannot be followed")
            #expect(scenario.sourceURL.hasPrefix("https://"),
                    "\(abbreviation)/\(scenario.name) sourceURL is not a resolvable https link")
            #expect(scenario.expectedStateTax >= 0)
            #expect(scenario.primaryAge > 0)
        }
    }
}
