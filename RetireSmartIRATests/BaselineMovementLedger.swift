import Testing
import Foundation
@testable import RetireSmartIRA

/// One deliberate, attributed movement of a frozen-baseline value.
///
/// Phases 1 through 4 could assert that NO baseline value moved. Phase 5 moves
/// values on purpose, so that assertion is replaced rather than weakened: the
/// baseline file stays frozen, and every movement must appear here naming the
/// golden case that authorises it. A value that moves without an entry still
/// fails, which preserves the property the frozen file existed to give.
struct BaselineMovement: Codable, Equatable {
    /// The baseline key, exactly as `StateTaxBehaviorBaselineTests.key` builds
    /// it: "XX|scenario name".
    let key: String
    /// The frozen value, copied from the baseline file. Never edited.
    let before: Double
    /// The value after this phase's correction. MEASURED, never predicted.
    let after: Double
    /// Two-letter jurisdiction, for grouping in reports.
    let state: String
    /// The `name` of the golden scenario whose correction moved this value.
    /// A movement with no golden case behind it is not a correction, it is a
    /// regression that happens to have been noticed.
    let goldenCase: String
    /// One sentence naming the rule that changed, with its authority.
    let justification: String
}

enum BaselineMovementLedger {
    static func movements() throws -> [String: BaselineMovement] {
        let bundle = Bundle(for: BaselineMovementMarker.self)
        guard let url = bundle.url(forResource: "statetax-behavior-movements-2026",
                                   withExtension: "json") else {
            throw LoadError.missing
        }
        let list = try JSONDecoder().decode([BaselineMovement].self,
                                            from: Data(contentsOf: url))
        return Dictionary(uniqueKeysWithValues: list.map { ($0.key, $0) })
    }

    enum LoadError: Error { case missing }
}

private final class BaselineMovementMarker {}

@Suite("Baseline movement ledger")
struct BaselineMovementLedgerTests {

    @Test("The ledger loads and every entry is well formed")
    func ledgerIsWellFormed() throws {
        let movements = try BaselineMovementLedger.movements()
        // Golden fixtures are loaded once per state and reused, since several
        // movements typically land in the same jurisdiction.
        var fixtures: [String: GoldenScenarioFile] = [:]
        for (key, m) in movements {
            #expect(m.key == key, "\(key): entry key disagrees with its map key")
            #expect(!m.goldenCase.isEmpty,
                    "\(key): movement with no golden case is not a correction")
            #expect(!m.justification.isEmpty, "\(key): movement with no justification")
            #expect(abs(m.before - m.after) >= 0.005,
                    "\(key): recorded as moved but before and after agree")
            #expect(key.hasPrefix(m.state + "|"),
                    "\(key): state \(m.state) does not match the key's prefix")

            // The attribution chain is a moved value pointing at a golden case,
            // which itself points at a state's published form. `goldenCase` was
            // previously validated only as non-empty text, so a typo or an
            // invented-sounding name broke the chain with every test still
            // green. This closes that: the named case must actually exist in
            // that state's own golden fixture.
            let fixture: GoldenScenarioFile
            if let cached = fixtures[m.state] {
                fixture = cached
            } else {
                do {
                    fixture = try GoldenScenario.load(abbreviation: m.state)
                    fixtures[m.state] = fixture
                } catch {
                    Issue.record("""
                        \(key): movement claims golden case "\(m.goldenCase)" in \
                        \(m.state), but \(m.state) has no golden fixture at all \
                        (\(error)). A jurisdiction with no golden coverage has no \
                        published form for this movement to point at, so the \
                        attribution chain has nothing on the other end. Add the \
                        golden fixture before recording a movement here, or do \
                        not move this value yet.
                        """)
                    continue
                }
            }
            #expect(fixture.scenarios.contains(where: { $0.name == m.goldenCase }),
                    """
                    \(key): movement names golden case "\(m.goldenCase)", but no \
                    scenario with that name exists in \
                    statetax-2026-\(m.state).golden.json. Either the name is a \
                    typo for a case that was written, or it names a case that \
                    was never written. Fix the name, or write the golden case \
                    first: a name that does not resolve is not an attribution.
                    """)
        }
    }
}
