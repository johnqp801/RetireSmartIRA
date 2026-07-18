import Testing
@testable import RetireSmartIRA

@Suite("Ladder row override badge")
struct LadderRowOverrideBadgeTests {
    @Test("badge reflects a real override, not an empty/absent entry")
    func badge() {
        let real = YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: nil))
        let empty = YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: nil))
        #expect(LadderRow.hasOverride(year: 2030, overrides: [2030: real]))
        #expect(LadderRow.hasOverride(year: 2030, overrides: [2030: empty]) == false)
        #expect(LadderRow.hasOverride(year: 2031, overrides: [2030: real]) == false)
    }
}
