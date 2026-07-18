import Testing
@testable import RetireSmartIRA

@Suite("YearOverrideEditModel")
struct YearOverrideEditModelTests {
    @Test("no existing override → empty fields, and empty edit produces no override")
    func emptyProducesNil() {
        var m = YearOverrideEditModel(year: 2030, existing: nil, projectedBeforeThisYear: 100_000)
        #expect(m.recurringText.isEmpty && m.oneTimeText.isEmpty)
        #expect(m.resultingOverride == nil)     // open + save with no entry → no override
    }

    @Test("existing override pre-populates both fields")
    func prepopulates() {
        let existing = YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: 40_000))
        let m = YearOverrideEditModel(year: 2030, existing: existing, projectedBeforeThisYear: 100_000)
        #expect(m.recurringText == "90000")
        #expect(m.oneTimeText == "40000")
    }

    @Test("entering values builds the override; clearing text yields nil")
    func buildsAndClears() {
        var m = YearOverrideEditModel(year: 2030, existing: nil, projectedBeforeThisYear: 100_000)
        m.oneTimeText = "40000"
        #expect(m.resultingOverride?.livingExpenses?.oneTimeAmount == 40_000)
        #expect(m.resultingOverride?.livingExpenses?.recurringLevel == nil)
        m.oneTimeText = ""
        #expect(m.resultingOverride == nil)
    }

    @Test("clearing one of two set values keeps the other (spec §9)")
    func clearOneKeepsOther() {
        var m = YearOverrideEditModel(year: 2030, existing:
            YearOverride(livingExpenses: FieldOverride(recurringLevel: 90_000, oneTimeAmount: 40_000)),
            projectedBeforeThisYear: 100_000)
        m.oneTimeText = ""   // clear the one-time, keep the recurring
        #expect(m.resultingOverride?.livingExpenses?.recurringLevel == 90_000)
        #expect(m.resultingOverride?.livingExpenses?.oneTimeAmount == nil)
    }

    @Test("non-finite / non-numeric text is ignored, not stored")
    func rejectsGarbage() {
        var m = YearOverrideEditModel(year: 2030, existing: nil, projectedBeforeThisYear: 100_000)
        m.recurringText = "abc"
        #expect(m.resultingOverride == nil)
    }

    @Test("reference label names the year")
    func referenceLabel() {
        let m = YearOverrideEditModel(year: 2030, existing: nil, projectedBeforeThisYear: 100_000)
        #expect(m.referenceLabel.contains("2030"))
    }
}
