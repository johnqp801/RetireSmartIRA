//
//  AccountSnapshot.swift
//  RetireSmartIRA
//
//  Value-type snapshot of a household's retirement account balances, collapsed into
//  the two engine buckets (traditional, roth) plus user-input taxable and HSA balances.
//
//  The six 1.9 AccountType cases map as follows:
//    traditional: .traditionalIRA + .traditional401k + .inheritedTraditionalIRA
//    roth:        .rothIRA + .roth401k + .inheritedRothIRA
//    taxable:     user-input balance (not modeled as AccountType in 1.9)
//    hsa:         user-input balance (not modeled as AccountType in 1.9)
//

import Foundation

struct AccountSnapshot: Codable, Equatable {
    let traditional: Double  // sum of trad IRA + trad 401k + inherited trad IRA
    let roth: Double          // sum of roth IRA + roth 401k + inherited roth IRA
    let taxable: Double       // user-input balance, not modeled as AccountType in 1.9
    let hsa: Double           // user-input balance, not modeled as AccountType in 1.9

    init(traditional: Double, roth: Double, taxable: Double, hsa: Double) {
        self.traditional = traditional
        self.roth = roth
        self.taxable = taxable
        self.hsa = hsa
    }

    var total: Double { traditional + roth + taxable + hsa }
    static let zero = AccountSnapshot(traditional: 0, roth: 0, taxable: 0, hsa: 0)
}
