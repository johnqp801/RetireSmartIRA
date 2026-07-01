import Foundation

/// Single source of truth for V2.0's honest-scope framing: the positioning line and the
/// modeled-vs-simplified limitations. Reused by the tab UI and the CPA briefing PDF so the two
/// never drift. See spec 2026-06-27 sections 2 and 6.6.
enum V2Disclosures {
    /// Non-full-planner positioning. MUST NOT imply complete / full retirement income optimization.
    static let positioning =
        "RetireSmartIRA helps you evaluate multi-year Roth conversions, RMDs, IRMAA, ACA cliffs, survivor tax effects, taxable-account interactions, and heir-tax outcomes using transparent assumptions."

    /// What the plan reads. Shown in the tab's "What this plan covers" section.
    static let inputsUsed =
        "This plan uses your IRA, Roth, and inherited-IRA balances, taxable accounts, Social Security, income, deductions, expenses, growth assumptions, IRMAA and ACA thresholds, and legacy settings."

    /// What V2.0 simplifies. Shown in the tab's Assumptions & Limitations section and the CPA PDF.
    static let limitations: [String] = [
        "Taxable-account sales use an average cost-basis estimate, not lot-level tax-lot selection or short-term versus long-term holding periods.",
        "Withdrawal order follows the assumption you select; the app does not optimize the order across accounts.",
        "Inherited taxable accounts are credited at a stepped-up cost basis, passing to heirs nearly tax-free.",
        "Growth sensitivity is a deterministic high and low band, not a Monte Carlo probability of success.",
        "The survivor scenario applies single-filer rates from the start of the horizon, a conservative upper bound.",
        "Wages, pension, and investment income are entered as steady annual amounts; income that starts or stops mid-horizon is not yet modeled.",
    ]
}
