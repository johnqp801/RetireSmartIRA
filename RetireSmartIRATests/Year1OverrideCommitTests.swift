import Testing
@testable import RetireSmartIRA

@Suite("Year1OverrideCommit")
struct Year1OverrideCommitTests {
    /// The regression this type exists for. When the user has an explicit Year-1 override, the plan
    /// pins Year 1 to it, so `plannedYear1` equals the override. The engine settling then syncs the
    /// field's text to that same amount, which re-enters the commit path. Treating "field equals the
    /// plan" as "clear the override" there silently zeroes the user's conversion.
    @Test("an active override survives the plan syncing the field back to its own amount")
    func activeOverrideSurvivesProgrammaticSync() {
        let target = Year1OverrideCommit.target(
            parsed: 200_000, plannedYear1: 200_000, currentOverride: 200_000)
        #expect(target == 200_000)
    }

    @Test("with no override, the field matching the plan stays as following the plan")
    func followingPlanStaysCleared() {
        let target = Year1OverrideCommit.target(
            parsed: 350_000, plannedYear1: 350_000, currentOverride: 0)
        #expect(target == 0)
    }

    @Test("typing an amount that differs from the plan sets an override")
    func typedAmountBecomesOverride() {
        let target = Year1OverrideCommit.target(
            parsed: 100_000, plannedYear1: 350_000, currentOverride: 0)
        #expect(target == 100_000)
    }

    @Test("clearing the field clears an active override")
    func emptyingFieldClearsOverride() {
        let target = Year1OverrideCommit.target(
            parsed: 0, plannedYear1: 200_000, currentOverride: 200_000)
        #expect(target == 0)
    }

    @Test("changing an active override to a new amount keeps the new amount")
    func overrideCanBeChanged() {
        let target = Year1OverrideCommit.target(
            parsed: 250_000, plannedYear1: 200_000, currentOverride: 200_000)
        #expect(target == 250_000)
    }
}
