//
//  HeirFrontier.swift
//  RetireSmartIRA
//
//  Value-type model for the owner-vs-heirs trade-off frontier: one FrontierPoint per
//  preset heir weight (λ), each carrying owner lifetime tax and what the heirs keep, in
//  today's dollars plus a present-value discount factor for the display toggle.
//
//  The PV toggle is DISPLAY-ONLY (a re-expression of the same plan), never a re-optimization
//  — see HeirFrontierUnitsInvariantTests.
//

import Foundation

enum DisplayUnits: String, CaseIterable, Sendable {
    case todaysDollars
    case presentValue
}

struct FrontierPoint: Identifiable, Equatable, Sendable {
    let id = UUID()
    let weight: Double                         // λ in [0,1]
    let ownerLifetimeTaxToday: Double          // today's dollars
    let heirAfterTaxInheritanceToday: Double   // today's dollars
    let heirTaxToday: Double                   // today's dollars
    let pvDiscountFactor: Double               // multiply today's-dollar figures to get PV

    func ownerLifetimeTax(units: DisplayUnits) -> Double {
        units == .presentValue ? ownerLifetimeTaxToday * pvDiscountFactor : ownerLifetimeTaxToday
    }
    func heirAfterTaxInheritance(units: DisplayUnits) -> Double {
        units == .presentValue ? heirAfterTaxInheritanceToday * pvDiscountFactor : heirAfterTaxInheritanceToday
    }
    func heirTax(units: DisplayUnits) -> Double {
        units == .presentValue ? heirTaxToday * pvDiscountFactor : heirTaxToday
    }

    // UUID id is excluded from equality (two points are equal if their figures match).
    static func == (lhs: FrontierPoint, rhs: FrontierPoint) -> Bool {
        lhs.weight == rhs.weight
            && lhs.ownerLifetimeTaxToday == rhs.ownerLifetimeTaxToday
            && lhs.heirAfterTaxInheritanceToday == rhs.heirAfterTaxInheritanceToday
            && lhs.heirTaxToday == rhs.heirTaxToday
            && lhs.pvDiscountFactor == rhs.pvDiscountFactor
    }
}

struct HeirFrontierResult: Equatable, Sendable {
    let points: [FrontierPoint]               // ordered by ascending weight
    var baseline: FrontierPoint? { points.first(where: { $0.weight == 0 }) ?? points.first }
}
