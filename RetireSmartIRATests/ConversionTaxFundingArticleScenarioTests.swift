//
//  ConversionTaxFundingArticleScenarioTests.swift
//  RetireSmartIRATests
//
//  Pins the published figures in "Paying Roth Conversion Tax From Your IRA"
//  on retiresmartira.com (/articles/paying-roth-conversion-tax-from-your-ira).
//
//  WHY THIS FILE EXISTS
//  --------------------
//  Same reason as WidowTaxArticleScenarioTests: these numbers appear under
//  John's byline in public. If an engine change moves one of them, that is a
//  correction the article needs, not a test to rebaseline. Treat a failure here
//  as "go look at what changed and decide whether the article is now wrong",
//  never as "update the expected value".
//
//  ENGINE CHOICE: the multi-year ProjectionEngine, because funding a
//  conversion's tax from the IRA is a multi-year concept. `rothTaxFundingMode`
//  exists only there, and the gross-up is a fixed point the single-year engine
//  does not run.
//
//  FULL INCOME COMPOSITION IS WRITTEN OUT for every persona below. The widow-tax
//  article lost real time to a $2,876 false alarm because a draft omitted a
//  household's Social Security; that cannot happen again if the composition is
//  in the file.
//
//  WHAT IN THE ARTICLE IS *NOT* ENGINE OUTPUT
//  ------------------------------------------
//  Every dollar figure and every ratio in the article comes from this engine
//  and is pinned below. These claims do NOT, and were written from statute or
//  editorial judgment. If they are ever challenged, no test defends them:
//
//    - "At most 85 percent of a benefit is ever taxable"  -> IRC 86, statutory.
//    - The entire under-59.5 discussion (10% additional tax, IRC 72(t)). The
//      persona is 66, so the engine NEVER exercises the penalty path. Nothing
//      here validates it.
//    - "IRMAA on 2026 income is billed through 2028 premiums" -> program rule.
//    - Withholding rates. 24% is what the MODEL elects, not a universal
//      custodian default; real defaults vary and are often lower. The article
//      was corrected to say so rather than implying an industry standard.
//    - The four "what has to be true for self-funding to make sense"
//      conditions, and all comparisons to the do-nothing alternative (future
//      RMDs, survivor filing single, the heirs' 10-year deadline). No
//      projection was run for any of them.
//
//  WHAT THE ARTICLE MAY AND MAY NOT CLAIM
//  --------------------------------------
//  Verified in code before drafting (2026-07-30):
//    MAY: the gross-up is a real fixed point over federal AND state tax; benefit
//         taxation is recomputed INSIDE that fixed point (ProjectionEngine.swift
//         `additionalIncome: otherIncomeForSSTax + dW + max(0, saleGain)`,
//         shipped in v2.3.0-build63).
//    MAY NOT: claim the gross-up enlarges itself when the funding withdrawal
//         crosses an IRMAA or ACA cliff. IRMAA/ACA/NIIT are deliberately frozen
//         inside the sizing loop (`nonFedState`, commented "NOT recomputed").
//

import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("Conversion tax funding article scenarios (published figures)", .serialized)
@MainActor
struct ConversionTaxFundingArticleScenarioTests {

    private var provider: TaxYearConfigProvider { .fixed(TaxYearConfig.loadOrFallback(forYear: 2026)) }

    /// Article states figures to the nearest dollar or hundred. $10 absorbs that
    /// while still catching a real regression, which moves these by hundreds.
    private let tolerance = 10.0

    // MARK: - Persona: "Dianne"
    //
    // The article names her. She is an illustrative composite, not a client and
    // not derived from any real person's data. Keep the name here in sync with
    // the article: a reader who checks the published persona against this file
    // should find the same household.
    //
    // SINGLE FILER, AGE 66. Past 59.5 (so no early-distribution penalty muddies
    // the comparison), before RMDs begin, and already on Medicare.
    //
    // Income composition, complete:
    //   Social Security  $2,500/mo at FRA, claimed at 66  -> $30,000/yr gross
    //   Wages                                             -> $0
    //   Pension                                           -> $0
    //   Tax-exempt interest                               -> $0
    // Balances:
    //   Traditional IRA                                   -> $1,000,000
    //   Taxable                                           -> $0   <- the whole point
    //   Roth                                              -> $0
    //   HSA                                               -> $0
    // Expenses: $0, so no spending draw competes with the tax funding. This
    // isolates the conversion decision, which is what the article is about.
    //
    // ZERO TAXABLE BALANCE IS DELIBERATE. The cascade funds from taxable assets
    // first and only then grosses up a traditional withdrawal. A household with
    // a brokerage account never reaches the gross-up, so it cannot illustrate it.

    private func inputs(state: String) -> MultiYearStaticInputs {
        MultiYearStaticInputs(
            startingBalances: AccountSnapshot(traditional: 1_000_000, roth: 0, taxable: 0, hsa: 0),
            baseYear: 2026,
            primaryCurrentAge: 66, spouseCurrentAge: nil,
            filingStatus: .single, state: state,
            primarySSClaimAge: 66, spouseSSClaimAge: nil,
            primaryExpectedBenefitAtFRA: 2_500, spouseExpectedBenefitAtFRA: nil,
            primaryBirthYear: 1960, spouseBirthYear: nil,
            primaryWageIncome: 0, spouseWageIncome: 0,
            primaryPensionIncome: 0, spousePensionIncome: 0,
            acaEnrolled: false, acaHouseholdSize: 1,
            primaryMedicareEnrollmentAge: 65, spouseMedicareEnrollmentAge: nil,
            baselineAnnualExpenses: 0
        )
    }

    private func assumptions(_ mode: RothTaxFundingMode) -> MultiYearAssumptions {
        var a = MultiYearAssumptions(
            horizonEndAge: 67, horizonEndAgeSpouse: nil, cpiRate: 0,
            investmentGrowthRate: 0, withdrawalOrderingRule: .taxEfficient,
            stressTestEnabled: false, perYearOverrides: [:],
            currentTaxableBalance: 0, currentHSABalance: 0, baselineAnnualExpenses: 0)
        a.rothTaxFundingMode = mode
        return a
    }

    private func run(state: String, conversion: Double,
                     mode: RothTaxFundingMode) -> YearRecommendation {
        ProjectionEngine(configProvider: provider).project(
            inputs: inputs(state: state),
            assumptions: assumptions(mode),
            actionsPerYear: [2026: [.rothConversion(amount: conversion)], 2027: []]
        ).first!
    }

    // MARK: - Published figures

    /// HEADLINE: "$219,751 leaves the IRA to put $150,000 in the Roth" and
    /// "$1.47 of IRA per $1.00 that arrives".
    @Test("CA $150k: total leaving the IRA, and the ratio the article leads with")
    func californiaHeadlineFigures() {
        let outside = run(state: "CA", conversion: 150_000, mode: .paidFromOutsideMoney)
        let funded = run(state: "CA", conversion: 150_000, mode: .fundedFromAccounts)

        #expect(abs(funded.taxFundingWithdrawal - 69_750.59) < tolerance)

        let totalOut = 150_000 + funded.taxFundingWithdrawal
        #expect(abs(totalOut - 219_751) < tolerance, "published: $219,751 leaves the IRA")

        // "$1.47 of IRA spent per $1.00 reaching the Roth"
        #expect(abs(totalOut / 150_000 - 1.4650) < 0.001)

        #expect(abs(outside.taxBreakdown.total - 44_639.36) < tolerance)
        #expect(abs(funded.taxBreakdown.total - 71_485.79) < tolerance)
        // "+$26,846 additional tax caused by self-funding"
        #expect(abs((funded.taxBreakdown.total - outside.taxBreakdown.total) - 26_846.43) < tolerance)

        #expect(abs(outside.endOfYearBalances.traditional - 850_000) < tolerance)
        #expect(abs(funded.endOfYearBalances.traditional - 780_249.41) < tolerance)

        // The Roth receives the same amount either way. The whole cost of
        // self-funding lands on the traditional side, never on what arrives.
        #expect(abs(outside.endOfYearBalances.roth - funded.endOfYearBalances.roth) < 0.01)
    }

    /// The article deliberately walks the headline ratio back: $1.47 is not
    /// "47 cents burned", because the conversion is taxable however you pay for
    /// it. Only the part ABOVE the tax you would have paid from cash is a real
    /// incremental cost. Published as $25,111, "about 17 percent of the
    /// conversion rather than 47".
    ///
    /// Measured as net wealth, not as tax, so it is not the same as the
    /// $26,846 tax delta. The $1,735 difference is the self-caused IRMAA that
    /// is not billed until 2028; see `irmaaIsNotFundedByTheGrossUp`.
    @Test("The incremental cost of self-funding is $25,111, not the full gross-up")
    func incrementalCostIsSmallerThanTheHeadlineRatio() {
        let outside = run(state: "CA", conversion: 150_000, mode: .paidFromOutsideMoney)
        let funded = run(state: "CA", conversion: 150_000, mode: .fundedFromAccounts)

        // Paying from cash: accounts are whole, but cash left the household.
        let outsideNetWealth = outside.endOfYearBalances.traditional
            + outside.endOfYearBalances.roth
            - outside.taxBreakdown.total
        // Self-funding: nothing left from outside, so the accounts carry it all.
        let fundedNetWealth = funded.endOfYearBalances.traditional
            + funded.endOfYearBalances.roth

        let incremental = outsideNetWealth - fundedNetWealth
        #expect(abs(incremental - 25_111.23) < tolerance, "published: $25,111")

        // Equivalent statement the article makes in prose: of the $69,751
        // withdrawn, $44,639 is tax owed either way and the rest is the extra.
        #expect(abs((funded.taxFundingWithdrawal - outside.taxBreakdown.total) - 25_111.23) < tolerance)

        // "about 17 percent of the conversion rather than 47"
        #expect(abs(incremental / 150_000 - 0.1674) < 0.002)

        // And it is genuinely SMALLER than the tax delta, which is the point of
        // the section. If this ever inverts, the article's framing is wrong.
        let taxDelta = funded.taxBreakdown.total - outside.taxBreakdown.total
        #expect(incremental < taxDelta)
    }

    /// The withholding section claims withholding is "a different trade, not a
    /// cheaper one": its lower total tax comes from converting LESS, not from
    /// costing less per dollar converted.
    @Test("Withholding's lower total tax is a smaller conversion, not a discount")
    func withholdingIsASmallerConversionNotADiscount() {
        let withheld = run(state: "CA", conversion: 150_000, mode: .withheldFromConversion)
        let funded = run(state: "CA", conversion: 150_000, mode: .fundedFromAccounts)

        #expect(abs(withheld.taxBreakdown.total - 51_979.66) < tolerance, "published: $51,980")
        #expect(abs(funded.taxBreakdown.total - 71_485.79) < tolerance, "published: $71,486")
        #expect(withheld.taxBreakdown.total < funded.taxBreakdown.total,
                "withholding really does show a lower total, which is why the section exists")

        // The reason: less reaches the Roth. $114,000 against $150,000.
        #expect(abs(withheld.endOfYearBalances.roth - 114_000) < tolerance, "published: $114,000")
        #expect(abs(funded.endOfYearBalances.roth - 150_000) < tolerance)
    }

    /// The state-tax comparison table: $1.30 in Florida against $1.47 in California.
    @Test("FL vs CA at $150k: the gap is state tax compounding through the gross-up")
    func stateComparisonFigures() {
        let fl = run(state: "FL", conversion: 150_000, mode: .fundedFromAccounts)
        let ca = run(state: "CA", conversion: 150_000, mode: .fundedFromAccounts)

        #expect(abs(fl.taxFundingWithdrawal - 45_469.37) < tolerance)
        #expect(abs(fl.taxBreakdown.total - 47_204.57) < tolerance)
        #expect(abs((150_000 + fl.taxFundingWithdrawal) - 195_469) < tolerance)
        #expect(abs((150_000 + fl.taxFundingWithdrawal) / 150_000 - 1.3031) < 0.001)

        #expect(abs(fl.taxBreakdown.state) < 0.01, "Florida has no state income tax")
        #expect(abs(ca.taxBreakdown.state - 16_569.44) < tolerance)
    }

    /// The Social Security section: a 12% statutory bracket paying an effective
    /// 17.4% on the dollars withdrawn to fund the tax.
    @Test("FL $40k: benefit taxation feedback pushes 12% to an effective 17.4%")
    func socialSecurityFeedbackFigures() {
        let outside = run(state: "FL", conversion: 40_000, mode: .paidFromOutsideMoney)
        let funded = run(state: "FL", conversion: 40_000, mode: .fundedFromAccounts)

        #expect(abs(outside.taxableSocialSecurity - 21_500) < tolerance)
        #expect(abs(funded.taxableSocialSecurity - 23_800) < tolerance)
        // "+$2,300 additional benefit dragged into taxation"
        #expect(abs((funded.taxableSocialSecurity - outside.taxableSocialSecurity) - 2_300) < tolerance)

        #expect(abs(outside.taxBreakdown.total - 4_234) < tolerance)
        #expect(abs(funded.taxBreakdown.total - 5_125) < tolerance)

        let withdrawal = funded.taxFundingWithdrawal
        let extraTax = funded.taxBreakdown.total - outside.taxBreakdown.total
        #expect(abs(withdrawal - 5_125) < tolerance)
        #expect(abs(extraTax - 891) < tolerance)
        // Published: 17.4% effective on those dollars.
        #expect(abs(extraTax / withdrawal - 0.174) < 0.002)

        // And the statutory bracket really is 12%: the added taxable income is
        // the withdrawal PLUS the benefit it dragged in, and 12% of that is the
        // added tax to the dollar. This is what makes the 17.4% a feedback
        // effect rather than a bracket.
        let addedTaxableIncome = withdrawal
            + (funded.taxableSocialSecurity - outside.taxableSocialSecurity)
        #expect(abs(extraTax / addedTaxableIncome - 0.12) < 0.002)
    }

    /// The ceiling argument: at $150k the benefit is already 85% taxable, so the
    /// feedback is identically zero. The article claims this explains why the
    /// effect bites modest conversions rather than large ones.
    @Test("At $150k the benefit is already at its 85% ceiling, so feedback is zero")
    func feedbackVanishesAtTheCeiling() {
        let outside = run(state: "FL", conversion: 150_000, mode: .paidFromOutsideMoney)
        let funded = run(state: "FL", conversion: 150_000, mode: .fundedFromAccounts)

        #expect(abs(outside.taxableSocialSecurity - funded.taxableSocialSecurity) < 0.01,
                "no feedback once benefits are saturated")
        #expect(abs(funded.taxableSocialSecurity - 23_800) < tolerance)

        // The article states the persona's benefit as "$28,000 a year", which
        // is not an input: the input is $2,500/mo at FRA, and the engine applies
        // the early-claim reduction for claiming at 66 against an FRA of 67.
        // Recover it from the saturated figure, since at the ceiling
        // taxableSS == 0.85 * gross. Pinned so the published persona
        // description cannot drift from what the engine actually modeled.
        let grossBenefit = funded.taxableSocialSecurity / 0.85
        #expect(abs(grossBenefit - 28_000) < tolerance,
                "published persona: $28,000 a year of Social Security")
    }

    /// Withholding: a 24% default election lands $30,400 in the Roth on a
    /// $40,000 conversion whose actual tax was $4,234.
    @Test("Withholding at the default rate strands Roth space permanently")
    func withholdingFigures() {
        let withheld = run(state: "FL", conversion: 40_000, mode: .withheldFromConversion)
        let outside = run(state: "FL", conversion: 40_000, mode: .paidFromOutsideMoney)

        #expect(abs(withheld.endOfYearBalances.roth - 30_400) < tolerance,
                "published: $30,400 reaches the Roth")
        #expect(abs((40_000 - withheld.endOfYearBalances.roth) - 9_600) < tolerance,
                "published: $9,600 withheld at the 24% default")
        #expect(abs(outside.taxBreakdown.total - 4_234) < tolerance,
                "published: the tax actually owed was $4,234")
    }

    /// The IRMAA caveat the article states explicitly. The funding withdrawal
    /// raises the surcharge, and the gross-up does NOT grow to cover it. This
    /// pins the documented limit so a future change to the sizing loop shows up
    /// here as a claim the article can no longer make.
    @Test("The gross-up does not fund the IRMAA tier it crosses")
    func irmaaIsNotFundedByTheGrossUp() {
        let outside = run(state: "FL", conversion: 150_000, mode: .paidFromOutsideMoney)
        let funded = run(state: "FL", conversion: 150_000, mode: .fundedFromAccounts)

        #expect(abs(outside.taxBreakdown.irmaa - 4_620) < tolerance)
        #expect(abs(funded.taxBreakdown.irmaa - 6_355.20) < tolerance)

        // The shortfall between the withdrawal and the total is EXACTLY the
        // IRMAA increase the withdrawal itself caused.
        let irmaaIncrease = funded.taxBreakdown.irmaa - outside.taxBreakdown.irmaa
        let shortfall = funded.taxBreakdown.total - funded.taxFundingWithdrawal
        #expect(abs(shortfall - irmaaIncrease) < tolerance,
                "the unfunded remainder is the self-caused IRMAA, nothing else")
    }

    /// None of these households is insolvent. The article describes a cost, not
    /// a failure, and an `isInfeasible` year would mean something else entirely.
    @Test("Every published scenario is fully funded, not infeasible")
    func scenariosAreFeasible() {
        for conversion in [40_000.0, 150_000.0] {
            for state in ["FL", "CA"] {
                for mode in [RothTaxFundingMode.paidFromOutsideMoney,
                             .fundedFromAccounts, .withheldFromConversion] {
                    let y = run(state: state, conversion: conversion, mode: mode)
                    #expect(y.isFullyFunded, "\(state) \(conversion) \(mode) should be fully funded")
                }
            }
        }
    }

    /// Emits the article's tables. Not an assertion: this is how the published
    /// numbers were produced, kept so they can be regenerated rather than
    /// re-derived by hand.
    @Test("EMIT: article figures")
    func emitArticleFigures() {
        var out = "\n===== CONVERSION TAX FUNDING: ARTICLE FIGURES =====\n"
        for conversion in [40_000.0, 150_000.0] {
            for state in ["FL", "CA"] {
                out += "\n--- \(state), conversion $\(Int(conversion)) ---\n"
                for mode in [RothTaxFundingMode.paidFromOutsideMoney,
                             .fundedFromAccounts,
                             .withheldFromConversion] {
                    let y = run(state: state, conversion: conversion, mode: mode)
                    let t = y.taxBreakdown
                    out += String(
                        format: "%-22@ grossUp %10.2f  total %10.2f  fed %10.2f  state %9.2f  irmaa %8.2f  taxableSS %9.2f  converted %10.2f  tradEnd %12.2f  rothEnd %11.2f  under %7.2f  infeas %@\n",
                        String(describing: mode) as NSString,
                        y.taxFundingWithdrawal, t.total, t.federal, t.state, t.irmaa,
                        y.taxableSocialSecurity,
                        y.executedRothConversion,
                        y.endOfYearBalances.traditional,
                        y.endOfYearBalances.roth,
                        y.underfunded ?? 0,
                        y.isInfeasible ? "YES" : "no"
                    )
                }
            }
        }
        out += "\n==================================================\n"
        print(out)
    }
}
