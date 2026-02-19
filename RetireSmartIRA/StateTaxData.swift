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
    case progressive(single: [DataManager.TaxBracket], married: [DataManager.TaxBracket])

    /// States with limited/special income tax (NH: dividends/interest only; WA: capital gains only)
    case specialLimited
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

    /// How the state treats capital gains
    var capitalGainsTreatment: CapGainsTreatment = .followsFederal

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

// MARK: - State Tax Configuration

/// Complete tax configuration for a single state in a single tax year.
/// All state-specific tax rules are co-located here for easy annual maintenance.
struct StateTaxConfig {
    let state: USState
    let taxSystem: StateTaxSystem
    let retirementExemptions: RetirementIncomeExemptions
}

// MARK: - 2026 State Tax Data

/// Static lookup of all 50 state + DC tax configurations for the 2026 tax year.
/// To update for a new tax year: change rates/thresholds here. No logic changes needed.
struct StateTaxData {

    /// Shorthand alias for bracket creation
    private typealias B = DataManager.TaxBracket

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
                )
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
            )
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
            )
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
            )
        )

        // Colorado — 4.40% flat rate (2026)
        configs[.colorado] = StateTaxConfig(
            state: .colorado,
            taxSystem: .flat(rate: 0.044),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // CO exempts SS for age 65+ (fully exempt 2026)
                pensionExemption: .partial(maxExempt: 24_000),  // age 65+ exclusion
                iraWithdrawalExemption: .partial(maxExempt: 24_000),  // combined with pension
                capitalGainsTreatment: .followsFederal
            )
        )

        // Georgia — 5.39% flat rate (2026, phasing down)
        configs[.georgia] = StateTaxConfig(
            state: .georgia,
            taxSystem: .flat(rate: 0.0539),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 65_000),  // age 62+ retirement income exclusion
                iraWithdrawalExemption: .partial(maxExempt: 65_000),  // combined
                capitalGainsTreatment: .followsFederal
            )
        )

        // Idaho — 5.695% flat rate (2026)
        configs[.idaho] = StateTaxConfig(
            state: .idaho,
            taxSystem: .flat(rate: 0.05695),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            )
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
            )
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
            )
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
            )
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
            )
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
            )
        )

        // Michigan — 4.05% flat rate
        configs[.michigan] = StateTaxConfig(
            state: .michigan,
            taxSystem: .flat(rate: 0.0405),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,  // MI phasing to full retirement income exemption by 2026
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            )
        )

        // Mississippi — 4.4% flat rate (2026, simplified from progressive)
        configs[.mississippi] = StateTaxConfig(
            state: .mississippi,
            taxSystem: .flat(rate: 0.044),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,  // MS exempts all retirement income
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            )
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
            )
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
            )
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
            )
        )

        // Pennsylvania — 3.07% flat rate
        configs[.pennsylvania] = StateTaxConfig(
            state: .pennsylvania,
            taxSystem: .flat(rate: 0.0307),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,  // PA exempts all retirement income
                iraWithdrawalExemption: .full,
                capitalGainsTreatment: .followsFederal
            )
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
            )
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
            )
        )

        // Arkansas — 2%, 4%, 4.4% (2026, reduced top rate)
        configs[.arkansas] = StateTaxConfig(
            state: .arkansas,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 4_400, rate: 0.04),
                    B(threshold: 8_800, rate: 0.044)
                ],
                married: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 4_400, rate: 0.04),
                    B(threshold: 8_800, rate: 0.044)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 6_000),
                iraWithdrawalExemption: .partial(maxExempt: 6_000),
                capitalGainsTreatment: .followsFederal
            )
        )

        // California — 1% to 12.3% (9 brackets, unchanged for 2026)
        configs[.california] = StateTaxConfig(
            state: .california,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.01),
                    B(threshold: 10_412, rate: 0.02),
                    B(threshold: 24_684, rate: 0.04),
                    B(threshold: 38_959, rate: 0.06),
                    B(threshold: 54_081, rate: 0.08),
                    B(threshold: 68_350, rate: 0.093),
                    B(threshold: 349_137, rate: 0.103),
                    B(threshold: 418_961, rate: 0.113),
                    B(threshold: 698_271, rate: 0.123)
                ],
                married: [
                    B(threshold: 0, rate: 0.01),
                    B(threshold: 20_824, rate: 0.02),
                    B(threshold: 49_368, rate: 0.04),
                    B(threshold: 77_918, rate: 0.06),
                    B(threshold: 108_162, rate: 0.08),
                    B(threshold: 136_700, rate: 0.093),
                    B(threshold: 698_274, rate: 0.103),
                    B(threshold: 837_922, rate: 0.113),
                    B(threshold: 1_396_542, rate: 0.123)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,  // CA does not tax SS
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .taxedAsOrdinary  // CA taxes cap gains as ordinary income
            )
        )

        // Connecticut — 3% to 6.99% (7 brackets)
        configs[.connecticut] = StateTaxConfig(
            state: .connecticut,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.03),
                    B(threshold: 10_000, rate: 0.05),
                    B(threshold: 50_000, rate: 0.055),
                    B(threshold: 100_000, rate: 0.06),
                    B(threshold: 200_000, rate: 0.065),
                    B(threshold: 250_000, rate: 0.069),
                    B(threshold: 500_000, rate: 0.0699)
                ],
                married: [
                    B(threshold: 0, rate: 0.03),
                    B(threshold: 20_000, rate: 0.05),
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
            )
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
            )
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
            )
        )

        // Hawaii — 1.4% to 11% (12 brackets)
        configs[.hawaii] = StateTaxConfig(
            state: .hawaii,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.014),
                    B(threshold: 2_400, rate: 0.032),
                    B(threshold: 4_800, rate: 0.055),
                    B(threshold: 9_600, rate: 0.064),
                    B(threshold: 14_400, rate: 0.068),
                    B(threshold: 19_200, rate: 0.072),
                    B(threshold: 24_000, rate: 0.076),
                    B(threshold: 36_000, rate: 0.079),
                    B(threshold: 48_000, rate: 0.0825),
                    B(threshold: 150_000, rate: 0.09),
                    B(threshold: 175_000, rate: 0.10),
                    B(threshold: 200_000, rate: 0.11)
                ],
                married: [
                    B(threshold: 0, rate: 0.014),
                    B(threshold: 4_800, rate: 0.032),
                    B(threshold: 9_600, rate: 0.055),
                    B(threshold: 19_200, rate: 0.064),
                    B(threshold: 28_800, rate: 0.068),
                    B(threshold: 38_400, rate: 0.072),
                    B(threshold: 48_000, rate: 0.076),
                    B(threshold: 72_000, rate: 0.079),
                    B(threshold: 96_000, rate: 0.0825),
                    B(threshold: 300_000, rate: 0.09),
                    B(threshold: 350_000, rate: 0.10),
                    B(threshold: 400_000, rate: 0.11)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            )
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
            )
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
            )
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
            )
        )

        // Maryland — 2% to 5.75% (8 brackets)
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
                    B(threshold: 250_000, rate: 0.0575)
                ],
                married: [
                    B(threshold: 0, rate: 0.02),
                    B(threshold: 1_000, rate: 0.03),
                    B(threshold: 2_000, rate: 0.04),
                    B(threshold: 3_000, rate: 0.0475),
                    B(threshold: 150_000, rate: 0.05),
                    B(threshold: 175_000, rate: 0.0525),
                    B(threshold: 225_000, rate: 0.055),
                    B(threshold: 300_000, rate: 0.0575)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 39_500),  // MD pension exclusion (age 65+)
                iraWithdrawalExemption: .partial(maxExempt: 39_500),
                capitalGainsTreatment: .followsFederal
            )
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
            )
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
            )
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
            )
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
            )
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
                pensionExemption: .partial(maxExempt: 100_000),  // NJ generous pension exclusion
                iraWithdrawalExemption: .partial(maxExempt: 100_000),
                capitalGainsTreatment: .followsFederal
            )
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
            )
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
                pensionExemption: .partial(maxExempt: 20_000),  // NY pension/annuity exclusion
                iraWithdrawalExemption: .partial(maxExempt: 20_000),
                capitalGainsTreatment: .followsFederal
            )
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
            )
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
            )
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
            )
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
            )
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
            )
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
            )
        )

        // West Virginia — 2.36% to 5.12% (2026, 5 brackets, reduced)
        configs[.westVirginia] = StateTaxConfig(
            state: .westVirginia,
            taxSystem: .progressive(
                single: [
                    B(threshold: 0, rate: 0.0236),
                    B(threshold: 10_000, rate: 0.0315),
                    B(threshold: 25_000, rate: 0.0354),
                    B(threshold: 40_000, rate: 0.0472),
                    B(threshold: 60_000, rate: 0.0512)
                ],
                married: [
                    B(threshold: 0, rate: 0.0236),
                    B(threshold: 10_000, rate: 0.0315),
                    B(threshold: 25_000, rate: 0.0354),
                    B(threshold: 40_000, rate: 0.0472),
                    B(threshold: 60_000, rate: 0.0512)
                ]
            ),
            retirementExemptions: RetirementIncomeExemptions(
                socialSecurityExempt: false,  // WV taxes SS (phasing out by 2026)
                pensionExemption: .none,
                iraWithdrawalExemption: .none,
                capitalGainsTreatment: .followsFederal
            )
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
            )
        )

        return configs
    }()

    /// Look up configuration for a state. Falls back to California if not found.
    static func config(for state: USState) -> StateTaxConfig {
        configs2026[state] ?? configs2026[.california]!
    }
}
