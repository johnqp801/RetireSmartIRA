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
        "The 10% additional tax on distributions before age 59 and a half is not modeled; plans that withhold from a conversion or fund tax from an IRA before that age understate both the tax and the withdrawal needed to pay it.",
    ]

    /// Shown wherever IRA dollars can end up paying conversion tax, by withholding or by
    /// a grossed-up withdrawal. This is the concern that prompted the feature.
    static let edSlottIRAFunding =
        "Paying conversion tax with IRA dollars leaves less in the account to grow tax free, and the dollars used to pay the tax are themselves taxable. Many advisors prefer paying from outside savings when that option exists. This plan shows the full IRA outflow so you can see the tradeoff."

    /// Shown when either spouse is under 59.5 and the selected mode can touch IRA dollars.
    /// The additional tax is deliberately NOT modeled in V2.3.
    static let earlyDistributionNotModeled =
        "If you are under 59 and a half, dollars withheld from a conversion or withdrawn to pay tax may be treated as an early distribution and subject to a 10% additional tax. This app does not model that additional tax, so both the tax shown and the withdrawal needed to pay it may be understated. Consult a tax professional before electing withholding or funding tax from an IRA under age 59 and a half."

    /// Explains an infeasible year: the amount, what the engine did, and what it means.
    ///
    /// Deliberately claims NOTHING about comparison or ranking. The optimizer's candidate
    /// selection (`OptimizationEngine.keepBestOfCandidates`) ranks purely on objective cost
    /// and reads none of `isInfeasible`, `dependsOnInfeasibleYear`, `isFullyFunded`, or
    /// `underfunded`, so an infeasible strategy is NOT excluded from lifetime comparisons.
    /// Actually excluding it would change which candidate is returned and move every
    /// downstream figure, so it is a separate cycle. Until it exists, this copy must not
    /// promise it. Every clause below is independently verified against the engine.
    static func infeasibleYearExplanation(shortfall: Double) -> String {
        let amount = shortfall.formatted(.number.precision(.fractionLength(0)))
        return "Tax funding shortfall: $\(amount). Available taxable and IRA assets were not enough to fund this year's modeled tax. The requested conversion was not reduced, so this year is shown as requested for diagnosis rather than as a funded recommendation. Later years that build on this year's balances are not reliable."
    }

    /// Shown on a year that did NOT fail on its own but whose opening balances descend from a
    /// year that did. Kept separate from `infeasibleYearExplanation` on purpose: collapsing the
    /// two would either invent a shortfall this year never had, or bury a shortfall it did.
    /// Carries no dollar amount, because nothing was short here.
    static let dependsOnInfeasibleYearExplanation =
        "This year builds on an earlier year whose tax could not be funded. Its opening balances come from a position the household could not actually have reached, so the figures shown here are not reliable."
}
