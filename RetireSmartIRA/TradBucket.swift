//
//  TradBucket.swift
//  RetireSmartIRA
//
//  A person's own traditional retirement balance, split into IRA and 401(k) portions.
//  QCDs may only be sourced from the IRA portion (a later Phase-1 task), so the engine
//  tracks them separately. All tax/AGI/RMD math uses `total` — the split is behavior-
//  neutral. Non-QCD debits (conversions, withdrawals, RMD, gross-up, auto-funding)
//  deplete the 401(k) portion FIRST, preserving the IRA portion for potential QCDs.
//

import Foundation

struct TradBucket: Equatable, Sendable {
    var ira: Double
    var k401: Double

    var total: Double { ira + k401 }

    /// Debit `amount` (expected 0...total), 401(k) first then IRA. Clamps at 0 (never negative),
    /// mirroring the pre-split `-= min(amount, max(0, balance))` guards.
    mutating func debit(_ amount: Double) {
        let a = max(0, amount)
        let from401k = min(a, max(0, k401))
        k401 -= from401k
        let rest = a - from401k
        ira -= min(rest, max(0, ira))
    }

    /// Apply a growth factor to both portions.
    mutating func grow(_ factor: Double) {
        ira *= factor
        k401 *= factor
    }

    /// Credit a 401(k) contribution to the 401(k) portion.
    mutating func credit401k(_ amount: Double) {
        k401 += max(0, amount)
    }
}
