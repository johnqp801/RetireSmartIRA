import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Golden scenario fixtures")
struct GoldenScenarioLoaderTests {

    /// The Phase 2 pilot. Phase 4 extends this to all 51 jurisdictions.
    static let pilot = ["PA", "IL", "MS"]

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
