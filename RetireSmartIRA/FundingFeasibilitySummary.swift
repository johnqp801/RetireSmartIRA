//
//  FundingFeasibilitySummary.swift
//  RetireSmartIRA
//
//  V2.3: plan-level roll-up of the per-year funding-feasibility flags.
//
//  The per-year rows carry the full explanation, but a shortfall in year 12 of a 30-year
//  ladder is invisible until the user scrolls to it, while the plan summary above keeps
//  printing a lifetime-tax figure that includes tax the household could never have paid.
//  This type supplies the one thing a row cannot: the COUNT of affected years, split by
//  which of the two states they are in. It deliberately carries none of the row paragraph's
//  sentences, so the headline and the rows never print the same copy on one screen.
//

import Foundation

struct FundingFeasibilitySummary: Equatable, Sendable {
    /// Years whose OWN tax could not be funded from available taxable plus traditional assets.
    let infeasibleYears: [Int]
    /// Years that did not fail themselves but inherit balances from a year that did. A year
    /// that is both is counted ONLY as infeasible: its own shortfall is the more urgent fact,
    /// and double counting would overstate how many years are merely downstream.
    let dependentOnlyYears: [Int]

    init(path: [YearRecommendation]) {
        infeasibleYears = path.filter(\.isInfeasible).map(\.year)
        dependentOnlyYears = path.filter { $0.dependsOnInfeasibleYear && !$0.isInfeasible }.map(\.year)
    }

    var isFullyFunded: Bool { infeasibleYears.isEmpty && dependentOnlyYears.isEmpty }

    /// Short banner headline. Empty when nothing is wrong, so the view can gate on it.
    ///
    /// The copy attributes the gap to what this plan MODELS, never to what the household
    /// could afford. Those are not the same thing, and the earlier wording asserted the
    /// second. A household living on a pension with a large Roth balance reaches these
    /// years routinely: the tax cascade funds only from taxable and traditional accounts,
    /// so a solvent household with its money in Roth was told its plan described an
    /// outcome it "could never have held". Unspent income now counts toward funding the
    /// year's tax, which removes the most common false alarm outright, but a household
    /// spending down Roth still lands here and the copy must not accuse it of insolvency.
    var headline: String {
        guard !isFullyFunded else { return "" }
        switch infeasibleYears.count {
        case 0:
            // Defensive: downstream years without a root failure should not occur, but the
            // plan still is not a complete picture.
            return "Tax funding not modeled in an earlier year of this plan"
        case 1:
            return "Tax funding not modeled in 1 year"
        default:
            return "Tax funding not modeled in \(infeasibleYears.count) years"
        }
    }

    /// One or two sentences of context. States what the totals mean and, separately, how many
    /// years merely inherit the gap. The per-year detail lives in the rows, not here.
    var detail: String {
        guard !isFullyFunded else { return "" }
        let lead = "In these years the modeled tax is more than the taxable and traditional balances can cover. This plan funds tax only from those accounts, so paying from Roth savings or from cash on hand is not modeled. The totals above leave that tax unfunded."
        switch dependentOnlyYears.count {
        case 0:
            return lead
        case 1:
            return lead + " 1 later year builds on those balances, so its figures carry the same gap."
        default:
            return lead + " \(dependentOnlyYears.count) later years build on those balances, so their figures carry the same gap."
        }
    }
}
