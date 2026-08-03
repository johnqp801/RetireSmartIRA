import Foundation

/// A state's treatment of Roth conversion income in the conversion year.
///
/// Before Phase 3a this was a `switch state` over Pennsylvania, Illinois and
/// Mississippi inside `TaxCalculationEngine.applyRetirementExemptions`. Iowa
/// exempts conversion income by name for anyone 55 or older (HF 2317), which a
/// `switch` with no age concept could not express, and which matters more than
/// any other single defect in the 2026-08-02 audit: this app exists to
/// optimize Roth conversions, and for an Iowa user it currently invents state
/// tax on that exact transaction.
///
/// nil, the default, means conversion income is fully taxable. That is the
/// correct treatment for 48 jurisdictions.
struct RothConversionExemption: Codable, Equatable, Sendable {
    /// Minimum age for the exemption. 0 means no age gate, which is Ans 274's
    /// position for Pennsylvania and the practitioner reading for Illinois and
    /// Mississippi: none of the three conditions the exemption on retirement
    /// age. Iowa will be 55.
    let minAge: Int

    /// Pennsylvania DOR Ans 274 holds the exemption applies only where the full
    /// pre-tax balance reaches the Roth, so any amount withheld for federal tax
    /// is a taxable distribution. Illinois and Mississippi publish no
    /// equivalent condition, so they exempt the gross.
    let withheldPortionRemainsTaxable: Bool
}
