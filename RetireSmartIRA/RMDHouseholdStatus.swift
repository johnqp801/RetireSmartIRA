import Foundation

/// The household-level RMD status: whether either person's Required Minimum
/// Distribution has started, and if not, who reaches it first.
///
/// This exists as a standalone pure type, rather than logic embedded in a
/// SwiftUI view, so both the "spouse drives the headline" branch and the
/// "primary drives the headline" branch are independently testable.
struct RMDHouseholdStatus: Equatable {
    enum Who: Equatable { case primary, spouse }

    /// True when EITHER person is at or past their RMD age.
    let anyoneRequired: Bool
    /// Whichever person reaches RMD age sooner. Ties resolve to `.primary`.
    let startsFirst: Who
    /// Years until the FIRST of the two starts. Zero once anyone is required.
    let yearsUntilFirst: Int
    /// The RMD age of whoever starts first.
    let firstRmdAge: Int
    /// True when the two people have different RMD ages or different timing,
    /// which is when the card must show both rather than one.
    let showsBothPeople: Bool

    static func resolve(
        primaryAge: Int, primaryRmdAge: Int,
        spouseEnabled: Bool, spouseAge: Int, spouseRmdAge: Int
    ) -> RMDHouseholdStatus {
        // Signed years-past-RMD-age: negative means still waiting, zero means
        // starting this year, positive means required that many years already.
        // A single signed comparison is correct whether both are still
        // waiting, both are already required, or one of each, so there is no
        // clamp to lose the "how overdue" information the old max(0, ...)
        // countdown discarded.
        let primarySignedYears = primaryAge - primaryRmdAge

        guard spouseEnabled else {
            return RMDHouseholdStatus(
                anyoneRequired: primarySignedYears >= 0,
                startsFirst: .primary,
                yearsUntilFirst: max(0, -primarySignedYears),
                firstRmdAge: primaryRmdAge,
                showsBothPeople: false)
        }

        let spouseSignedYears = spouseAge - spouseRmdAge

        // Whoever has the larger signed value started first; ties favor primary.
        let startsFirst: Who = spouseSignedYears > primarySignedYears ? .spouse : .primary
        let largestSignedYears = max(primarySignedYears, spouseSignedYears)
        let yearsUntilFirst = max(0, -largestSignedYears)
        let firstRmdAge = startsFirst == .spouse ? spouseRmdAge : primaryRmdAge
        let anyoneRequired = primarySignedYears >= 0 || spouseSignedYears >= 0
        let showsBothPeople = primaryRmdAge != spouseRmdAge || primarySignedYears != spouseSignedYears

        return RMDHouseholdStatus(
            anyoneRequired: anyoneRequired,
            startsFirst: startsFirst,
            yearsUntilFirst: yearsUntilFirst,
            firstRmdAge: firstRmdAge,
            showsBothPeople: showsBothPeople)
    }
}
