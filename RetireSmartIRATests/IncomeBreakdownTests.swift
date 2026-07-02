// RetireSmartIRATests/IncomeBreakdownTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("IncomeBreakdown")
struct IncomeBreakdownTests {
    @Test("composes the labeled chain and exposes each tab's canonical value")
    func chain() {
        let b = IncomeBreakdown(
            allSources: 176_054, inheritedRMD: 11_363, taxExempt: 46_927,
            taxableFromSources: 140_490, scenarioAdditions: 84_009, grossWithScenario: 224_499)
        #expect(b.allSources == 176_054)
        #expect(b.totalWithRMDs == 187_417)              // allSources + inheritedRMD
        #expect(b.taxableFromSources == 140_490)
        #expect(b.grossWithScenario == 224_499)
        // Steps: labeled chain with three subtotals, no em dash.
        #expect(b.steps.count == 7)
        #expect(b.steps.filter(\.isSubtotal).map(\.label) == [
            "Total income (sources + RMDs)", "Taxable income from sources", "Gross income (with scenario)"])
        #expect(b.steps.first?.label == "Income from all sources")
        #expect(b.steps.contains { $0.label == "Less tax-exempt interest" && $0.amount == -46_927 })
        #expect(b.steps.allSatisfy { !$0.label.contains("\u{2014}") })
    }
}
