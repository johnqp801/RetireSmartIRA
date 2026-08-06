//
//  PerSourceExemptionRule.swift
//  RetireSmartIRA
//
//  Phase 3b: an ordered, first-match-wins rule that grants a source-specific
//  exemption treatment. See
//  docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
//  sections 3.3 and 3.4a.
//
//  Types only in this phase. `RetirementIncomeExemptions.perSourceExemptions`
//  and the engine partition that consumes it are Task 2 and Task 3.
//

import Foundation

/// A single rule in `RetirementIncomeExemptions.perSourceExemptions`. Rules
/// are evaluated in order; the first match wins. An empty `matchSources` or
/// `matchStructures` means "any" for that dimension, never "none".
struct PerSourceExemptionRule: Codable, Sendable {
    /// Empty means "any". Non-empty means the source must be in this set.
    let matchSources: [PlanSource]
    /// Empty means "any". Non-empty means the structure must be in this set.
    let matchStructures: [PlanStructure]

    /// Phase 5b Task 9: whether the row must be a SURVIVOR benefit.
    ///
    /// `nil` (the default, and the value every rule shipped before this task
    /// carries) means this dimension is not consulted at all, so a rule
    /// written before this field existed behaves exactly as it did. `true`
    /// means the row must carry `isSurvivorBenefit == true`. `false` means it
    /// must carry `isSurvivorBenefit == false`.
    ///
    /// A row whose own flag is `nil` matches NEITHER `true` NOR `false`. That
    /// asymmetry is deliberate and it is the same discipline
    /// `RetirementPlanClassification.isSurvivorBenefit` documents for its own
    /// `Bool?`: `nil` means the question was never ASKED of that row, not that
    /// the answer is no. A never-asked row must not claim an exclusion whose
    /// statute conditions on the answer, and must not be denied one either by
    /// a `false` rule. This is the same direction Kansas's rule takes by
    /// declining to match `PlanSource.unknown`.
    ///
    /// Declared `var` with a default, never `let` with a default. Task 1's
    /// Critical finding was that `let isSurvivorBenefit: Bool? = nil` compiles,
    /// warns, and then SILENTLY DECODES JSON setting it true as nil, because
    /// Swift treats a `let` with an initial value as already initialised and
    /// excludes it from both the memberwise initializer and the synthesized
    /// `init(from:)`. `Phase5bDCSurvivorTests` proves the round trip here by
    /// execution rather than by reading.
    var matchIsSurvivorBenefit: Bool? = nil

    /// Phase 5b Task 9: a minimum age the row's OWNER must have reached.
    ///
    /// `nil` (the default, and the value every rule shipped before this task
    /// carries) means no age gate, which is what New York's Line 26 exclusion,
    /// Kansas's, Massachusetts's and Arizona's rules all require: the
    /// per-source partition in `TaxCalculationEngine.applyRetirementExemptions`
    /// is deliberately UNCONDITIONAL on age, and this field is the only way a
    /// rule can opt into a gate.
    ///
    /// A row whose owner's age is unknown (`nil` at the call site) matches no
    /// gated rule, same conservative direction as `matchIsSurvivorBenefit`.
    ///
    /// WHY A RULE-LEVEL GATE RATHER THAN `regularExemptionMinAge`: that field
    /// gates the POOLED `pensionExemption`/`iraWithdrawalExemption` levels via
    /// `resolveLevel`, which the per-source partition never consults, and it is
    /// household-wide. D.C. Code Section 47-1803.02(a)(2)(N)(ii) conditions on
    /// the AGE OF THE PERSON RECEIVING the survivor benefit, so the gate has to
    /// travel with the rule and be evaluated against the row's own owner.
    var matchMinAge: Int? = nil

    let treatment: RetirementIncomeExemptions.ExemptionLevel

    /// Whether a component or income row with this structure and source is
    /// covered by this rule.
    ///
    /// `governmentUnspecified` is not itself a jurisdiction, so it can only
    /// satisfy a rule whose `matchSources` is empty ("any source"). A rule
    /// that names specific jurisdictions, like New York's Line 26 rule,
    /// never matches it: `matchSources.contains(.governmentUnspecified)` is
    /// false unless a rule author literally lists that case, which no rule
    /// shipping in this phase does.
    ///
    /// Phase 5b: the identical `Set`-like containment reasoning is what
    /// makes `ownStateOrLocal` and `otherStateOrLocal` mutually exclusive,
    /// and `uniformedServices`, `railroadRetirement` and `federalCivilian`
    /// mutually exclusive. Each is a distinct `PlanSource` case, so a rule
    /// naming one is never satisfied by a row carrying another; no
    /// special-case code is needed here for that to hold, which is also why
    /// this function's body did not need to change to add them. See
    /// `Phase5bModelExtensionTests` for the exclusivity proof.
    /// Phase 5b Task 9 added `isSurvivorBenefit` and `age`. Both default to
    /// `nil` so every call site written before this task compiles and means
    /// exactly what it meant: a rule carrying neither `matchIsSurvivorBenefit`
    /// nor `matchMinAge` ignores both arguments entirely, which is what all
    /// four rules shipped before this task (NY, KS, MA, AZ) require. The two
    /// PRODUCTION call sites reach this through
    /// `RetirementIncomeExemptions.matchedPerSourceRule`, whose parameters are
    /// deliberately NOT defaulted, so an engine or DataManager site cannot
    /// silently omit a fact it has.
    func matches(structure: PlanStructure, source: PlanSource,
                 isSurvivorBenefit: Bool? = nil, age: Int? = nil) -> Bool {
        let sourceMatches = matchSources.isEmpty || matchSources.contains(source)
        let structureMatches = matchStructures.isEmpty || matchStructures.contains(structure)
        // nil rule field -> dimension not consulted. Non-nil rule field -> the
        // row's own value must be present AND equal. A nil row value never
        // satisfies a non-nil rule field; see the property doc above.
        let survivorMatches = matchIsSurvivorBenefit.map { $0 == isSurvivorBenefit } ?? true
        let ageMatches = matchMinAge.map { minimum in
            guard let age else { return false }
            return age >= minimum
        } ?? true
        return sourceMatches && structureMatches && survivorMatches && ageMatches
    }
}
