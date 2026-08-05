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

    /// Present only when the engine is KNOWN to disagree with `expectedStateTax`.
    /// Absent (nil) means the jurisdiction is expected to match its own form.
    let knownDefect: KnownDefect?

    /// Ordinary income carried by `federalAGI` that no other field on this
    /// fixture represents, DECLARED so the shape invariant can stay an exact
    /// equality instead of an inequality.
    ///
    /// DECLARATIVE ONLY. It is never summed into anything and never reaches an
    /// engine: `federalAGI` remains the single number the single-year runner
    /// passes in. Wiring this into the runner would change New York's shipped
    /// fixture values, which Phase 4 forbids.
    ///
    /// No fixture sets this field yet. It exists for New York's first fixture,
    /// whose `federalAGI` of $90,000 stands against a $70,000 classified
    /// government pension, leaving $20,000 of unrelated ordinary income
    /// currently described only in that fixture's prose `source` string. A
    /// later task moves that $20,000 into this field.
    ///
    /// A fixture with a nonzero value here can never join
    /// `GoldenScenarioCrossPathTests.agreeing`, because the multi-year runner
    /// derives AGI from the components and is structurally blind to this income.
    let otherOrdinaryIncome: Double?

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
    /// Phase 5b Task 2: whether this row is a SURVIVOR benefit rather than the
    /// holder's own pension. Mirrors `RetirementPlanClassification
    /// .isSurvivorBenefit`, which Task 1 added to the production type. DC
    /// exempts a survivor benefit at 62 or over while taxing the holder's own
    /// pension, and both are `federalCivilian`, so nothing in the fixture
    /// could tell them apart before this field existed.
    ///
    /// FIXTURE SCHEMA ONLY IN THIS TASK. Nothing consumes it yet: the chain
    /// from here to a matching rule (a field on `IncomeSource`/`IRAAccount`,
    /// `matchIsSurvivorBenefit` on `PerSourceExemptionRule`, a parameter on
    /// `matches()`, a pass-through in `DataManager.matchedPerSourceRule`, and
    /// a bridge in `GoldenScenarioSingleYearTests.singleYearStateTax`) is
    /// Task 9's work. The field is added here so DC's fixture can STATE the
    /// fact in structured form instead of prose, which is what Task 9 will
    /// then read.
    ///
    /// Declared `var` with a `nil` default for the same reason the production
    /// property is (see `RetirementPlanClassification.isSurvivorBenefit`): a
    /// `let` with an initial value is treated as already initialised, so
    /// Swift excludes it from the synthesized `init(from:)` entirely and a
    /// fixture setting the key would decode to `nil` anyway. That failure is
    /// silent, and it is the SAME failure class this field exists to fix.
    /// It was measured before the field was added: a row whose JSON set
    /// `"isSurvivorBenefit": true` decoded and re-encoded as
    /// `{"planSource":...,"amount":...,"planStructure":...}`, the key gone
    /// with no error. `GoldenFixtureSurvivorFlagTests` pins both halves now:
    /// a present key decodes to its value, an absent key decodes to `nil`.
    var isSurvivorBenefit: Bool? = nil
}

/// Records that a jurisdiction's shipped behavior is KNOWN to disagree with
/// its own published form, so the disagreement is pinned rather than silently
/// tolerated.
///
/// Phase 4 writes fixtures to CORRECT LAW, which means roughly 29 jurisdictions
/// are expected to disagree with the engine. Without this block the suite would
/// go red across the board and the phase could not gate. With it, every defect
/// is a named, pinned, citable record and the suite stays green.
///
/// `observedToday` is the figure the engine ACTUALLY produces right now. It is
/// not an endorsement. It exists so that any drift in a defective state fails a
/// test, and so Phase 5 can measure its own correction against a real baseline
/// rather than a remembered one.
struct KnownDefect: Codable {
    /// "tier1" | "tier2" | "tier3" | "tier4" | "unclassified", matching the
    /// tiers in `.claude/memory/roadmap/2026-08-02-full-50-state-verification.md`.
    let tier: String
    /// One sentence naming the mechanism, not the symptom.
    let summary: String
    /// Today's engine output for this scenario, measured, never predicted.
    let observedToday: Double
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
