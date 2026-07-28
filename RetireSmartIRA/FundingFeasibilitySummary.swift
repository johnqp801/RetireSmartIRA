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
    var headline: String {
        guard !isFullyFunded else { return "" }
        switch infeasibleYears.count {
        case 0:
            // Defensive: downstream years without a root failure should not occur, but the
            // plan is still not presentable as funded.
            return "Not fully funded: this plan builds on a year whose tax could not be funded"
        case 1:
            return "Not fully funded: 1 year cannot pay its modeled tax"
        default:
            return "Not fully funded: \(infeasibleYears.count) years cannot pay their modeled tax"
        }
    }

    /// One or two sentences of context. States what the totals mean and, separately, how many
    /// years merely inherit the problem. The per-year detail lives in the rows, not here.
    var detail: String {
        guard !isFullyFunded else { return "" }
        let lead = "The plan totals above include tax that available assets could not cover, so they do not describe an outcome this household can reach."
        switch dependentOnlyYears.count {
        case 0:
            return lead
        case 1:
            return lead + " 1 later year did not fail on its own but builds on balances the household could never have held, so its figures are not reliable either."
        default:
            return lead + " \(dependentOnlyYears.count) later years did not fail on their own but build on balances the household could never have held, so their figures are not reliable either."
        }
    }
}
