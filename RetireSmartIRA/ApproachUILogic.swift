//
//  ApproachUILogic.swift
//  RetireSmartIRA
//
//  Pure, view-agnostic logic for the conversion-approach UI. Keeps the SwiftUI branch-free and
//  unit-testable. No "Recommended" strings — the anchor is labeled by the objective the engine
//  actually optimized (legacy-off = lifetime-tax min; legacy-on = tax+legacy blend).
//

import Foundation

enum ApproachUILogic {
    static func anchorLabel(effectiveHeirWeight: Double) -> String {
        effectiveHeirWeight > 0 ? "Optimize tax + legacy" : "Minimize lifetime tax"
    }

    static func columnLabel(_ approach: ConversionApproach, effectiveHeirWeight: Double) -> String {
        switch approach {
        case .recommendedTaxMin:      return anchorLabel(effectiveHeirWeight: effectiveHeirWeight)
        case .fillToBracket(let r):   return "Fill to \(Int((r * 100).rounded()))% bracket"
        case .limitToIRMAA(let t, _): return "Limit to IRMAA tier \(t)"
        }
    }

    enum TargetStatus: Equatable { case reachable, exceededByBaseline, notApplicable }

    static func bracketStatus(bracketTopOrdinaryIncome: Double, baselineOrdinaryIncome: Double) -> TargetStatus {
        baselineOrdinaryIncome >= bracketTopOrdinaryIncome ? .exceededByBaseline : .reachable
    }

    static func activePath(selected: ConversionApproach,
                           comparison: ApproachComparison?,
                           frontierOrCurrent: [YearRecommendation]) -> [YearRecommendation] {
        switch selected {
        case .recommendedTaxMin: return frontierOrCurrent
        case .fillToBracket, .limitToIRMAA: return comparison?.selected.path ?? frontierOrCurrent
        }
    }

    static func approachAfterYear1Edit(_ selected: ConversionApproach) -> ConversionApproach {
        .recommendedTaxMin
    }

    /// The "Lifetime tax" figure shown in the approach-comparison table (and its selected-vs-anchor
    /// headline delta): ALWAYS present value, regardless of the nominal/present-value display
    /// toggle that governs the other rows (ending balances, etc.).
    ///
    /// Nominal is the wrong basis for comparing approaches here: "Minimize lifetime tax" optimizes
    /// a present-value objective, not the nominal undiscounted sum, so a front-loaded approach
    /// (e.g. "Fill to bracket") can show a LOWER nominal total while the minimize approach is
    /// genuinely lower on the objective it minimizes (same dollars, different time-weighting).
    /// Displaying nominal there reads as "the minimize option doesn't minimize" (B2). Present value
    /// is the one basis on which the comparison's own claim ("this approach minimizes lifetime
    /// tax") is actually true, so it's shown unconditionally rather than toggled.
    static func displayedLifetimeTax(_ column: ApproachColumn) -> Double {
        column.lifetimeTaxPV
    }
}
