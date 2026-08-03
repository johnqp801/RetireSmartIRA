import Foundation
@testable import RetireSmartIRA

/// One hand-derived tax case for one jurisdiction.
///
/// `expectedStateTax` MUST be derived from the state's own published form or
/// instructions, never from this app's output. `source` records which form and
/// which lines, so a future reader can re-derive it. A fixture whose expected
/// value came from the engine proves only that the engine agrees with itself.
struct GoldenScenario: Codable {
    let name: String
    /// Form and line numbers used to derive `expectedStateTax`.
    let source: String
    let filingStatus: String        // "single" or "marriedFilingJointly"
    let primaryAge: Int
    let spouseAge: Int?
    /// Federal adjusted gross income before any state-level exemption or
    /// deduction is applied. Same concept as `TaxCalculationEngine
    /// .calculateStateTax`'s `income:` parameter (called `federalAGI` at its
    /// call site in `ProjectionEngine.computeStateTax`). Named explicitly
    /// rather than "totalIncome" so a fixture author never has to guess
    /// whether it means AGI, gross income, or the sum of the fields below.
    let federalAGI: Double
    let taxableSocialSecurity: Double
    let pensionIncome: Double
    let iraWithdrawals: Double
    let rothConversion: Double
    let expectedStateTax: Double

    var resolvedFilingStatus: FilingStatus {
        filingStatus == "marriedFilingJointly" ? .marriedFilingJointly : .single
    }
}

struct GoldenScenarioFile: Codable {
    let state: String
    let taxYear: Int
    let scenarios: [GoldenScenario]
}

extension GoldenScenario {
    enum LoadError: LocalizedError {
        case missing(abbreviation: String)
        var errorDescription: String? {
            switch self {
            case .missing(let abbreviation):
                return "No golden fixture bundled for \(abbreviation)."
            }
        }
    }

    /// Fixtures live in the TEST bundle, not the app bundle: they are
    /// verification data and must never ship to users.
    static func load(abbreviation: String) throws -> GoldenScenarioFile {
        let bundle = Bundle(for: GoldenScenarioMarker.self)
        guard let url = bundle.url(forResource: "statetax-2026-\(abbreviation).golden",
                                   withExtension: "json") else {
            throw LoadError.missing(abbreviation: abbreviation)
        }
        return try JSONDecoder().decode(GoldenScenarioFile.self, from: Data(contentsOf: url))
    }
}

private final class GoldenScenarioMarker {}
