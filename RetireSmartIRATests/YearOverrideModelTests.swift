// RetireSmartIRATests/YearOverrideModelTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("YearOverride model")
struct YearOverrideModelTests {
    @Test("empty FieldOverride prunes to nil")
    func fieldEmptyPrunes() {
        #expect(FieldOverride(recurringLevel: nil, oneTimeAmount: nil).isEmpty)
        #expect(FieldOverride(recurringLevel: nil, oneTimeAmount: nil).pruned == nil)
        #expect(FieldOverride(recurringLevel: 0, oneTimeAmount: nil).isEmpty == false)   // 0 is a real value
        #expect(FieldOverride(recurringLevel: nil, oneTimeAmount: 100).pruned != nil)
    }

    @Test("YearOverride with only an empty field prunes to nil")
    func yearPrunes() {
        let y = YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: nil))
        #expect(y.pruned == nil)
        let y2 = YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: nil))
        #expect(y2.pruned != nil)
    }

    @Test("dictionary pruning drops empty entries, keeps real ones")
    func dictPrunes() {
        let d: [Int: YearOverride] = [
            2028: YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: nil)),
            2030: YearOverride(livingExpenses: FieldOverride(recurringLevel: nil, oneTimeAmount: nil)),
        ]
        let pruned = d.pruned()
        #expect(pruned.keys.sorted() == [2028])
    }
}
