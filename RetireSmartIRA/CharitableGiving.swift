//
//  CharitableGiving.swift
//  RetireSmartIRA
//
//  The multi-year charitable-giving input model. Intent (HOW MUCH to give) is kept
//  separate from the funding method (HOW to fund it — cash vs QCD), so the two can vary
//  independently and QCD sourcing is decided per year in the engine (Phase 1c). This file
//  is inputs only; the engine does not consume it yet.
//

import Foundation

/// How much the household intends to give each year.
enum GivingIntent: Equatable, Sendable {
    /// A fixed dollar target (see `CharitableGivingPlan.maintainRealValue` for inflation).
    case fixedAnnualAmount(Double)
    /// A fraction of the household total RMD (0.25 == 25%). Only bites at RMD age; interpreted
    /// against the combined RMD across all traditional sources in Phase 1c.
    case percentOfRMD(Double)
}

/// How the giving target is funded through QCDs (the remainder is cash charitable).
enum QCDFundingMethod: Equatable, Sendable {
    /// Fund the target with QCDs to the extent each spouse is eligible (the default).
    case qcdFirst
    /// Route a fixed dollar amount through QCDs; the remainder of the target is cash.
    case fixedQCD(Double)
}

/// The household's recurring charitable-giving plan for the multi-year projection.
struct CharitableGivingPlan: Equatable, Sendable {
    var intent: GivingIntent
    var funding: QCDFundingMethod
    /// Fixed-amount intent only: hold the target constant in real terms (inflate the nominal
    /// target with CPI) rather than flat-nominal. Ignored for `.percentOfRMD`.
    var maintainRealValue: Bool

    /// A plan directing no charitable giving.
    static let none = CharitableGivingPlan(intent: .fixedAnnualAmount(0), funding: .qcdFirst, maintainRealValue: true)

    /// True when the plan directs any giving.
    var hasGiving: Bool {
        switch intent {
        case .fixedAnnualAmount(let amount): return amount > 0
        case .percentOfRMD(let fraction): return fraction > 0
        }
    }
}
