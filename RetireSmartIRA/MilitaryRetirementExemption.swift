//
//  MilitaryRetirementExemption.swift
//  RetireSmartIRA
//
//  State-by-state exemption table for military retirement pay.
//  Per Tim's beta feedback (V1.8.1 Item #18).
//
//  IMPORTANT: State tax laws change. Users should verify their state's
//  specific rules with a tax professional. This table is a best-effort
//  2026 snapshot drawn from publicly-available state revenue department
//  publications and Military.com / DFAS state tax exemption guides.
//
//  Sources reviewed:
//    - Military.com State Tax Exemptions for Military Retirement Pay (2025/2026)
//    - DFAS State Income Tax Withholding guide
//    - Individual state department of revenue publications
//
//  Notable simplifications / conservative choices:
//    - Oregon offers a small pension subtraction (~$6K) but is treated as
//      fully taxable here — conservative.
//    - Colorado provides a general pension subtraction (not military-specific);
//      modeled as fully taxable — conservative.
//    - New Mexico: partial deduction modeled as 50% taxable (simplified).
//    - Georgia: fully taxable for military retirement specifically (separate
//      from its general retirement-income exclusion), though some interpretations
//      may allow it — treated conservatively as fully taxable.
//    - West Virginia: completed transition to full military retirement exemption
//      as of 2022; listed as fully exempt.
//

import Foundation

// MARK: - Exemption level type

enum MilitaryRetirementExemptionLevel: Equatable {
    /// Military retirement pay is fully excluded from state taxable income.
    case fullyExempt

    /// A portion of military retirement pay is taxable at the state level.
    /// - percentTaxable: Fraction of gross that counts as state taxable income (0.0–1.0).
    /// - ageThreshold: If non-nil, exemption only applies at or above this age.
    case partiallyExempt(percentTaxable: Double, ageThreshold: Int?)

    /// Military retirement pay is treated as ordinary pension income subject to
    /// full state income tax.
    case fullyTaxable

    /// The state levies no broad-based income tax, so military retirement is
    /// effectively untaxed at the state level.
    case noStateIncomeTax
}

// MARK: - Lookup enum

enum MilitaryRetirementExemption {

    /// Returns the exemption level for military retirement pay in the given state
    /// for a beneficiary of the given age.
    ///
    /// - Parameters:
    ///   - stateCode: 2-letter state postal code (case-insensitive).
    ///   - age: Beneficiary's current age (used for age-conditional exemptions like Iowa).
    /// - Returns: The applicable exemption level. Defaults to `.fullyTaxable` for
    ///   unrecognized state codes (conservative — never assume exempt).
    static func exemption(for stateCode: String, age: Int) -> MilitaryRetirementExemptionLevel {
        switch stateCode.uppercased() {

        // MARK: No broad-based state income tax
        // Military retirement is automatically untaxed in these states.
        case "AK",  // Alaska
             "FL",  // Florida
             "NV",  // Nevada
             "SD",  // South Dakota
             "TX",  // Texas
             "WA",  // Washington
             "WY":  // Wyoming
            return .noStateIncomeTax

        case "TN":
            // Tennessee: Hall Tax on investment income was fully repealed 1 Jan 2022.
            // Retirement income has never been subject to TN income tax.
            return .noStateIncomeTax

        case "NH":
            // New Hampshire taxes only interest & dividends (and that tax is being
            // phased out). Retirement / pension income is not taxed.
            return .noStateIncomeTax

        // MARK: Fully exempt
        // Military retirement pay is explicitly excluded from state taxable income.
        case "AL":  // Alabama
            return .fullyExempt
        case "AR":  // Arkansas
            return .fullyExempt
        case "AZ":  // Arizona — full exemption enacted 2021, effective 2022
            return .fullyExempt
        case "CT":  // Connecticut
            return .fullyExempt
        case "HI":  // Hawaii
            return .fullyExempt
        case "IL":  // Illinois
            return .fullyExempt
        case "IN":  // Indiana
            return .fullyExempt
        case "KS":  // Kansas
            return .fullyExempt
        case "LA":  // Louisiana
            return .fullyExempt
        case "MA":  // Massachusetts
            return .fullyExempt
        case "ME":  // Maine
            return .fullyExempt
        case "MI":  // Michigan
            return .fullyExempt
        case "MN":  // Minnesota — full exemption effective 2024
            return .fullyExempt
        case "MO":  // Missouri
            return .fullyExempt
        case "MS":  // Mississippi
            return .fullyExempt
        case "NE":  // Nebraska — full exemption phased in, complete by 2025
            return .fullyExempt
        case "NJ":  // New Jersey
            return .fullyExempt
        case "NC":  // North Carolina — full exemption enacted 2021
            return .fullyExempt
        case "ND":  // North Dakota
            return .fullyExempt
        case "NY":  // New York
            return .fullyExempt
        case "OH":  // Ohio
            return .fullyExempt
        case "OK":  // Oklahoma
            return .fullyExempt
        case "PA":  // Pennsylvania
            return .fullyExempt
        case "SC":  // South Carolina
            return .fullyExempt
        case "UT":  // Utah
            return .fullyExempt
        case "WI":  // Wisconsin
            return .fullyExempt
        case "WV":  // West Virginia — transition completed 2022
            return .fullyExempt

        // MARK: Age-conditional exemptions

        case "IA":
            // Iowa: military retirement fully exempt for taxpayers age 55+.
            // Below 55, treated as ordinary pension income (fully taxable).
            return age >= 55 ? .fullyExempt : .fullyTaxable

        // MARK: Partial exemptions

        case "NM":
            // New Mexico: offers a partial deduction for military retirement pay.
            // Modeled as 50% taxable for V1.8.1 (simplified conservative estimate).
            // FLAGGED: NM rules are income-dependent and may change — verify with
            // NM Taxation & Revenue Department for precise thresholds.
            return .partiallyExempt(percentTaxable: 0.5, ageThreshold: nil)

        // MARK: Fully taxable
        // Military retirement treated as ordinary pension income at state level.
        case "CA":  // California — no special military retirement exclusion
            return .fullyTaxable
        case "CO":
            // Colorado has a general pension subtraction but no military-specific
            // carve-out; modeled as fully taxable (conservative).
            // FLAGGED: CO general pension subtraction ($24K at 65+) may apply
            // — verify with CO DOR for exact treatment.
            return .fullyTaxable
        case "DC":  // District of Columbia
            return .fullyTaxable
        case "DE":  // Delaware — pension exclusion is modest and general, not military-specific
            return .fullyTaxable
        case "GA":
            // Georgia: has a general retirement-income exclusion but military
            // retirement is not explicitly carved out; treated conservatively.
            // FLAGGED: Some sources suggest GA may allow military retirement under
            // its general retirement-income exclusion — verify with GA DOR.
            return .fullyTaxable
        case "ID":  // Idaho
            return .fullyTaxable
        case "KY":  // Kentucky
            return .fullyTaxable
        case "MD":  // Maryland — partial/income-tested exemption not yet modeled; conservative
            // FLAGGED: MD offers a military retirement subtraction (~$15K) for
            // retirees age 55+. Task 6.3 wiring may need to revisit MD.
            return .fullyTaxable
        case "MT":  // Montana
            return .fullyTaxable
        case "OR":
            // Oregon: general pension subtraction (~$6K) applies but is not
            // military-specific; modeled as fully taxable (conservative).
            return .fullyTaxable
        case "RI":  // Rhode Island
            return .fullyTaxable
        case "VA":
            // Virginia: recently enacted a military retirement subtraction
            // (phasing to full exemption by 2026). Conservative: still labeled
            // fully taxable for V1.8.1; revisit in Task 6.3 if needed.
            // FLAGGED: VA full exemption effective 2026 — may need update.
            return .fullyTaxable
        case "VT":  // Vermont
            return .fullyTaxable

        // MARK: Default — conservative fallback
        // Unknown/unrecognized state codes default to fully taxable.
        // Never assume exempt for an unrecognized state.
        default:
            return .fullyTaxable
        }
    }

    /// Returns the dollar amount of military retirement income that is taxable
    /// for state purposes, given gross amount, state code, and beneficiary age.
    ///
    /// - Parameters:
    ///   - gross: Total annual military retirement pay (pre-tax).
    ///   - stateCode: 2-letter state postal code (case-insensitive).
    ///   - age: Beneficiary's current age.
    /// - Returns: The portion of `gross` subject to state income tax.
    static func stateTaxableAmount(gross: Double, stateCode: String, age: Int) -> Double {
        switch exemption(for: stateCode, age: age) {
        case .fullyExempt, .noStateIncomeTax:
            return 0

        case .fullyTaxable:
            return gross

        case .partiallyExempt(let percentTaxable, let ageThreshold):
            if let threshold = ageThreshold, age < threshold {
                // Below the age threshold — partial exemption not yet available
                return gross
            }
            return gross * percentTaxable
        }
    }
}
