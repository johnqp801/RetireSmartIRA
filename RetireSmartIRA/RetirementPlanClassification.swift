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
    /// US government civilian service.
    case federalCivilian
    /// A DIFFERENT state or its localities. NOT Line 26 eligible. This case
    /// exists specifically to stop an out-of-state public pension from
    /// selecting New York's exclusion.
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
