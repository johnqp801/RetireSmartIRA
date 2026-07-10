//
//  AccountSnapshot.swift
//  RetireSmartIRA
//
//  Value-type snapshot of a household's retirement account balances, collapsed into
//  per-spouse traditional buckets plus combined roth, taxable, and HSA balances.
//
//  The six 1.9 AccountType cases map as follows:
//    primaryTraditional: .traditionalIRA + .traditional401k + .inheritedTraditionalIRA (owner == .primary)
//    spouseTraditional:  .traditionalIRA + .traditional401k + .inheritedTraditionalIRA (owner == .spouse)
//    roth:               .rothIRA + .roth401k + .inheritedRothIRA (both spouses combined)
//    taxable:            user-input balance (not modeled as AccountType in 1.9)
//    hsa:                user-input balance (not modeled as AccountType in 1.9)
//
//  Backwards-compat: the convenience initializer init(traditional:roth:taxable:hsa:) routes
//  all trad to the primary bucket (spouseTraditional = 0). Single-filer tests and pre-split
//  callers continue to work unchanged. The computed property `traditional` sums both buckets.
//

import Foundation

struct AccountSnapshot: Codable, Equatable, Sendable {
    let primaryTraditional: Double  // trad IRA + 401k (primary's own accounts)
    let spouseTraditional: Double   // trad IRA + 401k (spouse's own accounts)
    let roth: Double                // sum of roth IRA + roth 401k (both spouses)
    let taxable: Double             // user-input balance, not modeled as AccountType in 1.9
    let hsa: Double                 // user-input balance, not modeled as AccountType in 1.9
    // Inherited accounts with complete beneficiary metadata are tracked as their own
    // buckets so the engine can apply beneficiary distribution rules (single-life RMDs,
    // 10-year drain) instead of the owner's uniform table. Inherited accounts MISSING
    // metadata still roll into the owner buckets above (legacy fallback).
    let inheritedTraditional: Double
    let inheritedRoth: Double

    init(primaryTraditional: Double, spouseTraditional: Double, roth: Double, taxable: Double, hsa: Double,
         inheritedTraditional: Double = 0, inheritedRoth: Double = 0) {
        self.primaryTraditional = primaryTraditional
        self.spouseTraditional = spouseTraditional
        self.roth = roth
        self.taxable = taxable
        self.hsa = hsa
        self.inheritedTraditional = inheritedTraditional
        self.inheritedRoth = inheritedRoth
    }

    /// Convenience initializer for single-filer / pre-split contexts.
    /// All trad goes to the primary's bucket; spouse's stays at 0.
    init(traditional: Double, roth: Double, taxable: Double, hsa: Double,
         inheritedTraditional: Double = 0, inheritedRoth: Double = 0) {
        self.init(
            primaryTraditional: traditional,
            spouseTraditional: 0,
            roth: roth,
            taxable: taxable,
            hsa: hsa,
            inheritedTraditional: inheritedTraditional,
            inheritedRoth: inheritedRoth
        )
    }

    /// Sum of both spouses' OWN traditional balances (inherited excluded).
    var traditional: Double { primaryTraditional + spouseTraditional }

    var total: Double { traditional + roth + taxable + hsa + inheritedTraditional + inheritedRoth }

    static let zero = AccountSnapshot(primaryTraditional: 0, spouseTraditional: 0, roth: 0, taxable: 0, hsa: 0)
}
