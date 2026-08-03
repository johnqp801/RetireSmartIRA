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
    /// A resolvable link to the authority named in `source`, so a reviewer can
    /// follow it rather than trusting the citation text. A citation string alone
    /// hid two wrong references in the first three fixtures ever written.
    let sourceURL: String
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
    /// Phase 3b Task 4: when present, REPLACES the single flat `pensionIncome`
    /// scalar with one classified `IncomeSource(type: .pension)` row per
    /// element, so a fixture can express a mix of per-source-rule-eligible
    /// and ordinary pension income within one taxpayer (e.g. New York's
    /// government pension alongside a private one). `pensionIncome` MUST be
    /// `0` in any fixture that sets this -- a loader that read both would
    /// double count. Absent (the default, via Swift's synthesized
    /// `decodeIfPresent` for an `Optional` property) for every pre-existing
    /// PA/IL/MS/NJ fixture, which keeps using the flat scalar unchanged.
    let classifiedPensionSources: [ClassifiedPensionSource]?

    var resolvedFilingStatus: FilingStatus {
        filingStatus == "marriedFilingJointly" ? .marriedFilingJointly : .single
    }
}

/// One classified pension row for `GoldenScenario.classifiedPensionSources`.
/// `planStructure`/`planSource` are the raw string values of `PlanStructure`/
/// `PlanSource` (e.g. `"definedBenefit"`, `"nyStateOrLocal"`), so a fixture
/// reads as plainly as the JSON it names.
struct ClassifiedPensionSource: Codable {
    let amount: Double
    let planStructure: String
    let planSource: String
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
