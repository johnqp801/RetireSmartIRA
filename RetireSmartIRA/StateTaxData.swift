//
//  StateTaxData.swift
//  RetireSmartIRA
//
//  State income tax configurations for all 50 US states + DC.
//  2026 tax year data. Isolates state tax data from the main DataManager
//  for easy annual updates — bracket changes are pure data entry.
//

import Foundation

// MARK: - US State Enum

/// All 50 US states plus the District of Columbia.
/// Raw values are full display names; abbreviations via computed property.
enum USState: String, Codable, CaseIterable, Identifiable {
    case alabama = "Alabama"
    case alaska = "Alaska"
    case arizona = "Arizona"
    case arkansas = "Arkansas"
    case california = "California"
    case colorado = "Colorado"
    case connecticut = "Connecticut"
    case delaware = "Delaware"
    case districtOfColumbia = "District of Columbia"
    case florida = "Florida"
    case georgia = "Georgia"
    case hawaii = "Hawaii"
    case idaho = "Idaho"
    case illinois = "Illinois"
    case indiana = "Indiana"
    case iowa = "Iowa"
    case kansas = "Kansas"
    case kentucky = "Kentucky"
    case louisiana = "Louisiana"
    case maine = "Maine"
    case maryland = "Maryland"
    case massachusetts = "Massachusetts"
    case michigan = "Michigan"
    case minnesota = "Minnesota"
    case mississippi = "Mississippi"
    case missouri = "Missouri"
    case montana = "Montana"
    case nebraska = "Nebraska"
    case nevada = "Nevada"
    case newHampshire = "New Hampshire"
    case newJersey = "New Jersey"
    case newMexico = "New Mexico"
    case newYork = "New York"
    case northCarolina = "North Carolina"
    case northDakota = "North Dakota"
    case ohio = "Ohio"
    case oklahoma = "Oklahoma"
    case oregon = "Oregon"
    case pennsylvania = "Pennsylvania"
    case rhodeIsland = "Rhode Island"
    case southCarolina = "South Carolina"
    case southDakota = "South Dakota"
    case tennessee = "Tennessee"
    case texas = "Texas"
    case utah = "Utah"
    case vermont = "Vermont"
    case virginia = "Virginia"
    case washington = "Washington"
    case westVirginia = "West Virginia"
    case wisconsin = "Wisconsin"
    case wyoming = "Wyoming"

    var id: String { rawValue }

    /// Two-letter postal abbreviation
    var abbreviation: String {
        switch self {
        case .alabama: "AL"
        case .alaska: "AK"
        case .arizona: "AZ"
        case .arkansas: "AR"
        case .california: "CA"
        case .colorado: "CO"
        case .connecticut: "CT"
        case .delaware: "DE"
        case .districtOfColumbia: "DC"
        case .florida: "FL"
        case .georgia: "GA"
        case .hawaii: "HI"
        case .idaho: "ID"
        case .illinois: "IL"
        case .indiana: "IN"
        case .iowa: "IA"
        case .kansas: "KS"
        case .kentucky: "KY"
        case .louisiana: "LA"
        case .maine: "ME"
        case .maryland: "MD"
        case .massachusetts: "MA"
        case .michigan: "MI"
        case .minnesota: "MN"
        case .mississippi: "MS"
        case .missouri: "MO"
        case .montana: "MT"
        case .nebraska: "NE"
        case .nevada: "NV"
        case .newHampshire: "NH"
        case .newJersey: "NJ"
        case .newMexico: "NM"
        case .newYork: "NY"
        case .northCarolina: "NC"
        case .northDakota: "ND"
        case .ohio: "OH"
        case .oklahoma: "OK"
        case .oregon: "OR"
        case .pennsylvania: "PA"
        case .rhodeIsland: "RI"
        case .southCarolina: "SC"
        case .southDakota: "SD"
        case .tennessee: "TN"
        case .texas: "TX"
        case .utah: "UT"
        case .vermont: "VT"
        case .virginia: "VA"
        case .washington: "WA"
        case .westVirginia: "WV"
        case .wisconsin: "WI"
        case .wyoming: "WY"
        }
    }
}

// MARK: - State Tax System Types

/// The type of income tax system a state uses.
enum StateTaxSystem {
    /// No state income tax (AK, FL, NV, SD, TN, TX, WY)
    case noIncomeTax

    /// Flat tax rate applied to all taxable income (IL, CO, IN, etc.)
    case flat(rate: Double)

    /// Progressive brackets with different rates at each threshold
    case progressive(single: [TaxBracket], married: [TaxBracket])

    /// States with limited/special income tax (NH: dividends/interest only; WA: capital gains only)
    case specialLimited

    /// Whether this tax system produces meaningful income tax for retirement planning.
    var hasIncomeTax: Bool {
        switch self {
        case .noIncomeTax, .specialLimited: return false
        case .flat, .progressive: return true
        }
    }
}

// MARK: - Retirement Income Exemptions

/// State-level exemptions for retirement income sources.
/// Critical for a retirement IRA planning app — these dramatically affect state tax liability.
struct RetirementIncomeExemptions {
    /// Whether Social Security benefits are exempt from state income tax (42 states exempt)
    var socialSecurityExempt: Bool = true

    /// Whether pension income is exempt from state income tax
    var pensionExemption: ExemptionLevel = .none

    /// Whether IRA/401(k) withdrawals are exempt from state income tax
    var iraWithdrawalExemption: ExemptionLevel = .none

    /// Whether the `.partial(maxExempt:)` cap applies PER-INDIVIDUAL rather
    /// than per-return. When `true` and filing status is MFJ AND both spouses
    /// are 59½+, the engine doubles the cap (effectively granting each
    /// spouse their own exclusion). When `false` (default) the cap is
    /// household-wide.
    ///
    /// States where this matters: NY ($20K per IT-201 pension/annuity
    /// exclusion under § 612(c)(3-a)). Other per-individual states (MD's
    /// pension exclusion under § 10-209, GA, NJ, CT) will likely adopt this
    /// flag in follow-up releases when their attribution rules are verified.
    var exemptionAppliesPerIndividual: Bool = false

    /// Minimum age for the regular pension/IRA exemption to apply. When 0
    /// (default), no age gate on pension income from explicit
    /// `IncomeSource.pension` rows; scenario-distribution income (RMDs +
    /// extra withdrawals) is still gated at 59½ by the engine.
    ///
    /// States that need a higher minimum: GA (62/65 tiered, set to 65 with
    /// `earlyAgeTier` covering 62-64), MD (65, but pension subtraction has
    /// its own DOR-tested age rule of 65 separately), NJ (62), CO (55/65).
    var regularExemptionMinAge: Int = 0

    /// Optional reduced exemption for an early-age tier. When the taxpayer
    /// is in `tier.ageRange`, BOTH `pensionExemption` and
    /// `iraWithdrawalExemption` are temporarily replaced with `tier.level`
    /// for the calculation. At ages above the tier's upper bound, the
    /// regular fields apply (subject to `regularExemptionMinAge`). Below
    /// the tier's lower bound, no exemption applies.
    ///
    /// Used by states with age-tiered exclusions, e.g., Georgia O.C.G.A.
    /// § 48-7-27(a)(5): $35K for ages 62-64, $65K for ages 65+.
    var earlyAgeTier: AgeTier? = nil

    /// When `true`, the `.partial(maxExempt:)` caps for `pensionExemption`
    /// and `iraWithdrawalExemption` are treated as a SINGLE SHARED cap
    /// across both income types — total exempt = min(pension + IRA, cap).
    /// When `false` (default), each type's cap is applied independently.
    ///
    /// Used by states whose statutes count pensions and IRA distributions
    /// together against one annual subtraction, e.g., Colorado C.R.S.
    /// § 39-22-104(4)(f) ("amounts received as pensions and annuities,"
    /// which by Colorado DOR guidance includes IRA distributions counting
    /// against the same annual cap).
    ///
    /// When `true`, the engine uses the `pensionExemption.partial.maxExempt`
    /// value as the shared cap. `iraWithdrawalExemption` should be set to
    /// the same `.partial` value for documentation clarity; the engine will
    /// ignore the second one to avoid double-counting.
    var pensionAndIRAShareSingleCap: Bool = false

    /// How the state treats capital gains
    var capitalGainsTreatment: CapGainsTreatment = .followsFederal

    /// Reduced exemption that applies only within a specific age band.
    /// Below `ageRange.lowerBound`: no exemption. Within `ageRange`: `level`.
    /// Above `ageRange.upperBound`: use the regular pension/IRA exemption
    /// fields on the containing `RetirementIncomeExemptions`.
    struct AgeTier {
        let ageRange: ClosedRange<Int>
        let level: ExemptionLevel
    }

    enum ExemptionLevel {
        /// No exemption — fully taxed as ordinary income
        case none
        /// Fully exempt from state income tax
        case full
        /// Partially exempt — first N dollars exempt
        case partial(maxExempt: Double)
    }

    enum CapGainsTreatment {
        /// State follows federal preferential rates (0%/15%/20%) — most states
        case followsFederal
        /// State taxes capital gains as ordinary income (CA and a few others)
        case taxedAsOrdinary
        /// No state tax on capital gains (no-income-tax states, or special treatment)
        case noStateTax
    }
}

// MARK: - State Standard Deduction

/// How a state handles standard deductions. Some states have their own amounts,
/// some conform to the federal standard deduction, and some have no standard deduction at all.
enum StateDeduction {
    /// No standard deduction — state may use personal exemptions or none at all (IL, PA, NJ, etc.)
    case none
    /// State conforms to / starts from federal taxable income (CO, AZ, ID, etc.)
    case conformsToFederal
    /// State has its own fixed standard deduction amounts
    case fixed(single: Double, married: Double)
}

// MARK: - State Tax Configuration

/// Complete tax configuration for a single state in a single tax year.
/// All state-specific tax rules are co-located here for easy annual maintenance.
struct StateTaxConfig {
    let state: USState
    let taxSystem: StateTaxSystem
    let retirementExemptions: RetirementIncomeExemptions
    let stateDeduction: StateDeduction
    /// Quarterly estimated payment percentage schedule. Defaults to federal (25/25/25/25).
    let estimatedPaymentSchedule: EstimatedPaymentSchedule
    /// State-specific safe harbor rule for the prior-year estimated tax method.
    let safeHarborRule: StateSafeHarborRule
    /// Current-year safe harbor percentage. Most states use 0.90 (like federal).
    /// GA/CO/OK use 0.70, MA/NJ/RI use 0.80, HI uses 0.60.
    let currentYearSafeHarborRate: Double
    /// CA and NJ tax HSA contributions as ordinary income at the state level
    /// (federal AGI reduction still applies, but state AGI does not).
    /// Defaults to false for the other 48 states + DC.
    let hsaContributionsTaxableForState: Bool
    /// Whether Traditional IRA contributions are taxable at the state level
    /// (i.e., the state does NOT allow the federal IRA deduction). Defaults
    /// to false (state-deductible, conforming) — no state currently flips this.
    /// Structure exists so future state-specific divergences can be added.
    let traditionalIRAContributionsTaxableForState: Bool
    /// Whether R3 "Other" above-the-line AGI reducers (educator expenses,
    /// student-loan interest, SE health-insurance premiums, alimony pre-2019,
    /// military moving, etc.) are taxable at the state level. Defaults to
    /// false (state-deductible, conforming). Non-conforming states can opt in.
    let otherPreTaxDeductionsTaxableForState: Bool
    /// Whether employee 401(k) elective deferrals are taxable at the state
    /// level at contribution time. Pennsylvania is the only state that does
    /// this (distributions later are state-tax-free — inverse of federal).
    /// Defaults to false; only PA opts in.
    ///
    /// EDGE CASES NOT COVERED BY THIS FLAG:
    /// - PA local EIT (Philadelphia wage tax, Act 32) also taxes 401(k);
    ///   we only model state, not local.
    /// - NJ does NOT conform for 403(b)/457/IRA contributions, but the app
    ///   only models 401(k) so no NJ flag needed today.
    /// - MA disallows solo-401(k) deduction for sole proprietors
    ///   (Schedule C); app is W-2-only so no MA flag needed.
    /// - Employer match is excluded from Box 1 federally AND from PA wages,
    ///   so no addback needed for match — only employee elective deferrals.
    let pretax401kContributionsTaxableForState: Bool
    /// Whether capital losses are class-isolated at the state level.
    ///
    /// PA classifies income into 8 statutory classes. Class 3 (Net Gains or
    /// Income From Disposition of Property) covers BOTH long-term and short-term
    /// capital gains. Within Class 3, losses can offset gains, but a net Class 3
    /// loss CANNOT offset Class 5 (dividends), Class 6 (interest), or any other
    /// class. When the net of LTCG + STCG is negative for the year, PA floors
    /// the Class 3 contribution at $0.
    ///
    /// Most states follow federal capital-loss rules (capital losses can offset
    /// up to $3K of ordinary income annually with carryforward). PA's class
    /// isolation is the exception. Source: PA DOR PIT Guide, Chapter on Net
    /// Gains or Income From the Disposition of Property; PA-40 Schedule D.
    ///
    /// Defaults to false (federal-style: capital losses can offset other income
    /// up to $3K/year via the federal computation that flows in here).
    let capitalLossesClassIsolated: Bool

    init(state: USState, taxSystem: StateTaxSystem, retirementExemptions: RetirementIncomeExemptions,
         stateDeduction: StateDeduction, estimatedPaymentSchedule: EstimatedPaymentSchedule = .federal,
         safeHarborRule: StateSafeHarborRule = .mirrorsFederal,
         currentYearSafeHarborRate: Double = 0.90,
         hsaContributionsTaxableForState: Bool = false,
         traditionalIRAContributionsTaxableForState: Bool = false,
         otherPreTaxDeductionsTaxableForState: Bool = false,
         pretax401kContributionsTaxableForState: Bool = false,
         capitalLossesClassIsolated: Bool = false) {
        self.state = state
        self.taxSystem = taxSystem
        self.retirementExemptions = retirementExemptions
        self.stateDeduction = stateDeduction
        self.estimatedPaymentSchedule = estimatedPaymentSchedule
        self.safeHarborRule = safeHarborRule
        self.currentYearSafeHarborRate = currentYearSafeHarborRate
        self.hsaContributionsTaxableForState = hsaContributionsTaxableForState
        self.traditionalIRAContributionsTaxableForState = traditionalIRAContributionsTaxableForState
        self.otherPreTaxDeductionsTaxableForState = otherPreTaxDeductionsTaxableForState
        self.pretax401kContributionsTaxableForState = pretax401kContributionsTaxableForState
        self.capitalLossesClassIsolated = capitalLossesClassIsolated
    }
}

// MARK: - 2026 State Tax Data

/// Static lookup of all 50 state + DC tax configurations for the 2026 tax year.
/// To update for a new tax year: change rates/thresholds here. No logic changes needed.
struct StateTaxData {

    /// Shorthand alias for bracket creation
    private typealias B = TaxBracket

    // MARK: No-Income-Tax States (9)

    static let configs2026: [USState: StateTaxConfig] = {
        var configs: [USState: StateTaxConfig] = [:]

        // ── No Income Tax States ──────────────────────────────────────────

        for state in [USState.alaska, .florida, .nevada, .southDakota, .tennessee, .texas, .wyoming] {
            configs[state] = StateTaxConfig(
                state: state,
                taxSystem: .noIncomeTax,
                retirementExemptions: RetirementIncomeExemptions(
                    socialSecurityExempt: true,
                    pensionExemption: .full,
                    iraWithdrawalExemption: .full,
                    capitalGainsTreatment: .noStateTax
                ),
                stateDeduction: .none
            )
        }

        // New Hampshire: No tax on wages/salary/pensions/IRA. Historically taxed dividends/interest
        // but that tax was fully repealed effective 2025. Effectively no income tax for retirees.
        configs[.newHampshire] = StateTaxConfig(
            state: .newHampshire,
            taxSystem: .specialLimited,
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .noStateTax
            ),
            stateDeduction: .none
        )

        // Washington: No general income tax. 7% capital gains tax on gains > $250K (long-term only).
        configs[.washington] = StateTaxConfig(
            state: .washington,
            taxSystem: .specialLimited,
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .noStateTax  // WA cap gains tax handled separately
            ),
            stateDeduction: .none
        )

        // ── Flat Tax States ───────────────────────────────────────────────

        // Arizona — 2.5% flat rate (2026)
        configs[.arizona] = StateTaxConfig(
            state: .arizona,
            taxSystem: .flat(rate: 0.025),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 2_500),
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal,
            safeHarborRule: .flatRate(1.00)
        )

        // Colorado — 4.40% flat rate (2026)
        configs[.colorado] = StateTaxConfig(
            state: .colorado,
            taxSystem: .flat(rate: 0.044),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // CO exempts SS for age 65+ (and 55-64 with AGI limits per SB24-228)
                // C.R.S. § 39-22-104(4)(f) — Colorado Pension and Annuity
                // Subtraction. Per CO DOR guidance, pensions AND IRA
                // distributions count together against ONE annual cap:
                //   Age 55-64: $20,000 combined (encoded in earlyAgeTier)
                //   Age 65+:   $24,000 combined
                // SB25-136 (which would have removed the cap entirely starting
                // TY2026) was Postponed Indefinitely 02/27/2025 — DID NOT pass.
                // So TY2026 stays at the $20K / $24K caps.
                pensionExemption: .partial(maxExempt: 24_000),
                iraWithdrawalExemption: .partial(maxExempt: 24_000),
                regularExemptionMinAge: 65,
                earlyAgeTier: RetirementIncomeExemptions.AgeTier(
                    ageRange: 55...64,
                    level: .partial(maxExempt: 20_000)
                ),
                pensionAndIRAShareSingleCap: true,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal,
            currentYearSafeHarborRate: 0.70
        )

        // Georgia — 5.39% flat rate (2026, phasing down)
        configs[.georgia] = StateTaxConfig(
            state: .georgia,
            taxSystem: .flat(rate: 0.0539),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                // O.C.G.A. § 48-7-27(a)(5): Georgia Retirement Income Exclusion.
                //   Ages 62-64: up to $35,000 (encoded in earlyAgeTier below)
                //   Ages 65+:   up to $65,000 (this field)
                // Effective for tax years beginning on or after Jan 1, 2012.
                // The exclusion is per qualifying individual on the return —
                // each spouse who separately meets the age and qualifying-
                // income tests gets a separate exclusion amount.
                //
                // GA's exclusion is a SINGLE retirement-income cap covering
                // ALL qualifying retirement income (pensions, IRAs, annuities,
                // interest, dividends, capital gains, etc. — though our engine
                // only handles pension and IRA here). It is NOT a separate cap
                // per income type. Set `pensionAndIRAShareSingleCap: true`.
                pensionExemption: .partial(maxExempt: 65_000),
                iraWithdrawalExemption: .partial(maxExempt: 65_000),
                exemptionAppliesPerIndividual: true,
                regularExemptionMinAge: 65,
                earlyAgeTier: RetirementIncomeExemptions.AgeTier(
                    ageRange: 62...64,
                    level: .partial(maxExempt: 35_000)
                ),
                pensionAndIRAShareSingleCap: true,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 12_000, married: 24_000),
            safeHarborRule: .flatRate(1.00),
            currentYearSafeHarborRate: 0.70
        )

        // Idaho — 5.3% flat rate (TY 2026 per HB 40, retroactive to TY 2025)
        // Primary source: ID State Tax Commission rate schedule page
        //   https://tax.idaho.gov/taxes/income-tax/individual-income/individual-income-tax-rate-schedule/
        // Enacted legislation: HB 40 (signed March 6, 2025 by Gov. Little) — made the 5.3% rate
        // permanent (not a one-year cut). HB 559 (2026) conforms ID to federal OBBBA standard
        // deduction for TY 2025+.
        // Note: ID has a small zero-bracket (~$4,811 single / $9,622 MFJ TY 2025; TY 2026 indexed
        // value pending DOR rate schedule update). For planning-tool accuracy, the federal-style
        // standard deduction (much larger than $4,811) shields most retirees from the zero-bracket
        // concern, so modeling as flat 5.3% with .conformsToFederal std deduction is acceptable.
        // TriSTAR coverage: source #1 (ID Tax Commission primary), #4 (multi-LLM), #2 (TAXSIM via test suite).
        // Verified 2026-05-27.
        configs[.idaho] = StateTaxConfig(
            state: .idaho,
            taxSystem: .flat(rate: 0.053),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal,
            safeHarborRule: .noPenalty
        )

        // Illinois — 4.95% flat rate
        configs[.illinois] = StateTaxConfig(
            state: .illinois,
            taxSystem: .flat(rate: 0.0495),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,  // IL exempts all retirement income
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none
        )

        // Indiana — 2.95% flat rate (2026, reduced from 3.05%)
        configs[.indiana] = StateTaxConfig(
            state: .indiana,
            taxSystem: .flat(rate: 0.0295),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none
        )

        // Iowa — 3.8% flat rate (2026)
        configs[.iowa] = StateTaxConfig(
            state: .iowa,
            taxSystem: .flat(rate: 0.038),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,  // IA phased out retirement exclusion with flat tax
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal
        )

        // Kentucky — 3.5% flat rate (2026, reduced from 4%)
        configs[.kentucky] = StateTaxConfig(
            state: .kentucky,
            taxSystem: .flat(rate: 0.035),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 31_110),  // KY retirement exclusion
                iraWithdrawalExemption: .partial(maxExempt: 31_110),  // combined
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 3_360, married: 3_360),
            safeHarborRule: .agiThreshold(threshold: 250_000, lowRate: 1.00, highRate: 1.10)
        )

        // Massachusetts — 5.0% flat rate
        configs[.massachusetts] = StateTaxConfig(
            state: .massachusetts,
            taxSystem: .flat(rate: 0.05),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,  // MA taxes pension income
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal  // MA has 9% surtax on short-term gains, simplified here
            ),
            stateDeduction: .none,
            safeHarborRule: .flatRate(1.00),
            currentYearSafeHarborRate: 0.80
        )

        // Michigan — 4.25% flat rate (TY 2026 per MI Treasury official 2026 rate notice)
        // Primary source: MI Department of Treasury notice (Apr 15, 2026)
        //   https://www.michigan.gov/treasury/news/2026/04/15/state-individual-income-tax-rate-for-2026-tax-year-determined
        // Also: Form 446 2026 Withholding Guide (Rev. 02-26) and RAB 2026-1.
        // History: 4.05% was a one-year TY 2023 trigger reduction under MCL 206.51 that did NOT
        // recur for TY 2024+. The rate has been 4.25% for TY 2024, 2025, and 2026.
        // Note: Retirement income exemption is in TY 2026 final phase-in of Lowering MI Costs Plan
        // (PA 4 of 2023) — 100% qualifying retirement income exempt. Already modeled as .full.
        // TriSTAR coverage: source #1 (Treasury primary), #4 (multi-LLM), #2 (TAXSIM via test suite).
        // Verified 2026-05-27.
        configs[.michigan] = StateTaxConfig(
            state: .michigan,
            taxSystem: .flat(rate: 0.0425),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,  // MI phasing to full retirement income exemption by 2026
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none
        )

        // Mississippi — 4.0% flat rate (TY 2026 statutory; on taxable income > $10,000)
        //
        // Primary source: enacted bill text on MS Legislature .ms.gov domain
        //   HB 531/2022 (Build Up Mississippi Act, original phase-down):
        //     https://billstatus.ls.state.ms.us/documents/2022/html/HB/0500-0599/HB0531SG.htm
        //     Schedule: TY 2024 = 4.7%, TY 2025 = 4.4%, TY 2026 = 4.0%
        //   HB 1/2025 (Build Up Mississippi Act II, signed Gov. Reeves 2025-03-27):
        //     https://billstatus.ls.state.ms.us/documents/2025/html/HB/0001-0099/HB0001SG.htm
        //     Confirmed TY 2026 = 4.0% unchanged; added TY 2027+ cuts (3.75%, 3.5%, 3.25%, 3.0%)
        //     toward full elimination of the individual income tax. The 0.25% TY 2027 step-down
        //     from 4.0% mathematically confirms 4.0% as the TY 2026 base.
        //
        // Note: MS DOR FAQ page (https://www.dor.ms.gov/individual/individual-income-tax-frequently-asked-questions)
        // may prominently display TY 2025 rate (4.4%) as "current" during early-2026 filing season.
        // This is a stale-DOR-page artifact common to state tax authorities; the authoritative
        // rate for TY 2026 per enacted statute is 4.0%. (Multi-LLM TriSTAR review surfaced this
        // ambiguity 2026-05-27; resolved by direct legislative-record verification.)
        //
        // MS exempts first $10,000 of taxable income (effectively a zero-bracket); the engine
        // captures this via the personal exemption + standard deduction stack rather than as
        // a separate bracket boundary. Std deduction $2,300/$4,600 already correct.
        //
        // TriSTAR coverage: source #1 (.ms.gov legislative record, dual-bill verification),
        // source #4 (multi-LLM with disambiguation), source #2 (TAXSIM via test suite),
        // source #3 (MetamorphicPropertyTests P14 unaffected — MS retirement exemption is full).
        // Verified 2026-05-27.
        configs[.mississippi] = StateTaxConfig(
            state: .mississippi,
            taxSystem: .flat(rate: 0.04),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,  // MS exempts all retirement income
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 2_300, married: 4_600)
        )

        // North Carolina — 3.99% flat rate (2026, reduced)
        configs[.northCarolina] = StateTaxConfig(
            state: .northCarolina,
            taxSystem: .flat(rate: 0.0399),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 12_750, married: 25_500),
            safeHarborRule: .flatRate(1.00)
        )

        // North Dakota — 1.95% flat rate (2026, simplified to flat)
        configs[.northDakota] = StateTaxConfig(
            state: .northDakota,
            taxSystem: .flat(rate: 0.0195),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal
        )

        // Ohio — 2.75% flat rate (2026, simplified from progressive)
        configs[.ohio] = StateTaxConfig(
            state: .ohio,
            taxSystem: .flat(rate: 0.0275),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none,
            safeHarborRule: .flatRate(1.00)
        )

        // Pennsylvania — 3.07% flat rate
        // PA taxes employee 401(k) elective deferrals at contribution time
        // (distributions later are tax-free at state level — opposite of federal).
        // Source: PA DOR Gross Compensation guide. NJ/MA/AL/HI/MS all conform.
        configs[.pennsylvania] = StateTaxConfig(
            state: .pennsylvania,
            taxSystem: .flat(rate: 0.0307),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,  // PA exempts all retirement income
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none,
            safeHarborRule: .flatRate(1.00),
            pretax401kContributionsTaxableForState: true,
            capitalLossesClassIsolated: true  // PA Class 3 isolation — see capitalLossesClassIsolated docs
        )

        // Utah — 4.55% flat rate (2026)
        configs[.utah] = StateTaxConfig(
            state: .utah,
            taxSystem: .flat(rate: 0.0455),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // UT taxes SS (with tax credit for lower incomes)
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none
        )

        // ── Progressive Bracket States ────────────────────────────────────

        // Alabama — 2%, 4%, 5% (unchanged for 2026)
        configs[.alabama] = StateTaxConfig(
            state: .alabama,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 500, rate: 0.04),
                    B(threshold: 3_000, rate: 0.05)
                ],
                married: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 1_000, rate: 0.04),
                    B(threshold: 6_000, rate: 0.05)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 3_000, married: 8_500)
        )

        // Arkansas — 0%, 2%, 3%, 3.4%, 3.7% graduated (TY 2026 per HB 1001 / Act 1 of 2026 1st Ex. Sess.)
        //
        // Primary source: AR DFA Fiscal Impact Statement on HB 1001 (5/1/2026)
        //   https://www.arkleg.state.ar.us/Home/FTPDocument?path=%2FAssembly%2F2025%2F2026S1%2FFiscal+Impacts%2FHB1001-DFA1.pdf
        // Also: AR DFA 2026 Low-Income Withholding Tables
        //   https://www.dfa.arkansas.gov/wp-content/uploads/withholdTaxTablesLowIncome_2026_1.pdf
        // Enacted legislation: HB 1001 of the 2026 First Extraordinary Session,
        //   Act 1 of 2026 (1st Ex. Sess.), signed by Gov. Sanders 2026-05-06.
        //   Amends Ark. Code Ann. § 26-51-201 reducing top rate 3.9% → 3.7% TY 2026.
        //   Standard Income Table threshold ceiling moved $92,300 → $94,700 (indexed).
        //
        // Engine models the Standard Income Table (taxable income ≤ $94,700) which covers
        // the entire retiree-planning demographic. AR also has an "Upper Income Table" for
        // income > $94,700 (2% on first $4,700; 3.7% above) with a $94,701-$97,600 bracket
        // smoothing band — not modeled here; high-income AR filers will see slight tax
        // overstatement (acceptable planning-tool approximation).
        //
        // AR uses one schedule for single + MFJ (no doubling). Std deduction $2,470/$4,940
        // (TY 2025 indexed value; TY 2026 indexed value pending AR1000F instructions —
        // using TY 2025 as conservative floor; AR DFA indexes annually).
        //
        // TriSTAR coverage: source #1 (.gov AR DFA + AR Legislature dual verification),
        // source #4 (multi-LLM pending re-review after 3.7% disambiguation),
        // sources #2/#3 (TAXSIM + metamorphic via test suite).
        // Verified 2026-05-27 (initial 3.9% expectation disambiguated to 3.7% per HB 1001).
        configs[.arkansas] = StateTaxConfig(
            state: .arkansas,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 5_600, rate: 0.02),
                    B(threshold: 11_200, rate: 0.03),
                    B(threshold: 16_000, rate: 0.034),
                    B(threshold: 26_400, rate: 0.037)
                ],
                married: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 5_600, rate: 0.02),
                    B(threshold: 11_200, rate: 0.03),
                    B(threshold: 16_000, rate: 0.034),
                    B(threshold: 26_400, rate: 0.037)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 6_000),  // $6K per taxpayer at 59½+
                iraWithdrawalExemption: .partial(maxExempt: 6_000),
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 2_470, married: 4_940),  // TY 2025; TY 2026 indexed value pending AR1000F instructions
            safeHarborRule: .flatRate(1.00)
        )

        // California — 1% to 13.3% (10 brackets; TY 2025 per CA FTB Schedule X / Y)
        // Source: 2025 Form 540 Tax Rate Schedules (CA FTB)
        // https://www.ftb.ca.gov/forms/2025/2025-540-tax-rate-schedules.pdf
        // Verified 2026-05-26 against the official FTB 2025 Form 540 instructions.
        // Previously held TY 2023 values (surfaced by tester screenshot showing $21K/$49K/$78K
        // MFJ thresholds — those were TY 2023 single×2 doubled values). Updated to TY 2025
        // actuals. TY 2026 thresholds will be published by CA FTB late 2026.
        // Note: HoH has separate Schedule Z (not modeled — engine API only supports single/married).
        configs[.california] = StateTaxConfig(
            state: .california,
            taxSystem: .progressive(
                single: [   // Schedule X — Single / Married Filing Separately
                    B(threshold: 0, rate: 0.01),
                    B(threshold: 11_079, rate: 0.02),
                    B(threshold: 26_264, rate: 0.04),
                    B(threshold: 41_452, rate: 0.06),
                    B(threshold: 57_542, rate: 0.08),
                    B(threshold: 72_724, rate: 0.093),
                    B(threshold: 371_479, rate: 0.103),
                    B(threshold: 445_771, rate: 0.113),
                    B(threshold: 742_953, rate: 0.123),
                    B(threshold: 1_000_000, rate: 0.133)  // 12.3% + 1% MHST (statutory $1M floor, not indexed)
                ],
                married: [  // Schedule Y — Married Filing Jointly / Qualifying Surviving Spouse
                    B(threshold: 0, rate: 0.01),
                    B(threshold: 22_158, rate: 0.02),
                    B(threshold: 52_528, rate: 0.04),
                    B(threshold: 82_904, rate: 0.06),
                    B(threshold: 115_084, rate: 0.08),
                    B(threshold: 145_448, rate: 0.093),
                    B(threshold: 742_958, rate: 0.103),
                    B(threshold: 891_542, rate: 0.113),
                    B(threshold: 1_000_000, rate: 0.123),  // 11.3% + 1% MHST kicks in at $1M before 12.3% bracket
                    B(threshold: 1_485_906, rate: 0.133)   // 12.3% + 1% MHST
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // CA does not tax SS
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .taxedAsOrdinary  // CA taxes cap gains as ordinary income
            ),
            stateDeduction: .fixed(single: 5_706, married: 11_412),
            estimatedPaymentSchedule: .california,
            safeHarborRule: .mirrorsFederalWithDisqualification(disqualifyAGI: 1_000_000),
            hsaContributionsTaxableForState: true
        )

        // Connecticut — 2% to 6.99% (7 brackets, TY 2026)
        //
        // Primary source: CT DRS — Informational Publication 2026(1), 2026 Circular CT
        //   Employer's Tax Guide (with TY 2026 bracket schedule)
        //   https://portal.ct.gov/-/media/drs/publications/pubsip/2026/ip-2026-1.pdf
        // Also: CGA Office of Legislative Research 2025-R-0080 (historical schedule)
        //   https://cga.ct.gov/2025/rpt/pdf/2025-R-0080.pdf
        // Enacted legislation: Public Act 23-204 §§ 374-376 cut the bottom two rates
        //   from 3%/5% to 2%/4.5% effective TY 2024+ (continues for TY 2026 unchanged).
        //
        // CT has no statutory inflation indexing; bracket thresholds remain stable across
        // years. The 3%/5% rates in pre-fix code were CT's pre-TY-2024 rates that were
        // permanently reduced by PA 23-204.
        //
        // IRA exclusion: TY 2026 = 100% (final phase-in of 50%/75%/100% across TY24/25/26).
        // SS exempt under $75K single / $100K MFJ federal AGI (75% above); pension/annuity
        // 100% deduction under $75K/$100K AGI, phasing to 0% at $100K/$150K — phaseouts NOT
        // modeled here (engine lacks AGI-based exemption support; pensionExemption stays
        // .none conservatively). Personal exemption (credit-style, AGI-phased) not modeled.
        //
        // TriSTAR coverage: source #1 (CT DRS IP-2026-1 primary), source #4 (multi-LLM
        // pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.connecticut] = StateTaxConfig(
            state: .connecticut,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 10_000, rate: 0.045),
                    B(threshold: 50_000, rate: 0.055),
                    B(threshold: 100_000, rate: 0.06),
                    B(threshold: 200_000, rate: 0.065),
                    B(threshold: 250_000, rate: 0.069),
                    B(threshold: 500_000, rate: 0.0699)
                ],
                married: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 20_000, rate: 0.045),
                    B(threshold: 100_000, rate: 0.055),
                    B(threshold: 200_000, rate: 0.06),
                    B(threshold: 400_000, rate: 0.065),
                    B(threshold: 500_000, rate: 0.069),
                    B(threshold: 1_000_000, rate: 0.0699)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // CT taxes SS above AGI thresholds
                pensionExemption: .none,
                iraWithdrawalExemption: .full,  // CT exempts IRA withdrawals starting 2026
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none,
            safeHarborRule: .flatRate(1.00)
        )

        // Delaware — 2.2% to 6.6% (6 brackets)
        configs[.delaware] = StateTaxConfig(
            state: .delaware,
            taxSystem: .progressive(
                single: [
                    B(threshold: 2_000, rate: 0.022),
                    B(threshold: 5_000, rate: 0.039),
                    B(threshold: 10_000, rate: 0.048),
                    B(threshold: 20_000, rate: 0.052),
                    B(threshold: 25_000, rate: 0.0555),
                    B(threshold: 60_000, rate: 0.066)
                ],
                married: [
                    B(threshold: 2_000, rate: 0.022),
                    B(threshold: 5_000, rate: 0.039),
                    B(threshold: 10_000, rate: 0.048),
                    B(threshold: 20_000, rate: 0.052),
                    B(threshold: 25_000, rate: 0.0555),
                    B(threshold: 60_000, rate: 0.066)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 12_500),  // age 60+ exclusion
                iraWithdrawalExemption: .partial(maxExempt: 12_500),
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 3_250, married: 6_500)
        )

        // District of Columbia — 4% to 10.75% (7 brackets)
        configs[.districtOfColumbia] = StateTaxConfig(
            state: .districtOfColumbia,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.04),
                    B(threshold: 10_000, rate: 0.06),
                    B(threshold: 40_000, rate: 0.065),
                    B(threshold: 60_000, rate: 0.085),
                    B(threshold: 250_000, rate: 0.0925),
                    B(threshold: 500_000, rate: 0.0975),
                    B(threshold: 1_000_000, rate: 0.1075)
                ],
                married: [
                    B(threshold: 0, rate: 0.04),
                    B(threshold: 10_000, rate: 0.06),
                    B(threshold: 40_000, rate: 0.065),
                    B(threshold: 60_000, rate: 0.085),
                    B(threshold: 250_000, rate: 0.0925),
                    B(threshold: 500_000, rate: 0.0975),
                    B(threshold: 1_000_000, rate: 0.1075)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 14_600, married: 25_900)
        )

        // Hawaii — 1.4% to 11% (12 brackets, TY 2026 per Act 46 SLH 2024)
        //
        // Primary source: HI DOTAX tax tables (effective after 2024-12-31)
        //   https://tax.hawaii.gov/forms/d_25table-on/
        // Also: HI DOTAX 2026 Payroll Updates
        //   https://tax.hawaii.gov/payrollupdate/
        // Enacted legislation: Act 46, SLH 2024 (HB 2404)
        //   https://data.capitol.hawaii.gov/sessions/sessionlaws/Years/SLH2024/SLH2024_Act46.pdf
        //
        // Act 46 (2024) phases in bracket widening + std deduction increases through 2031.
        // Bracket schedule changes only in TY 2025, 2027, and 2029; TY 2026 brackets =
        // TY 2025 brackets. Standard deduction DOES increase TY 2025 → TY 2026 (from
        // $4,400/$8,800 to $8,000/$16,000) — already correctly set below.
        //
        // The pre-fix brackets ($2,400 / $4,800 / $9,600... for single) were the pre-Act-46
        // schedule from before TY 2025. Replaced with TY 2025/2026 widened brackets per
        // DOTAX official tax tables.
        //
        // MFJ thresholds doubled (per Act 46): $19,200 / $28,800 / ... / $650,000.
        // Retirement income: HI continues to fully exclude employer pensions (already .none
        // in code — engine convention is .none means "no special exemption beyond what's
        // in the bracket structure"; the HRS § 235-7(a)(2)/(3) full exemption for pensions
        // is a known engine limitation not affecting tax computation when pension income
        // is not separately broken out in incomeSources).
        //
        // TriSTAR coverage: source #1 (HI DOTAX primary + Act 46 enacted text),
        // source #4 (multi-LLM pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.hawaii] = StateTaxConfig(
            state: .hawaii,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.014),
                    B(threshold: 9_600, rate: 0.032),
                    B(threshold: 14_400, rate: 0.055),
                    B(threshold: 19_200, rate: 0.064),
                    B(threshold: 24_000, rate: 0.068),
                    B(threshold: 36_000, rate: 0.072),
                    B(threshold: 48_000, rate: 0.076),
                    B(threshold: 125_000, rate: 0.079),
                    B(threshold: 175_000, rate: 0.0825),
                    B(threshold: 225_000, rate: 0.09),
                    B(threshold: 275_000, rate: 0.10),
                    B(threshold: 325_000, rate: 0.11)
                ],
                married: [
                    B(threshold: 0, rate: 0.014),
                    B(threshold: 19_200, rate: 0.032),
                    B(threshold: 28_800, rate: 0.055),
                    B(threshold: 38_400, rate: 0.064),
                    B(threshold: 48_000, rate: 0.068),
                    B(threshold: 72_000, rate: 0.072),
                    B(threshold: 96_000, rate: 0.076),
                    B(threshold: 250_000, rate: 0.079),
                    B(threshold: 350_000, rate: 0.0825),
                    B(threshold: 450_000, rate: 0.09),
                    B(threshold: 550_000, rate: 0.10),
                    B(threshold: 650_000, rate: 0.11)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 8_000, married: 16_000),
            safeHarborRule: .flatRate(1.00),
            currentYearSafeHarborRate: 0.60
        )

        // Kansas — 3.1%, 5.25%, 5.7% (3 brackets)
        configs[.kansas] = StateTaxConfig(
            state: .kansas,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.031),
                    B(threshold: 15_000, rate: 0.0525),
                    B(threshold: 30_000, rate: 0.057)
                ],
                married: [
                    B(threshold: 0, rate: 0.031),
                    B(threshold: 30_000, rate: 0.0525),
                    B(threshold: 60_000, rate: 0.057)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // KS exempts SS for AGI under $75K
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 3_605, married: 8_240),
            safeHarborRule: .flatRate(1.00)
        )

        // Louisiana — 1.85%, 3.5%, 4.25% (3 brackets, 2026)
        configs[.louisiana] = StateTaxConfig(
            state: .louisiana,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0185),
                    B(threshold: 12_500, rate: 0.035),
                    B(threshold: 50_000, rate: 0.0425)
                ],
                married: [
                    B(threshold: 0, rate: 0.0185),
                    B(threshold: 25_000, rate: 0.035),
                    B(threshold: 100_000, rate: 0.0425)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 6_000),
                iraWithdrawalExemption: .partial(maxExempt: 6_000),
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 12_500, married: 25_000),
            safeHarborRule: .flatRate(1.00)
        )

        // Maine — 5.8%, 6.75%, 7.15% (3 brackets)
        configs[.maine] = StateTaxConfig(
            state: .maine,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.058),
                    B(threshold: 26_050, rate: 0.0675),
                    B(threshold: 61_600, rate: 0.0715)
                ],
                married: [
                    B(threshold: 0, rate: 0.058),
                    B(threshold: 52_100, rate: 0.0675),
                    B(threshold: 123_250, rate: 0.0715)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 25_000),  // ME pension deduction
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 15_300, married: 30_600),
            safeHarborRule: .flatRate(1.00)
        )

        // Maryland — 2% to 6.50% (10 brackets, TY 2026 per HB 352 / 2025 Md. Laws Ch. 604)
        //
        // Primary source: MD Comptroller — 2025 Session Tax Alert (revised 2025-12-22)
        //   https://www.marylandcomptroller.gov/content/dam/mdcomp/tax/legal-publications/alerts/tax-alert-changes-to-standard-and-itemized-deductions-and-to-state-and-local-income-tax-rates-from-the-2025-legislative-session.pdf
        // Also: MD Pension Exclusion Guidance
        //   https://www.marylandtaxes.gov/individual/income/filing/pension-exclusion.php
        // Enacted legislation: HB 352 (2025 Regular Session) = Budget Reconciliation and
        //   Financing Act of 2025 = 2025 Md. Laws Ch. 604
        //   Fiscal note: https://mgaleg.maryland.gov/2025RS/fnotes/bil_0002/hb0352.pdf
        //
        // HB 352 added TWO new top brackets effective TY 2025+:
        //   Single: 6.25% on $500K-$1M, 6.50% over $1M
        //   MFJ:    6.25% on $600K-$1.2M, 6.50% over $1.2M
        // The 5.75% bracket is now capped instead of open-ended.
        //
        // Standard deduction rule also changed via HB 352: previously a 15%-of-AGI formula
        // with min/max caps; now a FLAT $3,350/$6,700 (no AGI formula). Indexed thereafter
        // under Md. Tax-General § 10-217.
        //
        // Pension exclusion: $39,500 (TY 2024) → $41,200 (TY 2025) → likely ~$42,500 (TY 2026
        // indexed; awaiting publication of Withholding Tax Facts 2026 to confirm exact value;
        // using $41,200 as TY 2025-verified floor — conservative under-exemption acceptable).
        //
        // County local income tax (2.25%-3.30% per county) NOT modeled. 2% surtax on net
        // capital gains for FAGI > $350K also NOT modeled (rare for typical retiree).
        //
        // TriSTAR coverage: source #1 (MD Comptroller primary + HB 352 fiscal note),
        // source #4 (multi-LLM pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.maryland] = StateTaxConfig(
            state: .maryland,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 1_000, rate: 0.03),
                    B(threshold: 2_000, rate: 0.04),
                    B(threshold: 3_000, rate: 0.0475),
                    B(threshold: 100_000, rate: 0.05),
                    B(threshold: 125_000, rate: 0.0525),
                    B(threshold: 150_000, rate: 0.055),
                    B(threshold: 250_000, rate: 0.0575),
                    B(threshold: 500_000, rate: 0.0625),
                    B(threshold: 1_000_000, rate: 0.065)
                ],
                married: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 1_000, rate: 0.03),
                    B(threshold: 2_000, rate: 0.04),
                    B(threshold: 3_000, rate: 0.0475),
                    B(threshold: 150_000, rate: 0.05),
                    B(threshold: 175_000, rate: 0.0525),
                    B(threshold: 225_000, rate: 0.055),
                    B(threshold: 300_000, rate: 0.0575),
                    B(threshold: 600_000, rate: 0.0625),
                    B(threshold: 1_200_000, rate: 0.065)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                // MD pension exclusion: up to $39,500 (TY2024 per Comptroller's
                // Technical Bulletin No. 51, effective April 10, 2025; Md
                // Tax-General § 10-209). Applies to taxpayers age 65+ or
                // totally disabled. Qualifying income: employer pensions /
                // 401(a) / 403 / 457(b) annuities only.
                // MD pension exclusion: TY 2025 = $41,200 indexed. TY 2026 value
                // likely ~$42,500 (awaiting publication of MD Withholding Tax Facts 2026);
                // using TY 2025-verified $41,200 as conservative floor.
                pensionExemption: .partial(maxExempt: 41_200),
                // IRA distributions DO NOT qualify for the MD pension exclusion
                // (per TB-51 §II.F): "A traditional IRA, a Roth IRA, a rollover
                // IRA, a simplified employee plan (SEP), a Keogh plan, an
                // ineligible deferred compensation plan, or foreign retirement
                // income does not qualify."
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            // TY 2025+ flat std deduction per HB 352 (2025 Md. Laws Ch. 604) — replaces
            // prior 15%-of-AGI formula with $1,800-$2,700/$3,600-$5,450 caps. Now flat
            // $3,350/$6,700 (indexed thereafter under Md Tax-General § 10-217).
            stateDeduction: .fixed(single: 3_350, married: 6_700),
            safeHarborRule: .flatRate(1.10)
        )

        // Minnesota — 5.35% to 9.85% (4 brackets)
        configs[.minnesota] = StateTaxConfig(
            state: .minnesota,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0535),
                    B(threshold: 31_690, rate: 0.068),
                    B(threshold: 104_090, rate: 0.0785),
                    B(threshold: 193_240, rate: 0.0985)
                ],
                married: [
                    B(threshold: 0, rate: 0.0535),
                    B(threshold: 46_330, rate: 0.068),
                    B(threshold: 184_040, rate: 0.0785),
                    B(threshold: 321_450, rate: 0.0985)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // MN taxes SS (with subtraction for lower incomes)
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 15_300, married: 30_600)
        )

        // Missouri — 2% to 4.7% (graduated, 2026)
        configs[.missouri] = StateTaxConfig(
            state: .missouri,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 1_207, rate: 0.025),
                    B(threshold: 2_414, rate: 0.03),
                    B(threshold: 3_621, rate: 0.035),
                    B(threshold: 4_828, rate: 0.04),
                    B(threshold: 6_035, rate: 0.045),
                    B(threshold: 7_242, rate: 0.047)
                ],
                married: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 1_207, rate: 0.025),
                    B(threshold: 2_414, rate: 0.03),
                    B(threshold: 3_621, rate: 0.035),
                    B(threshold: 4_828, rate: 0.04),
                    B(threshold: 6_035, rate: 0.045),
                    B(threshold: 7_242, rate: 0.047)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // MO fully exempts SS (2026)
                pensionExemption: .partial(maxExempt: 6_000),  // public pension deduction
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal
        )

        // Montana — 4.7% flat rate (2026, reduced and simplified)
        configs[.montana] = StateTaxConfig(
            state: .montana,
            taxSystem: .flat(rate: 0.047),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // MT taxes SS (with partial deduction)
                pensionExemption: .partial(maxExempt: 4_640),
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal,
            safeHarborRule: .flatRate(1.00)
        )

        // Nebraska — 3.99% to 5.2% (2026, 4 brackets, reduced rates)
        configs[.nebraska] = StateTaxConfig(
            state: .nebraska,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0399),
                    B(threshold: 3_700, rate: 0.0499),
                    B(threshold: 22_170, rate: 0.0509),
                    B(threshold: 35_730, rate: 0.052)
                ],
                married: [
                    B(threshold: 0, rate: 0.0399),
                    B(threshold: 7_390, rate: 0.0499),
                    B(threshold: 44_350, rate: 0.0509),
                    B(threshold: 71_460, rate: 0.052)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // NE fully exempts SS (2025+)
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 12_000, married: 24_000)
        )

        // New Jersey — 1.4% to 10.75% (7 brackets)
        configs[.newJersey] = StateTaxConfig(
            state: .newJersey,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.014),
                    B(threshold: 20_000, rate: 0.0175),
                    B(threshold: 35_000, rate: 0.035),
                    B(threshold: 40_000, rate: 0.05525),
                    B(threshold: 75_000, rate: 0.0637),
                    B(threshold: 500_000, rate: 0.0897),
                    B(threshold: 1_000_000, rate: 0.1075)
                ],
                married: [
                    B(threshold: 0, rate: 0.014),
                    B(threshold: 20_000, rate: 0.0175),
                    B(threshold: 50_000, rate: 0.0245),
                    B(threshold: 70_000, rate: 0.035),
                    B(threshold: 80_000, rate: 0.05525),
                    B(threshold: 150_000, rate: 0.0637),
                    B(threshold: 500_000, rate: 0.0897),
                    B(threshold: 1_000_000, rate: 0.1075)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                // NJSA 54A:6-15: NJ Pension and Other Retirement Income
                // Exclusion. Available to taxpayers age 62+ or totally
                // disabled. For tax years beginning on or after Jan 1, 2020:
                //   MFJ:    up to $100,000
                //   Single: up to  $75,000
                //   MFS:    up to  $50,000
                // AGI phaseout (TY2021+): full exclusion below $100K AGI;
                // reduced 50%/37.5%/25% in $100K–$125K tier; reduced
                // 25%/18.75%/12.5% in $125K–$150K tier; zero above $150K.
                //
                // Current encoding uses the MFJ cap. Two known
                // approximations remain (filed as TODOs for follow-up):
                //   - Single filers currently get the MFJ $100K cap rather
                //     than the correct $75K. Affects only single retirees
                //     with $75K-$100K of pension/IRA income.
                //   - AGI-based phaseout is not modeled. Affects retirees
                //     with total income $100K-$150K. Engine over-exempts
                //     in that window.
                pensionExemption: .partial(maxExempt: 100_000),
                iraWithdrawalExemption: .partial(maxExempt: 100_000),
                regularExemptionMinAge: 62,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none,
            safeHarborRule: .mirrorsFederal,
            currentYearSafeHarborRate: 0.80,
            hsaContributionsTaxableForState: true
        )

        // New Mexico — 1.7% to 5.9% (4 brackets)
        configs[.newMexico] = StateTaxConfig(
            state: .newMexico,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.017),
                    B(threshold: 5_500, rate: 0.032),
                    B(threshold: 11_000, rate: 0.047),
                    B(threshold: 16_000, rate: 0.049),
                    B(threshold: 210_000, rate: 0.059)
                ],
                married: [
                    B(threshold: 0, rate: 0.017),
                    B(threshold: 8_000, rate: 0.032),
                    B(threshold: 16_000, rate: 0.047),
                    B(threshold: 24_000, rate: 0.049),
                    B(threshold: 315_000, rate: 0.059)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // NM taxes SS above thresholds
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal,
            safeHarborRule: .flatRate(1.00)
        )

        // New York — 4% to 10.9% (9 brackets)
        configs[.newYork] = StateTaxConfig(
            state: .newYork,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.04),
                    B(threshold: 8_500, rate: 0.045),
                    B(threshold: 11_700, rate: 0.0525),
                    B(threshold: 13_900, rate: 0.0585),
                    B(threshold: 80_650, rate: 0.0625),
                    B(threshold: 215_400, rate: 0.0685),
                    B(threshold: 1_077_550, rate: 0.0965),
                    B(threshold: 5_000_000, rate: 0.103),
                    B(threshold: 25_000_000, rate: 0.109)
                ],
                married: [
                    B(threshold: 0, rate: 0.04),
                    B(threshold: 17_150, rate: 0.045),
                    B(threshold: 23_600, rate: 0.0525),
                    B(threshold: 27_900, rate: 0.0585),
                    B(threshold: 161_550, rate: 0.0625),
                    B(threshold: 323_200, rate: 0.0685),
                    B(threshold: 2_155_350, rate: 0.0965),
                    B(threshold: 5_000_000, rate: 0.103),
                    B(threshold: 25_000_000, rate: 0.109)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                // NY Tax Law § 612(c)(3-a): "Pensions and annuities received by
                // an individual who has attained the age of fifty-nine and
                // one-half" — up to $20,000 per qualifying individual.
                // Per IT-201 instructions, each spouse on a joint return who
                // separately meets the age and qualifying-income tests gets
                // their own $20,000 exclusion.
                pensionExemption: .partial(maxExempt: 20_000),
                iraWithdrawalExemption: .partial(maxExempt: 20_000),
                // Per-individual: MFJ where both spouses are 59½+ gets 2 × $20K.
                exemptionAppliesPerIndividual: true,
                // Age 59½ statutory minimum. Engine uses integer ages; we use
                // 59 as a slightly generous approximation matching the rest of
                // the engine's `>= 59` convention for retirement-age gates.
                regularExemptionMinAge: 59,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 8_000, married: 16_050)
        )

        // Oklahoma — 0.25% to 4.75% (6 brackets, 2026)
        configs[.oklahoma] = StateTaxConfig(
            state: .oklahoma,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0025),
                    B(threshold: 1_000, rate: 0.0075),
                    B(threshold: 2_500, rate: 0.0175),
                    B(threshold: 3_750, rate: 0.0275),
                    B(threshold: 4_900, rate: 0.0375),
                    B(threshold: 7_200, rate: 0.0475)
                ],
                married: [
                    B(threshold: 0, rate: 0.0025),
                    B(threshold: 2_000, rate: 0.0075),
                    B(threshold: 5_000, rate: 0.0175),
                    B(threshold: 7_500, rate: 0.0275),
                    B(threshold: 9_800, rate: 0.0375),
                    B(threshold: 12_200, rate: 0.0475)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 10_000),
                iraWithdrawalExemption: .partial(maxExempt: 10_000),
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 13_550, married: 27_100),
            safeHarborRule: .flatRate(1.00),
            currentYearSafeHarborRate: 0.70
        )

        // Oregon — 4.75% to 9.9% (4 brackets)
        configs[.oregon] = StateTaxConfig(
            state: .oregon,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0475),
                    B(threshold: 4_050, rate: 0.0675),
                    B(threshold: 10_200, rate: 0.0875),
                    B(threshold: 125_000, rate: 0.099)
                ],
                married: [
                    B(threshold: 0, rate: 0.0475),
                    B(threshold: 8_100, rate: 0.0675),
                    B(threshold: 20_400, rate: 0.0875),
                    B(threshold: 250_000, rate: 0.099)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .taxedAsOrdinary  // OR taxes cap gains as ordinary
            ),
            stateDeduction: .fixed(single: 4_840, married: 9_680),
            safeHarborRule: .flatRate(1.00)
        )

        // Rhode Island — 3.75%, 4.75%, 5.99% (3 brackets)
        configs[.rhodeIsland] = StateTaxConfig(
            state: .rhodeIsland,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0375),
                    B(threshold: 73_450, rate: 0.0475),
                    B(threshold: 166_950, rate: 0.0599)
                ],
                married: [
                    B(threshold: 0, rate: 0.0375),
                    B(threshold: 73_450, rate: 0.0475),
                    B(threshold: 166_950, rate: 0.0599)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // RI taxes SS above AGI threshold
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 11_200, married: 22_400),
            currentYearSafeHarborRate: 0.80
        )

        // South Carolina — 0% to 6.3% (2026, 3 brackets simplified)
        configs[.southCarolina] = StateTaxConfig(
            state: .southCarolina,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.00),
                    B(threshold: 3_460, rate: 0.03),
                    B(threshold: 17_330, rate: 0.063)
                ],
                married: [
                    B(threshold: 0, rate: 0.00),
                    B(threshold: 3_460, rate: 0.03),
                    B(threshold: 17_330, rate: 0.063)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 10_000),  // SC retirement deduction
                iraWithdrawalExemption: .partial(maxExempt: 10_000),
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal
        )

        // Vermont — 3.35% to 8.75% (4 brackets)
        configs[.vermont] = StateTaxConfig(
            state: .vermont,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0335),
                    B(threshold: 45_400, rate: 0.066),
                    B(threshold: 110_050, rate: 0.076),
                    B(threshold: 229_500, rate: 0.0875)
                ],
                married: [
                    B(threshold: 0, rate: 0.0335),
                    B(threshold: 75_850, rate: 0.066),
                    B(threshold: 183_400, rate: 0.076),
                    B(threshold: 279_450, rate: 0.0875)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // VT taxes SS above AGI threshold
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 7_850, married: 15_700),
            safeHarborRule: .flatRate(1.00)
        )

        // Virginia — 2% to 5.75% (4 brackets)
        configs[.virginia] = StateTaxConfig(
            state: .virginia,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 3_000, rate: 0.03),
                    B(threshold: 5_000, rate: 0.05),
                    B(threshold: 17_000, rate: 0.0575)
                ],
                married: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 3_000, rate: 0.03),
                    B(threshold: 5_000, rate: 0.05),
                    B(threshold: 17_000, rate: 0.0575)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 12_000),  // VA age deduction (65+)
                iraWithdrawalExemption: .partial(maxExempt: 12_000),
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 8_750, married: 17_500),
            safeHarborRule: .flatRate(1.00)
        )

        // West Virginia — 2.11% to 4.58% (TY 2026, 5 brackets per SB 392 5% cut)
        //
        // Primary source: WV Tax Division — Personal Income Tax Reduction Bill page
        //   https://tax.wv.gov/Individuals/Pages/PersonalIncomeTaxReductionBill.aspx
        // Enacted legislation: SB 392 (2026 Regular Session), signed 2026-03-31;
        //   codified at W. Va. Code § 11-21-4j; effective 2026-06-12 retroactive to 2026-01-01.
        //   Trigger conditions for the 5% across-the-board cut WERE MET.
        //
        // Note: WV does not double brackets for MFJ — same single schedule applies to
        //   single, MFJ, HoH, and estates/trusts. MFS uses half-thresholds at same rates
        //   (not modeled here; engine only distinguishes single vs married, and MFS is
        //   not a supported filing status).
        // SS exemption: TY 2026 = 100% (phase-in complete per WV Tax Division).
        // WV uses $2,000/person personal exemption (no standard deduction).
        //
        // TriSTAR coverage: source #1 (WV Tax Division primary), source #4 (multi-LLM
        // pending), source #2 (TAXSIM via test suite), source #3 (metamorphic tests).
        // Verified 2026-05-27.
        configs[.westVirginia] = StateTaxConfig(
            state: .westVirginia,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0211),
                    B(threshold: 10_000, rate: 0.0281),
                    B(threshold: 25_000, rate: 0.0316),
                    B(threshold: 40_000, rate: 0.0422),
                    B(threshold: 60_000, rate: 0.0458)
                ],
                married: [
                    B(threshold: 0, rate: 0.0211),
                    B(threshold: 10_000, rate: 0.0281),
                    B(threshold: 25_000, rate: 0.0316),
                    B(threshold: 40_000, rate: 0.0422),
                    B(threshold: 60_000, rate: 0.0458)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // WV TY 2026: SS 100% exempt (phase-in complete)
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none,
            safeHarborRule: .flatRate(1.00)
        )

        // Wisconsin — 3.5% to 7.65% (4 brackets)
        configs[.wisconsin] = StateTaxConfig(
            state: .wisconsin,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.035),
                    B(threshold: 14_320, rate: 0.044),
                    B(threshold: 28_640, rate: 0.053),
                    B(threshold: 315_310, rate: 0.0765)
                ],
                married: [
                    B(threshold: 0, rate: 0.035),
                    B(threshold: 19_090, rate: 0.044),
                    B(threshold: 38_190, rate: 0.053),
                    B(threshold: 420_420, rate: 0.0765)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 6_702, married: 9_461)
        )

        return configs
    }()

    /// Look up configuration for a state. Falls back to California if not found.
    static func config(for state: USState) -> StateTaxConfig {
        configs2026[state] ?? configs2026[.california]!
    }
}
