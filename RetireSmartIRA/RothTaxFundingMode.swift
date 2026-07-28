//
//  RothTaxFundingMode.swift
//  RetireSmartIRA
//
//  V2.3: how the multi-year plan funds the year's tax bill.
//
//  These three cases are USER-FACING PRESETS, not a complete domain model.
//  Withholding and shortfall-funding are two orthogonal concepts; each preset
//  resolves into one (remittance, shortfall policy) pair:
//
//    Preset                  | Remittance          | Shortfall funding
//    ------------------------|---------------------|---------------------------
//    .withheldFromConversion | custodian withholds | taxable, then grossed-up IRA
//    .fundedFromAccounts     | paid separately     | taxable, then grossed-up IRA
//    .paidFromOutsideMoney   | paid separately     | untracked external source
//
//  Withholding is a PAYMENT toward a liability, never a definition of it. The
//  elected rate is FEDERAL ONLY (matching single-year's
//  rothConversionFederalWithholdingRate), so state tax, IRMAA, NIIT, and ACA
//  impact always fund through the shortfall policy.
//
//  See docs/superpowers/specs/2026-07-27-v2.3-tax-payment-source-design.md
//

import Foundation

enum RothTaxFundingMode: String, Codable, Sendable, CaseIterable {
    /// Custodian withholds the elected federal rate from the gross distribution.
    /// Any remaining liability cascades: taxable assets first, then a grossed-up
    /// traditional withdrawal.
    case withheldFromConversion

    /// Tax is remitted separately. Funding cascades: taxable assets first, then a
    /// grossed-up traditional withdrawal. This is the pre-V2.3 default behavior
    /// (formerly `TaxPaymentSource.taxableThenGrossUp`).
    case fundedFromAccounts

    /// Tax is remitted separately from funds the plan does not track. No balance
    /// is modeled (formerly `TaxPaymentSource.external`).
    case paidFromOutsideMoney

    /// True when the custodian withholds federal tax from the distribution itself.
    var usesCustodialWithholding: Bool {
        self == .withheldFromConversion
    }

    /// True when a remaining balance is funded from tracked accounts
    /// (taxable first, then a grossed-up traditional withdrawal).
    var fundsShortfallFromAccounts: Bool {
        switch self {
        case .withheldFromConversion, .fundedFromAccounts: return true
        case .paidFromOutsideMoney: return false
        }
    }

    /// True when IRA dollars can end up paying the tax bill, by either mechanism.
    /// Drives both the Ed Slott disclosure and the under-59.5 warning.
    var canTouchIRADollarsForTax: Bool {
        usesCustodialWithholding || fundsShortfallFromAccounts
    }

    var displayName: String {
        switch self {
        case .withheldFromConversion: return "Withhold from conversion"
        case .fundedFromAccounts:     return "Pay from my accounts"
        case .paidFromOutsideMoney:   return "Pay from outside money"
        }
    }

    /// States the full funding behavior. A friendly label that hides the cascade is
    /// the main usability risk in this feature, so every preset spells the order out.
    var fundingSubtitle: String {
        switch self {
        case .withheldFromConversion:
            return "Withhold at the selected federal rate; use taxable assets, then additional IRA withdrawals, for any remaining tax."
        case .fundedFromAccounts:
            return "Taxable assets first, then IRA if needed."
        case .paidFromOutsideMoney:
            return "Paid from savings outside this plan. Those funds are not tracked as a balance."
        }
    }
}

/// Federal withholding rates a custodian will accept, corresponding to 2026 bracket
/// edges. Owned here (domain), not by a SwiftUI view, so single-year and multi-year
/// cannot drift apart.
enum FederalWithholdingRates {
    static let options: [(label: String, rate: Double)] = [
        ("10%", 0.10), ("12%", 0.12), ("22%", 0.22), ("24%", 0.24),
        ("32%", 0.32), ("35%", 0.35), ("37%", 0.37)
    ]

    static let defaultRate: Double = 0.24
}
