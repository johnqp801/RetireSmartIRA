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

    /// When `true`, applies the NJ-1040 Worksheet D "Other Retirement Income
    /// Exclusion" (NJSA 54A:6-15). After the pension/IRA exclusion, the UNUSED
    /// portion of the chart maximum (chartMax − pension exclusion) shelters
    /// OTHER eligible income (interest/dividends/cap-gains/refunds/other),
    /// provided the taxpayer is age `regularExemptionMinAge`+ (62 for NJ),
    /// total gross income ≤ $150,000, and earned income (wages/self-employment;
    /// NJ lines 15+18+21+22) ≤ $3,000. Only New Jersey sets this today.
    var otherRetirementIncomeExclusion: Bool = false

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

    /// A single income band in a stepped exclusion phaseout. The percentage of
    /// the (capped) excludable income that survives is filing-status specific.
    /// Bands are evaluated in order; `upperBound` is the inclusive top of the
    /// band (use `.infinity` for the open-ended cliff band).
    struct PhaseoutTier {
        /// Inclusive upper bound of total gross income for this band.
        let upperBound: Double
        /// Fraction of the capped excludable income retained for MFJ filers.
        let mfjPercent: Double
        /// Fraction retained for single filers.
        let singlePercent: Double
    }

    enum ExemptionLevel {
        /// No exemption — fully taxed as ordinary income
        case none
        /// Fully exempt from state income tax
        case full
        /// Partially exempt — first N dollars exempt
        case partial(maxExempt: Double)
        /// Stepped exclusion phased out by TOTAL state gross income, with
        /// per-filing-status caps applied to the excludable income BEFORE the
        /// tier percentage. Models NJSA 54A:6-15 (NJ pension/retirement
        /// exclusion): caps are $100K MFJ / $75K single, and the retained
        /// percentage steps down by income band (not a linear ramp). The
        /// `tiers` array is searched in order for the first band whose
        /// `upperBound` is ≥ the total income.
        case steppedPhaseoutByFilingStatus(
            maxExemptSingle: Double,
            maxExemptMFJ: Double,
            tiers: [PhaseoutTier]
        )

        /// Compute the excluded (subtracted) amount for this level.
        ///
        /// - Parameters:
        ///   - eligibleIncome: the pension / IRA-withdrawal income eligible for
        ///     the exclusion.
        ///   - totalGrossIncome: the total state gross income used as the
        ///     phaseout gate (only consulted by the stepped phaseout case).
        ///   - isMarried: true for MFJ (selects the MFJ cap + MFJ tier %).
        ///   - perIndividualMultiplier: cap doubler for per-taxpayer states
        ///     (NY/GA); applies to `.partial` only.
        ///
        /// Centralizing this keeps `TaxCalculationEngine.applyRetirementExemptions`
        /// and the `DataManager` breakdown computation byte-identical (their
        /// agreement is enforced by StateTaxBreakdownTests).
        func excludedAmount(
            eligibleIncome: Double,
            totalGrossIncome: Double,
            isMarried: Bool,
            perIndividualMultiplier: Double = 1.0
        ) -> Double {
            switch self {
            case .none:
                return 0
            case .full:
                return eligibleIncome
            case .partial(let maxExempt):
                return min(eligibleIncome, maxExempt * perIndividualMultiplier)
            case .steppedPhaseoutByFilingStatus:
                // exclusion = min(eligible × tier%, chartMax). Applying the tier
                // percentage to the income FIRST and then capping at the chart
                // maximum matches NJ-1040 Worksheet D. (The earlier formula
                // capped at $100K/$75K BEFORE the percentage, under-excluding
                // when pension exceeded the cap inside a phaseout band — e.g.
                // $120K pension at total $125K MFJ yielded $50K instead of the
                // correct $60K.) For pension ≤ cap this equals the old result.
                let percent = tierPercent(totalGrossIncome: totalGrossIncome, isMarried: isMarried)
                let max = chartMax(totalGrossIncome: totalGrossIncome, isMarried: isMarried)
                return min(eligibleIncome * percent, max)
            }
        }

        /// Retained-fraction for the band containing `totalGrossIncome`.
        /// Non-stepped levels return 1.0 (the percentage concept doesn't apply).
        func tierPercent(totalGrossIncome: Double, isMarried: Bool) -> Double {
            guard case .steppedPhaseoutByFilingStatus(_, _, let tiers) = self else { return 1.0 }
            let tier = tiers.first { totalGrossIncome <= $0.upperBound } ?? tiers.last
            return tier.map { isMarried ? $0.mfjPercent : $0.singlePercent } ?? 0
        }

        /// The Worksheet D "chart maximum" — the ceiling on the pension/IRA
        /// exclusion AND the basis for the unused other-income exclusion:
        ///   • ≤ first band (≤$100K): the per-filing-status cap ($100K MFJ / $75K single)
        ///   • phaseout bands: tier% × total gross income
        ///   • over the cliff: $0
        /// Returns 0 for non-stepped levels (no chart concept applies).
        func chartMax(totalGrossIncome: Double, isMarried: Bool) -> Double {
            guard case .steppedPhaseoutByFilingStatus(let maxExemptSingle, let maxExemptMFJ, let tiers) = self else { return 0 }
            let cap = isMarried ? maxExemptMFJ : maxExemptSingle
            let percent = tierPercent(totalGrossIncome: totalGrossIncome, isMarried: isMarried)
            // First band retains 100% — the chart max there is the flat cap.
            // Otherwise it is the tier percentage applied to total income
            // (and 0 in the cliff band, where percent == 0).
            if percent >= 1.0 { return cap }
            return percent * totalGrossIncome
        }
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

    /// NJSA 54A:6-15 stepped pension/retirement exclusion phaseout tiers,
    /// keyed by TOTAL NJ gross income. Bands are inclusive of their upper
    /// bound; the final band is the open-ended ($150K+) zero-exclusion cliff.
    static let njRetirementExclusionTiers: [RetirementIncomeExemptions.PhaseoutTier] = [
        .init(upperBound: 100_000, mfjPercent: 1.0,  singlePercent: 1.0),
        .init(upperBound: 125_000, mfjPercent: 0.50, singlePercent: 0.375),
        .init(upperBound: 150_000, mfjPercent: 0.25, singlePercent: 0.1875),
        .init(upperBound: .infinity, mfjPercent: 0.0, singlePercent: 0.0)
    ]

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

        // Massachusetts — 5% base + 4% Fair Share surtax (TY 2026 per Article CXII)
        //
        // Primary source: MA DOR 4% Surtax page (DOR-certified TY 2026 threshold)
        //   https://www.mass.gov/info-details/massachusetts-4-surtax-on-taxable-income
        // Enacted legislation: Massachusetts Constitution Article CXII (Question 1
        //   ballot initiative, Nov 2022), implemented via M.G.L. c. 62 §§ 4(d), 5A.
        //
        // Threshold inflation-indexed annually from $1,000,000 anchor (TY 2023):
        //   TY 2023: $1,000,000; TY 2024: $1,053,750; TY 2025: $1,083,150;
        //   TY 2026: $1,107,750 (DOR-certified).
        //
        // Same threshold for Single and MFJ (constitutional — no MFJ doubling).
        // MA uses personal exemptions ($4,400 single / $8,800 MFJ); no separate
        // standard deduction.
        //
        // Pre-fix code modeled MA as pure flat 5% — missed the Fair Share surtax
        // entirely for >$1.1M income filers (high-net-worth retirees in MA).
        //
        // Note: MA also has a 9% surtax on short-term capital gains (>1yr held)
        // not modeled in capitalGainsTreatment (simplified to .followsFederal).
        //
        // TriSTAR coverage: source #1 (DOR-certified primary), source #4 (multi-LLM
        // pending), sources #2/#3 (test suite). Verified 2026-05-27.
        configs[.massachusetts] = StateTaxConfig(
            state: .massachusetts,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.05),
                    B(threshold: 1_107_750, rate: 0.09)  // 5% base + 4% Fair Share surtax
                ],
                married: [
                    B(threshold: 0, rate: 0.05),
                    B(threshold: 1_107_750, rate: 0.09)  // Same threshold; constitutional no-doubling
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,  // MA taxes pension income
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal  // MA 9% surtax on short-term gains simplified here
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

        // North Dakota — 3-bracket progressive 0% / 1.95% / 2.50% (TY 2023+ per SB 2293)
        //
        // Primary source: ND Tax Commissioner Individual Income Tax page
        //   https://www.tax.nd.gov/individual-income-tax
        // Enacted legislation: SB 2293, 67th Legislative Assembly (2023 Session),
        //   replacing the prior 5-bracket schedule with the current 3-bracket structure.
        //
        // FIX OF LONG-STANDING MODELING ERROR: Pre-fix code modeled ND as flat 1.95%.
        // This was wrong for TY 2023+ — ND has had a 3-bracket structure (0% / 1.95% /
        // 2.50%) including a zero-rate first bracket that shelters most modest-income
        // retirees from ND state tax entirely.
        //
        // TY 2026 thresholds (using TY 2025 indexed values as best-available proxy
        // until ND Tax Commissioner publishes TY 2026 indexed thresholds in late
        // 2026 / early 2027):
        //   Single: 0% on $0–$48,475; 1.95% on $48,475–$244,825; 2.50% over $244,825
        //   MFJ:    0% on $0–$80,975; 1.95% on $80,975–$298,075; 2.50% over $298,075
        //
        // ND uses federal taxable income as starting point (conformsToFederal); no
        // separate state std deduction. Federal std deduction (post-OBBBA TY 2026)
        // flows through.
        //
        // Social Security: 100% exempt since TY 2021 (no change).
        //
        // TriSTAR coverage: source #1 (ND Tax Commissioner primary),
        // source #4 (multi-LLM pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.northDakota] = StateTaxConfig(
            state: .northDakota,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 48_475, rate: 0.0195),
                    B(threshold: 244_825, rate: 0.025)
                ],
                married: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 80_975, rate: 0.0195),
                    B(threshold: 298_075, rate: 0.025)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // ND fully exempts SS since TY 2021
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal
        )

        // Ohio — 2-bracket 0% / 2.75% with $26,050 zero-bracket floor (TY 2026 per HB 96)
        //
        // Primary source: Ohio Department of Taxation 2026 IT 1040 instructions / rate page
        //   https://tax.ohio.gov/
        // Enacted legislation: HB 96, 136th Ohio General Assembly (FY26-27 biennial budget,
        //   signed by Gov. DeWine 2025-06-30), effective for TY 2026.
        //
        // HB 96 collapsed prior 2-bracket schedule (2.75% / 3.5%) into a single 2.75%
        // flat rate above the $26,050 zero-bracket. Pre-fix code modeled OH as PURE flat
        // 2.75% with NO zero-bracket — materially overstated tax for low-income OH
        // retirees (e.g., a retiree with $20K taxable income should pay $0 OH tax under
        // the actual schedule, but pre-fix code charged 2.75% × $20K = $550).
        //
        // OH uses identical schedule for Single and MFJ (no doubling).
        //
        // Existing OH retirement income credit, lump-sum credits, and SS exclusion
        // continue under HB 96 (already represented by socialSecurityExempt: true).
        //
        // Note: OH business income remains a separate 3% flat above $250K deduction
        // (NOT modeled here; out of scope for retirement-tax-planning).
        //
        // TriSTAR coverage: source #1 (Ohio Tax + HB 96 enacted text),
        // source #4 (multi-LLM pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.ohio] = StateTaxConfig(
            state: .ohio,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 26_050, rate: 0.0275)
                ],
                married: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 26_050, rate: 0.0275)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .none,  // OH uses the $26,050 zero-bracket as effective deduction
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
        // Delaware — 0% to 6.6% (7 brackets incl. $0-$2,000 zero bracket; same schedule all filers)
        // Primary source: DE Division of Revenue Tax Rate Changes
        //   https://revenue.delaware.gov/software-developer/tax-rate-changes/
        // Structurally unchanged for TY 2026 (HB 13 did not pass 2025 session).
        // Pension exclusion: age 60+ = $12,500/person; under 60 = $2,000/person (not modeled here).
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.delaware] = StateTaxConfig(
            state: .delaware,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 2_000, rate: 0.022),
                    B(threshold: 5_000, rate: 0.039),
                    B(threshold: 10_000, rate: 0.048),
                    B(threshold: 20_000, rate: 0.052),
                    B(threshold: 25_000, rate: 0.0555),
                    B(threshold: 60_000, rate: 0.066)
                ],
                married: [
                    B(threshold: 0, rate: 0.0),
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

        // Kansas — 2-bracket 5.20% / 5.58% (TY 2026 per SB 1 of 2024 Special Session)
        //
        // Primary source: KS Department of Revenue Income Tax Booklet 2025 / 2026 Tax Rates
        //   https://www.ksrevenue.gov/
        // Enacted legislation: SB 1, 2024 Special Session (signed June 2024).
        //
        // Major reform: collapsed 3-bracket schedule (3.1%/5.25%/5.7%) into 2 brackets
        // (5.20%/5.58%). Bracket boundaries: $23,000 single / $46,000 MFJ.
        // KS doubles thresholds for MFJ at same rates.
        //
        // Social Security: 100% exempt for ALL filers at ALL AGI levels (prior $75K AGI
        // cliff removed by SB 1 starting TY 2024). Engine comment updated accordingly.
        //
        // Standard deduction TY 2026: $3,605 single / $8,240 MFJ (indexed from base
        // $3,500/$8,000). Already correct in production code.
        //
        // TriSTAR coverage: source #1 (KDOR primary + SB 1 enacted text),
        // source #4 (multi-LLM pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.kansas] = StateTaxConfig(
            state: .kansas,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.052),
                    B(threshold: 23_000, rate: 0.0558)
                ],
                married: [
                    B(threshold: 0, rate: 0.052),
                    B(threshold: 46_000, rate: 0.0558)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                // KS SS exemption: 100% at all AGI levels (TY 2024+, SB 1 § 18).
                // SB 1 fully REMOVED the prior $75K federal AGI cap — not raised, not
                // phased; eliminated outright. Per KS DOR Notice 24-08:
                //   "The amended language removes the income limitation and allows
                //    all taxpayers receiving social security benefits... to claim
                //    the subtraction modification, regardless of the amount of their
                //    federal adjusted gross income."
                // https://www.ksrevenue.gov/taxnotices/notice24-08.pdf
                // K.S.A. 79-32,117 as amended by SB 1 § 18.
                // Engine: `socialSecurityExempt: true` unconditionally exempts. No
                // AGI-aware modeling needed for KS (unlike CT pension where AGI
                // phaseout requires .partialWithAGIPhaseout).
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 3_605, married: 8_240),
            safeHarborRule: .flatRate(1.00)
        )

        // Louisiana — flat 3% (TY 2025+ per HB 10 of 2024 Third Extraordinary Session)
        //
        // Primary source: LA DOR Income Tax Rates FAQ
        //   https://revenue.louisiana.gov/tax-education-and-faqs/faqs/income-tax-reform/what-are-the-individual-income-tax-rates-and-brackets/
        // Enacted legislation: HB 10 of 2024 3rd Ex. Sess. (Build Louisiana Forward Act),
        //   signed by Gov. Landry 2024-12-04, effective 2025-01-01.
        //
        // Major reform: replaced 3-bracket progressive (1.85%/3.5%/4.25%) with FLAT 3.0%.
        // Single = MFJ flat rate (same 3% applies; no brackets to double).
        //
        // Retirement income exemption (age 65+) doubled from $6,000 to $12,000 per HB 10,
        // with annual CPI indexing starting TY 2026 (LDR has not yet published 2026
        // indexed value — using base $12,000 as conservative floor).
        //
        // Standard deduction: $12,500 single / $25,000 MFJ statutory base (HB 10),
        // inflation-indexed starting TY 2026. LDR has not yet published 2026 indexed
        // value — using base as conservative floor. (Agent research estimates TY 2026
        // indexed ~$12,875/$25,750.)
        //
        // Note: LA public pensions / federal civil service / military retirement remain
        // fully exempt — not modeled separately by source (engine treats all pension/IRA
        // identically with the $12K partial cap). Acceptable planning-tool approximation.
        //
        // TriSTAR coverage: source #1 (LDR primary + HB 10 enacted text),
        // source #4 (multi-LLM pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.louisiana] = StateTaxConfig(
            state: .louisiana,
            taxSystem: .flat(rate: 0.03),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 12_000),  // HB 10: doubled $6K → $12K (age 65+), indexed
                iraWithdrawalExemption: .partial(maxExempt: 12_000),
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 12_500, married: 25_000),  // HB 10 statutory base; TY 2026 indexed value pending LDR publication
            safeHarborRule: .flatRate(1.00)
        )

        // Maine — 5.8%, 6.75%, 7.15% (3 brackets)
        // Maine — 5.8% / 6.75% / 7.15% + NEW 2% millionaire surcharge for TY 2026
        // Primary source: Maine Revenue Services 2026 Individual Tax Rate Schedules
        //   https://www.maine.gov/revenue/sites/maine.gov.revenue/files/inline-files/ind_tax_rate_sched_2026.pdf
        // Brackets inflation-adjusted vs TY 2025. NEW 2% surcharge on income above
        //   $1,000,000 (Single) / $1,500,000 (MFJ/HoH) — added top 9.15% bracket.
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.maine] = StateTaxConfig(
            state: .maine,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.058),
                    B(threshold: 27_400, rate: 0.0675),
                    B(threshold: 64_850, rate: 0.0715),
                    B(threshold: 1_000_000, rate: 0.0915)  // 7.15% + 2% millionaire surcharge (TY 2026)
                ],
                married: [
                    B(threshold: 0, rate: 0.058),
                    B(threshold: 54_850, rate: 0.0675),
                    B(threshold: 129_750, rate: 0.0715),
                    B(threshold: 1_500_000, rate: 0.0915)  // 7.15% + 2% millionaire surcharge (TY 2026)
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
        // Minnesota — 5.35% / 6.80% / 7.85% / 9.85% (TY 2026, brackets inflation-adjusted)
        // Primary source: MN DOR 2025-12-16 press release (TY 2026 brackets +2.369%)
        //   https://www.revenue.state.mn.us/press-release/2025-12-16/minnesota-income-tax-brackets-standard-deduction-and-dependent-exemption
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.minnesota] = StateTaxConfig(
            state: .minnesota,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0535),
                    B(threshold: 33_310, rate: 0.068),
                    B(threshold: 109_430, rate: 0.0785),
                    B(threshold: 203_150, rate: 0.0985)
                ],
                married: [
                    B(threshold: 0, rate: 0.0535),
                    B(threshold: 48_700, rate: 0.068),
                    B(threshold: 193_480, rate: 0.0785),
                    B(threshold: 337_930, rate: 0.0985)
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

        // Missouri — 0% / 2% / 2.5% / 3% / 3.5% / 4% / 4.5% / 4.7% (TY 2026, 8 brackets incl. zero)
        // Primary source: MO DOR 2026 Withholding Tax Formula (page 13, Annual Payroll column)
        //   https://dor.mo.gov/forms/Withholding%20Formula_2026.pdf
        // Thresholds inflation-bumped +2.67% from TY 2025 per MO § 143.011 CPI indexing.
        // Top rate 4.7% holds (trigger to 4.5% NOT met for 2026).
        // HB 798: private pension full 100% exemption begins TY 2026 (was $6K capped). MO also
        // fully exempts SS since TY 2024 and public pensions 100% since TY 2024.
        // Same brackets across filing statuses (MO has no MFJ doubling).
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.missouri] = StateTaxConfig(
            state: .missouri,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 1_348, rate: 0.02),
                    B(threshold: 2_696, rate: 0.025),
                    B(threshold: 4_044, rate: 0.03),
                    B(threshold: 5_392, rate: 0.035),
                    B(threshold: 6_740, rate: 0.04),
                    B(threshold: 8_088, rate: 0.045),
                    B(threshold: 9_436, rate: 0.047)
                ],
                married: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 1_348, rate: 0.02),
                    B(threshold: 2_696, rate: 0.025),
                    B(threshold: 4_044, rate: 0.03),
                    B(threshold: 5_392, rate: 0.035),
                    B(threshold: 6_740, rate: 0.04),
                    B(threshold: 8_088, rate: 0.045),
                    B(threshold: 9_436, rate: 0.047)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // MO fully exempts SS (TY 2024+)
                pensionExemption: .full,     // HB 798: 100% private + public pension TY 2026
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal
        )

        // Montana — 2-bracket 4.70% / 5.65% (TY 2026 per HB 337)
        //
        // Primary source: MT DOR HB 337 page (publishes bracket schedule directly)
        //   https://revenue.mt.gov/news/recent-news/HB-337
        // Enacted legislation: HB 337, 69th Montana Legislature (2025 Regular Session).
        //
        // Pre-fix code modeled MT as flat 4.7% — WRONG. MT has been 2-bracket progressive
        // since TY 2024. HB 337 effective 1/1/2026 reduced top rate 5.9% → 5.65% and
        // widened lower bracket.
        //
        // New thresholds (per HB 337):
        //   Single: 4.70% on $0-$47,500; 5.65% over $47,500
        //   MFJ:    4.70% on $0-$95,000; 5.65% over $95,000
        //
        // MT uses .conformsToFederal for std deduction (federal $15,750/$31,500 projected
        // TY 2026 post-OBBBA flows through).
        //
        // Pension subtraction ($4,640) is inflation-indexed — current value may be stale;
        // verify exact TY 2026 amount before next release.
        //
        // Note: top rate drops further to 5.40% in TY 2027 per HB 337 phased schedule.
        //
        // TriSTAR coverage: source #1 (MT DOR HB 337 page primary),
        // source #4 (multi-LLM pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.montana] = StateTaxConfig(
            state: .montana,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.047),
                    B(threshold: 47_500, rate: 0.0565)
                ],
                married: [
                    B(threshold: 0, rate: 0.047),
                    B(threshold: 95_000, rate: 0.0565)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // MT taxes SS (with partial deduction not modeled here)
                pensionExemption: .partial(maxExempt: 4_640),  // TODO: verify exact TY 2026 indexed value
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal,
            safeHarborRule: .flatRate(1.00)
        )

        // Nebraska — 2.46% / 3.51% / 4.55% (TY 2026, 3 brackets per LB 754)
        // Primary source: Neb. Rev. Stat. § 77-2715.03 (statute)
        //   https://nebraskalegislature.gov/laws/statutes.php?statute=77-2715.03
        // Also: NE DOR Circular EN 2026 (rev 11-2025), supersedes 11-2024
        //   https://revenue.nebraska.gov/sites/default/files/doc/business/Cir_En_2025/2026cir_en_whole.pdf
        // LB 754 phase-down for TY 2026: top rate 5.20% → 4.55%; consolidated to 3 brackets
        // by merging former brackets 3 and 4. Brackets are statutorily frozen (not inflation-
        // indexed). Further drop to 3.99% effective TY 2027.
        // SS 100% exempt since TY 2025 (also LB 754).
        // Verified 2026-05-27 (Bucket 2 sweep — closes TriSTAR Nebraska gap).
        configs[.nebraska] = StateTaxConfig(
            state: .nebraska,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0246),
                    B(threshold: 2_400, rate: 0.0351),
                    B(threshold: 18_000, rate: 0.0455)
                ],
                married: [
                    B(threshold: 0, rate: 0.0246),
                    B(threshold: 4_800, rate: 0.0351),
                    B(threshold: 36_000, rate: 0.0455)
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
                // AGI phaseout (TY2021+), stepped by TOTAL NJ gross income:
                //   ≤ $100,000          → 100% / 100%  (MFJ / single)
                //   $100,001–$125,000   →  50% / 37.5%
                //   $125,001–$150,000   →  25% / 18.75%
                //   > $150,000          →   0% / 0%  (cliff)
                // The per-filing-status cap ($100K MFJ / $75K single) is
                // applied to the excludable pension/IRA income BEFORE the
                // tier percentage.
                //
                // NJSA 54A:6-15 grants ONE COMBINED exclusion across ALL
                // qualifying retirement income (pension + annuity + IRA
                // withdrawals) — the cap is an AGGREGATE, not per income type.
                // `pensionAndIRAShareSingleCap: true` makes the engine combine
                // pension + IRA income, apply the per-filing-status cap to the
                // total, then apply the stepped tier percentage based on total
                // gross income. Without the flag the cap would be applied to
                // pension and IRA separately, over-excluding for filers with
                // both income types.
                pensionExemption: .steppedPhaseoutByFilingStatus(
                    maxExemptSingle: 75_000,
                    maxExemptMFJ: 100_000,
                    tiers: njRetirementExclusionTiers
                ),
                iraWithdrawalExemption: .steppedPhaseoutByFilingStatus(
                    maxExemptSingle: 75_000,
                    maxExemptMFJ: 100_000,
                    tiers: njRetirementExclusionTiers
                ),
                regularExemptionMinAge: 62,
                pensionAndIRAShareSingleCap: true,
                // NJ-1040 Worksheet D: the unused chart maximum shelters other
                // retirement income (62+, total ≤ $150K, earned ≤ $3,000).
                otherRetirementIncomeExclusion: true,
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

        // New York — 3.9% to 10.9% (9 brackets, bottom-5 rate cuts effective TY 2026)
        // Primary source: NYS Pub NYS-50-T-NYS rev 1/26 (TY 2026 withholding tables)
        //   https://www.tax.ny.gov/pdf/publications/withholding/nys50_t_nys.pdf
        // Also: NYS DTF withholding rate change notice citing Chapter 59 of Laws of 2025, Part A
        //   https://www.tax.ny.gov/bus/wt/rate.htm
        // Chapter 59/2025 Part A cut the bottom 5 bracket rates effective 2026-01-01:
        //   4.00% → 3.90%, 4.50% → 4.40%, 5.25% → 5.15%, 5.85% → 5.40%, 6.25% → 5.90%.
        // High-income brackets ($1.077M+/$2.155M+) at 9.65%/10.30%/10.90% extended through 2032.
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.newYork] = StateTaxConfig(
            state: .newYork,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.039),
                    B(threshold: 8_500, rate: 0.044),
                    B(threshold: 11_700, rate: 0.0515),
                    B(threshold: 13_900, rate: 0.054),
                    B(threshold: 80_650, rate: 0.059),
                    B(threshold: 215_400, rate: 0.0685),
                    B(threshold: 1_077_550, rate: 0.0965),
                    B(threshold: 5_000_000, rate: 0.103),
                    B(threshold: 25_000_000, rate: 0.109)
                ],
                married: [
                    B(threshold: 0, rate: 0.039),
                    B(threshold: 17_150, rate: 0.044),
                    B(threshold: 23_600, rate: 0.0515),
                    B(threshold: 27_900, rate: 0.054),
                    B(threshold: 161_550, rate: 0.059),
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
                // In the shared-cap branch perIndividualMultiplier=2.0 doubles
                // the cap → exclusion = min(combinedPensionIRA, 20_000 × 2).
                exemptionAppliesPerIndividual: true,
                // Age 59½ statutory minimum. Engine uses integer ages; we use
                // 59 as a slightly generous approximation matching the rest of
                // the engine's `>= 59` convention for retirement-age gates.
                regularExemptionMinAge: 59,
                // § 612(c)(3-a) is ONE combined $20,000 exclusion per qualifying
                // individual across pension + annuity + IRA distributions — NOT
                // a separate $20K for pension and another $20K for IRA. Route
                // pension and IRA through the shared-cap branch (same mechanism
                // NJ/CO use) so ONE $20K applies to the SUMMED pension+IRA income.
                // Without this flag the engine subtracted up to $20K twice
                // (~$40K/person), over-exempting retirees holding both.
                // KNOWN LIMITATION: the combined-cap branch sums HOUSEHOLD
                // pension+IRA, so a concentrated-income MFJ couple (one spouse
                // holding most of the income) may still slightly over-exempt vs.
                // true per-spouse caps. Full per-spouse dollar attribution is a
                // deferred follow-up.
                pensionAndIRAShareSingleCap: true,
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .fixed(single: 8_000, married: 16_050)
        )

        // Oklahoma — 0% / 2.5% / 3.5% / 4.5% (TY 2026, 4 brackets per HB 2764)
        // Primary source: OK Tax Commission Packet OW-2 (rev 11-2025)
        //   https://oklahoma.gov/content/dam/ok/en/tax/documents/resources/publications/businesses/withholding-tables/WHTables-2026.pdf
        // Enacted: HB 2764 (signed May 2025)
        //   https://www.oklegislature.gov/cf_pdf/2025-26%20ENR/hB/HB2764%20ENR.PDF
        // MAJOR RESTRUCTURE: collapsed 6 brackets → 4 (incl. 0% zero bracket); top 4.75% → 4.50%.
        // MFJ uses doubled thresholds. HB 2764 also adds 0.25-pp trigger reductions toward
        // eventual elimination if revenue benchmarks are certified by the Board of Equalization.
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.oklahoma] = StateTaxConfig(
            state: .oklahoma,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 3_750, rate: 0.025),
                    B(threshold: 4_900, rate: 0.035),
                    B(threshold: 7_200, rate: 0.045)
                ],
                married: [
                    B(threshold: 0, rate: 0.0),
                    B(threshold: 7_500, rate: 0.025),
                    B(threshold: 9_800, rate: 0.035),
                    B(threshold: 14_400, rate: 0.045)
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

        // Rhode Island — 3.75% / 4.75% / 5.99% (TY 2026, brackets inflation-adjusted)
        // Primary source: RI Division of Taxation Advisory 2025-22 (Inflation Adjustments TY 2026)
        //   https://tax.ri.gov/sites/g/files/xkgbur541/files/2025-11/ADV_2025_22_Inflation_Adjustments.pdf
        // Same brackets across all filing statuses (RI does not double for MFJ).
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.rhodeIsland] = StateTaxConfig(
            state: .rhodeIsland,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0375),
                    B(threshold: 82_050, rate: 0.0475),
                    B(threshold: 186_450, rate: 0.0599)
                ],
                married: [
                    B(threshold: 0, rate: 0.0375),
                    B(threshold: 82_050, rate: 0.0475),
                    B(threshold: 186_450, rate: 0.0599)
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

        // South Carolina — 2-tier 1.99% / 5.21% (TY 2026 per H.4216, signed March 30, 2026)
        //
        // Primary source: SC DOR H.4216 information page
        //   https://dor.sc.gov/news/information-about-h-4216
        // Enacted legislation: H.4216, 126th General Assembly, signed by Gov. McMaster
        //   2026-03-30 (ceremonially re-signed April 15, 2026).
        //
        // MAJOR RESTRUCTURE: H.4216 replaced prior 3-bracket schedule (0% / 3% / 6.3%)
        // with 2-tier 1.99% / 5.21%. The $966 credit-equivalent adjustment in H.4216
        // ensures continuity at the $30,000 boundary; mathematically equivalent to
        // standard progressive bracket math (1.99% × min(income, 30K) + 5.21% ×
        // max(0, income - 30K)).
        //
        // SC uses same schedule for Single and MFJ (no doubling).
        //
        // SCIAD NOTE: H.4216 also decoupled SC from federal standard/itemized deductions,
        // replacing federal std deduction with a new "SC Income Adjusted Deduction" (SCIAD).
        // Starting point is now Federal AGI (was federal taxable income). Exact SCIAD value
        // pending SCDOR's 2026 SC1040 instructions. Until then, keep .conformsToFederal as
        // a conservative-floor approximation; engine should refresh once SCDOR publishes
        // the 2026 SC1040 booklet. (Acceptable planning-tool approximation pending
        // primary-source SCIAD specifics.)
        //
        // Existing retirement deductions continue per H.4216:
        //   $10,000 retirement income deduction (under 65)
        //   $15,000 retirement income deduction (age 65+) — additional, not modeled
        //   SS remains fully exempt
        //
        // Future further rate reductions are trigger-based (≥5% BEA revenue growth,
        // ≤$200M revenue impact, certified by Feb 15 annually). TY 2026 base schedule
        // (1.99% / 5.21%) is NOT trigger-dependent — it is the statutory schedule.
        //
        // TriSTAR coverage: source #1 (SCDOR primary + H.4216 enacted text),
        // source #4 (multi-LLM pending), sources #2/#3 (test suite).
        // Verified 2026-05-27.
        configs[.southCarolina] = StateTaxConfig(
            state: .southCarolina,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0199),
                    B(threshold: 30_000, rate: 0.0521)
                ],
                married: [
                    B(threshold: 0, rate: 0.0199),
                    B(threshold: 30_000, rate: 0.0521)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 10_000),  // SC retirement deduction (unchanged by H.4216)
                iraWithdrawalExemption: .partial(maxExempt: 10_000),
                capitalGainsTreatment: .followsFederal
            ),
            stateDeduction: .conformsToFederal  // TODO: SCIAD per H.4216 decoupling pending SCDOR 2026 SC1040 publication
        )

        // Vermont — 3.35% to 8.75% (4 brackets)
        // Vermont — 3.35% / 6.6% / 7.6% / 8.75% (TY 2025 primary-source values used as TY 2026
        // floor; VT DOT published TY 2026 schedule 2025-12-22 but PDF endpoints not machine-
        // readable. TY 2026 thresholds are inflation-adjusted ~2-3% upward; using TY 2025 here
        // is a conservative under-bracket position acceptable under Path 1.)
        // Primary source: VT Department of Taxes 2026 / 2025 Rate Schedules
        //   https://tax.vermont.gov/document/2026-vt-rate-schedules
        //   https://tax.vermont.gov/individuals/personal-income-tax/rates
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.vermont] = StateTaxConfig(
            state: .vermont,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0335),
                    B(threshold: 47_900, rate: 0.066),
                    B(threshold: 116_000, rate: 0.076),
                    B(threshold: 242_000, rate: 0.0875)
                ],
                married: [
                    B(threshold: 0, rate: 0.0335),
                    B(threshold: 80_200, rate: 0.066),
                    B(threshold: 194_000, rate: 0.076),
                    B(threshold: 294_600, rate: 0.0875)
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

        // Wisconsin — 3.5% / 4.4% / 5.3% / 7.65% (TY 2026, brackets inflation-adjusted)
        // Primary source: WI DOR Tax Rates FAQ
        //   https://www.revenue.wi.gov/Pages/FAQS/pcs-taxrates.aspx
        // Rates unchanged from 2023 Act 19 (which cut bottom two rates). MFJ uses ~1.33x
        // single thresholds (statutory factor, not flat doubling).
        // Verified 2026-05-27 (Bucket 2 sweep).
        configs[.wisconsin] = StateTaxConfig(
            state: .wisconsin,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.035),
                    B(threshold: 14_680, rate: 0.044),
                    B(threshold: 50_480, rate: 0.053),
                    B(threshold: 323_290, rate: 0.0765)
                ],
                married: [
                    B(threshold: 0, rate: 0.035),
                    B(threshold: 19_580, rate: 0.044),
                    B(threshold: 67_300, rate: 0.053),
                    B(threshold: 431_060, rate: 0.0765)
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
