//
//  PersistedConversionApproach.swift
//  RetireSmartIRA
//
//  Codable persistence shim for `ConversionApproach` (which has associated values). Stored on
//  `MultiYearAssumptions` so the user's selected approach survives relaunch.
//

import Foundation

struct PersistedConversionApproach: Codable, Equatable, Sendable {
    enum Kind: String, Codable { case recommendedTaxMin, fillToBracket, limitToIRMAA }
    let kind: Kind
    let rate: Double?
    let tier: Int?
    let buffer: Double?

    static let recommendedTaxMin = PersistedConversionApproach(.recommendedTaxMin)

    init(_ approach: ConversionApproach) {
        switch approach {
        case .recommendedTaxMin:
            kind = .recommendedTaxMin; rate = nil; tier = nil; buffer = nil
        case .fillToBracket(let r):
            kind = .fillToBracket; rate = r; tier = nil; buffer = nil
        case .limitToIRMAA(let t, let b):
            kind = .limitToIRMAA; rate = nil; tier = t; buffer = b
        }
    }

    func toApproach() -> ConversionApproach {
        switch kind {
        case .recommendedTaxMin: return .recommendedTaxMin
        case .fillToBracket:     return .fillToBracket(rate: rate ?? 0.24)
        case .limitToIRMAA:      return .limitToIRMAA(tier: tier ?? 1, buffer: buffer ?? 5_000)
        }
    }
}
