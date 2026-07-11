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
}
