//
//  RetirementPlanClassification.swift
//  RetireSmartIRA
//
//  Phase 3b: a retirement plan is classified along two independent
//  dimensions, structure and source, rather than one flat enum. See
//  docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
//  section 3.1 for why the two dimensions cannot be collapsed into one, and
//  section 3.6 for the migration inference implemented below.
//
//  Types only in this phase. Task 2 wires this onto IncomeSource and
//  Account; Task 3 wires it into the engine; Task 4 ships New York's rule.
//

import Foundation

/// How a retirement plan is structured. Orthogonal to `PlanSource`, which
/// carries the employer/jurisdiction. A public-school 403(b) is
/// simultaneously government-employed, defined contribution and
/// salary-reduction; collapsing structure and source into one enum would
/// discard whichever fact a later state rule needs.
enum PlanStructure: String, Codable, CaseIterable {
    /// Traditional pension, annuitised.
    case definedBenefit
    /// 401(k), 403(b), 457.
    case definedContribution
    /// Individual retirement arrangement.
    case ira
    /// Migration default; behaves as today.
    case unknown
}

/// Where a retirement plan's income originates. Orthogonal to
/// `PlanStructure`.
enum PlanSource: String, Codable, CaseIterable {
    /// NYS, NY localities, named NY public authorities.
    case nyStateOrLocal
    /// US government civilian service: CSRS and FERS. Distinct from
    /// `uniformedServices` (military retired pay) and `railroadRetirement`
    /// (Railroad Retirement Board benefits), neither of which is an ordinary
    /// federal civilian pension even though all three are federal in origin.
    case federalCivilian
    /// Military retired pay. Distinct from `federalCivilian` (CSRS/FERS).
    /// Phase 5b: Vermont, Arizona, Idaho, Massachusetts and Kansas each give
    /// uniformed-services and federal-civilian pay different treatment;
    /// before this case existed the two were indistinguishable, so no rule
    /// could express that difference.
    case uniformedServices
    /// Railroad Retirement Board benefits. Phase 5b: neither a state system
    /// nor an ordinary federal civilian pension, which is why it is its own
    /// case rather than folded into `federalCivilian`. Kansas exempts it by
    /// name.
    case railroadRetirement
    /// The taxpayer's OWN state of residence, or that state's localities:
    /// their own state's public retirement system. This is what KPERS (the
    /// Kansas Public Employees Retirement System) is for a Kansas resident.
    /// Phase 5b: contrast with `otherStateOrLocal` below, which is a
    /// DIFFERENT state's system. The two are a matched pair and a rule
    /// naming one must never match the other. Before this case existed,
    /// Kansas's own KPERS fixtures had to be labelled `otherStateOrLocal`,
    /// the exact case whose entire reason for existing is to stop an
    /// out-of-state pension from claiming a state's own exclusion.
    case ownStateOrLocal
    /// A DIFFERENT state or its localities. NOT Line 26 eligible. This case
    /// exists specifically to stop an out-of-state public pension from
    /// selecting New York's exclusion. Contrast with `ownStateOrLocal`
    /// above, the taxpayer's OWN state system: the two are a matched pair
    /// and a rule naming one must never match the other.
    case otherStateOrLocal
    /// A government employer whose jurisdiction was not established. The
    /// picker establishes jurisdiction for pensions, where it changes the
    /// answer, and deliberately does not interrogate it for salary-reduction
    /// plans, where under every rule shipping in this phase it cannot.
    /// Recording `otherStateOrLocal` for a New York state employee's 403(b)
    /// would be a false statement stored in user data. No rule may match
    /// this case as though it were a specific jurisdiction.
    case governmentUnspecified
    case privateEmployer
    /// Self-established, e.g. a personal IRA.
    case individual
    /// Migration default; behaves as today.
    case unknown
}

/// Both dimensions together, carried by `IncomeSource` and by `Account`
/// (that wiring lands in Task 2; this type is domain model only).
struct RetirementPlanClassification: Codable, Equatable, Sendable {
    let structure: PlanStructure
    let source: PlanSource
    /// Phase 5b: whether this classified source is a survivor benefit held
    /// by someone other than the original plan participant, rather than the
    /// participant's own pension. DC exempts a survivor benefit while taxing
    /// the holder's own pension, and today both are `federalCivilian`,
    /// indistinguishable without this flag.
    ///
    /// Defaults to `nil`, which is what every classification built before
    /// this flag existed produces: `RetirementPlanClassification`'s
    /// synthesized memberwise initializer carries the same `nil` default,
    /// so no existing call site in `infer(incomeType:)` or
    /// `infer(accountType:)` needed to change. Swift's synthesized
    /// `Decodable` conformance decodes a missing key on an `Optional`
    /// property as `nil` rather than throwing, so every fixture and every
    /// user save written before this flag existed decodes unchanged.
    ///
    /// Domain model only in this phase, per this file's header: nothing yet
    /// reads this flag when matching a `PerSourceExemptionRule`. Wiring it
    /// into matching is later phase 5b task work.
    let isSurvivorBenefit: Bool? = nil

    /// Migration inference for existing `IncomeSource` rows, per design doc
    /// section 3.6. Only `.rmd` maps to a specific classification. `.pension`
    /// is left unknown/unknown and prompted at the presentation layer, which
    /// is out of scope for this domain-model task. Everything else defaults
    /// to unknown/unknown, preserving today's behavior.
    static func infer(incomeType: IncomeType) -> RetirementPlanClassification {
        switch incomeType {
        case .rmd:
            return RetirementPlanClassification(structure: .ira, source: .individual)
        default:
            return RetirementPlanClassification(structure: .unknown, source: .unknown)
        }
    }

    /// Migration inference for existing `Account` rows, per design doc
    /// section 3.6.
    static func infer(accountType: AccountType) -> RetirementPlanClassification {
        switch accountType {
        case .traditionalIRA:
            return RetirementPlanClassification(structure: .ira, source: .individual)
        case .traditional401k:
            return RetirementPlanClassification(structure: .definedContribution, source: .privateEmployer)
        default:
            return RetirementPlanClassification(structure: .unknown, source: .unknown)
        }
    }
}

/// A classification enum with an `.unknown` migration-default case, so a
/// safe fallback always exists for a raw value this build does not
/// recognise. Conformed by `PlanStructure` and `PlanSource`.
protocol RetirementPlanClassificationCase: RawRepresentable where RawValue == String {
    static var unknown: Self { get }
}

extension PlanStructure: RetirementPlanClassificationCase {}
extension PlanSource: RetirementPlanClassificationCase {}

/// Decodes `PlanStructure`/`PlanSource` from a USER'S saved data
/// (`IncomeSource.init(from:)`, `IRAAccount.init(from:)`, reached via
/// `PersistenceManager.loadAll`), which must tolerate an unrecognised raw
/// value rather than throw. See design doc section 3.6, "the two data
/// sources get different strictness, deliberately," and section 6's error
/// table. Shipped state JSON keeps `PlanStructure`/`PlanSource`'s own
/// strict, throwing `Decodable` conformance untouched by this type (pinned
/// by `Phase3bClassificationTests`): a silent default there could turn a
/// corrupt config into a plausible wrong tax. A user's saved data is
/// different: `PersistenceManager.loadAll` wraps its `[IncomeSource]` and
/// `[IRAAccount]` array decodes in `try?`, so one row throwing here would
/// silently discard every stored row of that type, for a value the app has
/// no rule for anyway.
enum PlanClassificationUserSaveDecoding {

    /// Set once a present but unrecognised raw value is decoded for a
    /// user-saved `planStructure`/`planSource` key. Never set while decoding
    /// shipped state JSON, which never calls this type. Follows the
    /// precedent of `StateTaxDataLoader.legacyFallbackFired`: a static,
    /// observable marker a test can assert on. Not reset once set.
    static private(set) var unrecognisedClassificationEncountered = false

    /// Absent key resolves to `inferredFallback`, the ordinary Phase 3b
    /// migration inference from `incomeType`/`accountType`, expected on
    /// every pre-3b row. A present value that is not a string, or is a
    /// string that does not match a known case, resolves to `.unknown` and
    /// sets `unrecognisedClassificationEncountered`. Never throws.
    static func decode<T: RetirementPlanClassificationCase, K: CodingKey>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<K>,
        forKey key: K,
        inferredFallback: T
    ) -> T {
        let raw: String?
        do {
            raw = try container.decodeIfPresent(String.self, forKey: key)
        } catch {
            unrecognisedClassificationEncountered = true
            return .unknown
        }
        guard let raw else { return inferredFallback }
        guard let value = T(rawValue: raw) else {
            unrecognisedClassificationEncountered = true
            return .unknown
        }
        return value
    }
}
