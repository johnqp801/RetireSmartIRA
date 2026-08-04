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
        let primaryYearsUntil = max(0, primaryRmdAge - primaryAge)

        guard spouseEnabled else {
            return RMDHouseholdStatus(
                anyoneRequired: primaryYearsUntil == 0,
                startsFirst: .primary,
                yearsUntilFirst: primaryYearsUntil,
                firstRmdAge: primaryRmdAge,
                showsBothPeople: false)
        }

        let spouseYearsUntil = max(0, spouseRmdAge - spouseAge)

        let startsFirst: Who = spouseYearsUntil < primaryYearsUntil ? .spouse : .primary
        let yearsUntilFirst = min(primaryYearsUntil, spouseYearsUntil)
        let firstRmdAge = startsFirst == .spouse ? spouseRmdAge : primaryRmdAge
        let anyoneRequired = primaryYearsUntil == 0 || spouseYearsUntil == 0
        let showsBothPeople = primaryRmdAge != spouseRmdAge || primaryYearsUntil != spouseYearsUntil

        return RMDHouseholdStatus(
            anyoneRequired: anyoneRequired,
            startsFirst: startsFirst,
            yearsUntilFirst: yearsUntilFirst,
            firstRmdAge: firstRmdAge,
            showsBothPeople: showsBothPeople)
    }
}
