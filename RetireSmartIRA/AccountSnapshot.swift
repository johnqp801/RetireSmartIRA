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
    let primaryTraditionalIRA: Double
    let primaryTraditional401k: Double
    let spouseTraditionalIRA: Double
    let spouseTraditional401k: Double
    let roth: Double                // sum of roth IRA + roth 401k (both spouses)
    let taxable: Double
    let hsa: Double
    let inheritedTraditional: Double
    let inheritedRoth: Double

    // Combined owner traditional per spouse (IRA + 401k). Preserves the pre-split API for
    // all existing consumers (RMD basis, snapshots, tests). Tax/RMD math uses these totals.
    var primaryTraditional: Double { primaryTraditionalIRA + primaryTraditional401k }
    var spouseTraditional: Double { spouseTraditionalIRA + spouseTraditional401k }

    /// Full-split memberwise init (used by the adapter with real IRA/401k balances).
    init(primaryTraditionalIRA: Double, primaryTraditional401k: Double,
         spouseTraditionalIRA: Double, spouseTraditional401k: Double,
         roth: Double, taxable: Double, hsa: Double,
         inheritedTraditional: Double = 0, inheritedRoth: Double = 0) {
        self.primaryTraditionalIRA = primaryTraditionalIRA
        self.primaryTraditional401k = primaryTraditional401k
        self.spouseTraditionalIRA = spouseTraditionalIRA
        self.spouseTraditional401k = spouseTraditional401k
        self.roth = roth
        self.taxable = taxable
        self.hsa = hsa
        self.inheritedTraditional = inheritedTraditional
        self.inheritedRoth = inheritedRoth
    }

    /// Backward-compat init: callers that don't know the IRA/401k split route the combined
    /// per-spouse balance to the IRA portion (k401 = 0). Behavior-neutral for all tax/RMD math.
    init(primaryTraditional: Double, spouseTraditional: Double, roth: Double, taxable: Double, hsa: Double,
         inheritedTraditional: Double = 0, inheritedRoth: Double = 0) {
        self.init(primaryTraditionalIRA: primaryTraditional, primaryTraditional401k: 0,
                  spouseTraditionalIRA: spouseTraditional, spouseTraditional401k: 0,
                  roth: roth, taxable: taxable, hsa: hsa,
                  inheritedTraditional: inheritedTraditional, inheritedRoth: inheritedRoth)
    }

    /// Convenience for single-filer / pre-split contexts. All trad to the primary IRA bucket.
    init(traditional: Double, roth: Double, taxable: Double, hsa: Double,
         inheritedTraditional: Double = 0, inheritedRoth: Double = 0) {
        self.init(primaryTraditional: traditional, spouseTraditional: 0,
                  roth: roth, taxable: taxable, hsa: hsa,
                  inheritedTraditional: inheritedTraditional, inheritedRoth: inheritedRoth)
    }

    /// Sum of both spouses' OWN traditional balances (inherited excluded).
    var traditional: Double { primaryTraditional + spouseTraditional }
    var total: Double { traditional + roth + taxable + hsa + inheritedTraditional + inheritedRoth }

    static let zero = AccountSnapshot(primaryTraditionalIRA: 0, primaryTraditional401k: 0,
                                      spouseTraditionalIRA: 0, spouseTraditional401k: 0,
                                      roth: 0, taxable: 0, hsa: 0)

    private enum CodingKeys: String, CodingKey {
        case primaryTraditionalIRA, primaryTraditional401k, spouseTraditionalIRA, spouseTraditional401k
        case primaryTraditional, spouseTraditional  // legacy keys (pre-split persisted data)
        case roth, taxable, hsa, inheritedTraditional, inheritedRoth
    }

    // Custom decode: new split keys if present, else fall back to legacy combined keys
    // (route to the IRA portion). Custom encode: always write the split keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let ira = try c.decodeIfPresent(Double.self, forKey: .primaryTraditionalIRA) {
            primaryTraditionalIRA = ira
            primaryTraditional401k = try c.decodeIfPresent(Double.self, forKey: .primaryTraditional401k) ?? 0
            spouseTraditionalIRA = try c.decodeIfPresent(Double.self, forKey: .spouseTraditionalIRA) ?? 0
            spouseTraditional401k = try c.decodeIfPresent(Double.self, forKey: .spouseTraditional401k) ?? 0
        } else {
            primaryTraditionalIRA = try c.decodeIfPresent(Double.self, forKey: .primaryTraditional) ?? 0
            primaryTraditional401k = 0
            spouseTraditionalIRA = try c.decodeIfPresent(Double.self, forKey: .spouseTraditional) ?? 0
            spouseTraditional401k = 0
        }
        roth = try c.decode(Double.self, forKey: .roth)
        taxable = try c.decode(Double.self, forKey: .taxable)
        hsa = try c.decode(Double.self, forKey: .hsa)
        inheritedTraditional = try c.decodeIfPresent(Double.self, forKey: .inheritedTraditional) ?? 0
        inheritedRoth = try c.decodeIfPresent(Double.self, forKey: .inheritedRoth) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(primaryTraditionalIRA, forKey: .primaryTraditionalIRA)
        try c.encode(primaryTraditional401k, forKey: .primaryTraditional401k)
        try c.encode(spouseTraditionalIRA, forKey: .spouseTraditionalIRA)
        try c.encode(spouseTraditional401k, forKey: .spouseTraditional401k)
        try c.encode(roth, forKey: .roth)
        try c.encode(taxable, forKey: .taxable)
        try c.encode(hsa, forKey: .hsa)
        try c.encode(inheritedTraditional, forKey: .inheritedTraditional)
        try c.encode(inheritedRoth, forKey: .inheritedRoth)
    }
}
