import Foundation

/// Single source of truth for V2.0's honest-scope framing: the positioning line and the
/// modeled-vs-simplified limitations. Reused by the tab UI and the CPA briefing PDF so the two
/// never drift. See spec 2026-06-27 sections 2 and 6.6.
enum V2Disclosures {
    /// Non-full-planner positioning. MUST NOT imply complete / full retirement income optimization.
    static let positioning =
        "RetireSmartIRA helps you evaluate multi-year Roth conversions, RMDs, IRMAA, ACA cliffs, survivor tax effects, and heir-tax outcomes using transparent assumptions."

    /// What V2.0 simplifies. Shown in the tab's Assumptions & Limitations section and the CPA PDF.
    static let limitations: [String] = [
        "Taxable-account withdrawals during life use simplified tax treatment: no lot-level cost basis, and capital gains and qualified dividends are not separately rate-tiered.",
        "Withdrawal order follows the assumption you select; the app does not optimize the order across accounts.",
        "Inherited taxable accounts are credited at a stepped-up cost basis, passing to heirs nearly tax-free.",
        "Growth sensitivity is a deterministic high and low band, not a Monte Carlo probability of success.",
        "Tax-exempt municipal interest is excluded from MAGI, so IRMAA, ACA, and Social Security taxation may be understated for muni holders.",
        "The survivor scenario applies single-filer rates from the start of the horizon, a conservative upper bound.",
    ]
}
