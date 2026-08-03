import Foundation

/// Reduces a computed retirement-income exclusion as income rises.
///
/// Six jurisdictions in the 2026-08-02 audit need this (CT, VA, ME, RI, WV,
/// NM) and before Phase 3a only New Jersey had a mechanism, bespoke to its own
/// stepped Worksheet D bands. For a Roth conversion planner this matters more
/// than the individual state values: a large conversion is precisely what
/// lifts AGI through these thresholds, so modeling an exemption as
/// unconditional promises the user something the recommended action destroys.
///
/// INCOME BASIS, NOT YET VERIFIED. `reduced(exclusion:totalGrossIncome:...)`
/// is called with the same total-gross-income figure New Jersey's stepped
/// tiers already gate on. Several statutes key off a state-specific AGI that
/// is not that number (Virginia uses Virginia AFAGI). Phase 3a does not decide
/// this, because no state carries a phase-out yet; each state's Phase 4 golden
/// scenario pins its own basis and Phase 5 corrects the call site if needed.
/// Do not read this type's existence as evidence the basis was checked.
struct AGIPhaseout: Codable, Equatable, Sendable {
    /// Income at or below which the exclusion is unreduced, for a single filer.
    let thresholdSingle: Double

    /// The same, for a joint return.
    let thresholdMFJ: Double

    let shape: Shape

    enum Shape: Equatable, Sendable {
        /// The exclusion drops to zero the moment income exceeds the
        /// threshold. New Mexico's $28,500 / $51,000 limits are this shape.
        ///
        /// BOUNDARY CONVENTION, not yet verified against any statute: income
        /// exactly AT the threshold is UNREDUCED, and reduction begins one
        /// dollar above it. The audit's wording for New Mexico ("requires AGI
        /// under $28,500") reads as exclusive, which would differ from this by
        /// the entire exclusion at exactly $28,500. Each state's Phase 4 golden
        /// scenario must pin its own boundary; do not assume this one.
        case cliff

        /// The exclusion is reduced by `perDollar` for every dollar of income
        /// above the threshold, floored at zero.
        ///
        /// Virginia reduces $1 per $1, so `perDollar` is 1.0. A ramp that
        /// reaches zero at some `end` is `perDollar = exclusion / (end - threshold)`.
        case linear(perDollar: Double)
    }

    func reduced(exclusion: Double, totalGrossIncome: Double, isMarried: Bool) -> Double {
        let threshold = isMarried ? thresholdMFJ : thresholdSingle
        let excess = totalGrossIncome - threshold
        guard excess > 0 else { return exclusion }
        switch shape {
        case .cliff:
            return 0
        case .linear(let perDollar):
            return max(0, exclusion - excess * perDollar)
        }
    }
}
