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

struct AccountSnapshot: Codable, Equatable {
    let primaryTraditional: Double  // trad IRA + 401k + inherited trad (primary's accounts)
    let spouseTraditional: Double   // trad IRA + 401k + inherited trad (spouse's accounts)
    let roth: Double                // sum of roth IRA + roth 401k + inherited roth IRA (both spouses)
    let taxable: Double             // user-input balance, not modeled as AccountType in 1.9
    let hsa: Double                 // user-input balance, not modeled as AccountType in 1.9

    init(primaryTraditional: Double, spouseTraditional: Double, roth: Double, taxable: Double, hsa: Double) {
        self.primaryTraditional = primaryTraditional
        self.spouseTraditional = spouseTraditional
        self.roth = roth
        self.taxable = taxable
        self.hsa = hsa
    }

    /// Convenience initializer for single-filer / pre-split contexts.
    /// All trad goes to the primary's bucket; spouse's stays at 0.
    init(traditional: Double, roth: Double, taxable: Double, hsa: Double) {
        self.init(
            primaryTraditional: traditional,
            spouseTraditional: 0,
            roth: roth,
            taxable: taxable,
            hsa: hsa
        )
    }

    /// Sum of both spouses' traditional balances.
    var traditional: Double { primaryTraditional + spouseTraditional }

    var total: Double { traditional + roth + taxable + hsa }

    static let zero = AccountSnapshot(primaryTraditional: 0, spouseTraditional: 0, roth: 0, taxable: 0, hsa: 0)
}
