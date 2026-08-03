import Foundation

/// A state's personal exemption: an amount subtracted from state taxable
/// income AFTER retirement-income exclusions and their income-gated
/// phase-outs, because those phase-outs key off total income rather than
/// income net of exemptions.
///
/// This did not exist as a field before Phase 3a. New Jersey's was a hardcoded
/// function (`TaxCalculationEngine.njPersonalExemptions`) and California's are
/// credits rather than exemptions, computed separately. Kansas has one and the
/// app grants none, which overstates every married Kansas filer by $952.64 a
/// year: that is Steve Nicolai's 2026-08-01 report, and it is corrected in
/// Phase 5a, not here.
///
/// Amounts are stated per RETURN, not per filer, because that is how state
/// instructions publish them. New Jersey's $1,000-per-filer regular exemption
/// therefore appears as `single: 1_000, marriedFilingJointly: 2_000`.
struct StatePersonalExemption: Codable, Equatable, Sendable {
    /// Total regular exemption for a single filer.
    let single: Double

    /// Total regular exemption for a joint return with a spouse configured.
    let marriedFilingJointly: Double

    /// Additional amount granted for EACH filer at or above `seniorAge`.
    /// New Jersey grants $1,000 each. Most states grant nothing; set 0.
    let seniorAdditionalPerFiler: Double

    /// Age at which `seniorAdditionalPerFiler` applies. Ignored when that is 0.
    let seniorAge: Int

    /// The exemption for this household.
    ///
    /// `enableSpouse` is a separate argument rather than being inferred from
    /// `filingStatus` on purpose: the app allows a filing status of married
    /// filing jointly with no spouse actually configured, and the behavior this
    /// replaces treated that case as a single filer. Reproducing it exactly is
    /// a Phase 3a requirement.
    func amount(
        filingStatus: FilingStatus,
        enableSpouse: Bool,
        primaryAge: Int,
        spouseAge: Int
    ) -> Double {
        let hasSpouse = filingStatus == .marriedFilingJointly && enableSpouse
        var total = hasSpouse ? marriedFilingJointly : single
        if seniorAdditionalPerFiler > 0 {
            if primaryAge >= seniorAge { total += seniorAdditionalPerFiler }
            if hasSpouse && spouseAge >= seniorAge { total += seniorAdditionalPerFiler }
        }
        return total
    }
}
