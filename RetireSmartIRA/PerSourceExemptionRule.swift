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
    func matches(structure: PlanStructure, source: PlanSource) -> Bool {
        let sourceMatches = matchSources.isEmpty || matchSources.contains(source)
        let structureMatches = matchStructures.isEmpty || matchStructures.contains(structure)
        return sourceMatches && structureMatches
    }
}
