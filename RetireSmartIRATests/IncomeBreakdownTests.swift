// RetireSmartIRATests/IncomeBreakdownTests.swift
import Testing
@testable import RetireSmartIRA

@Suite("IncomeBreakdown")
struct IncomeBreakdownTests {
    /// Sum of the component (non-subtotal) step amounts up to the named subtotal. Subtotal rows carry
    /// the cumulative value for display, so footing means the components sum to the subtotal.
    private func runningTotalAt(_ b: IncomeBreakdown, label: String) -> Double {
        var sum = 0.0
        for step in b.steps {
            if step.isSubtotal {
                if step.label == label { return sum }
            } else {
                sum += step.amount
            }
        }
        return .nan
    }

    @Test("demo profile (regularRMD == 0): exposes each tab's canonical value and foots")
    func demoChain() {
        let b = IncomeBreakdown(
            allSources: 176_054, regularRMD: 0, inheritedRMD: 11_363,
            taxableFromSources: 140_490, grossWithScenario: 224_499)
        #expect(b.allSources == 176_054)
        #expect(b.totalWithRMDs == 187_417)              // allSources + regularRMD + inheritedRMD
        #expect(b.taxableFromSources == 140_490)
        #expect(b.grossWithScenario == 224_499)
        // Zero regularRMD row is hidden; inherited row shown. Three subtotals, in order.
        #expect(!b.steps.contains { $0.label == "Regular RMD" })
        #expect(b.steps.filter(\.isSubtotal).map(\.label) == [
            "Total income (sources + RMDs)", "Taxable income from sources", "Gross income (with scenario)"])
        // The chain foots: each subtotal equals the running total of preceding steps.
        #expect(abs(runningTotalAt(b, label: "Total income (sources + RMDs)") - 187_417) < 0.01)
        #expect(abs(runningTotalAt(b, label: "Taxable income from sources") - 140_490) < 0.01)
        #expect(abs(runningTotalAt(b, label: "Gross income (with scenario)") - 224_499) < 0.01)
    }

    @Test("general case (nonzero regularRMD, taxable < gross): chain still foots by construction")
    func generalChainFoots() {
        // A household at RMD age with tax-exempt interest + untaxed SS, so taxable < gross.
        let b = IncomeBreakdown(
            allSources: 120_000, regularRMD: 30_000, inheritedRMD: 5_000,
            taxableFromSources: 130_000, grossWithScenario: 180_000)
        #expect(b.totalWithRMDs == 155_000)              // 120k + 30k + 5k
        // Regular RMD row is shown when nonzero.
        #expect(b.steps.contains { $0.label == "Regular RMD" && $0.amount == 30_000 })
        // Residual bridge is negative (removes tax-exempt + untaxed SS): 130k - 155k = -25k.
        #expect(b.steps.contains {
            $0.label == "Less tax-exempt interest and untaxed Social Security" && $0.amount == -25_000 })
        // Scenario residual: 180k - 130k = 50k.
        #expect(b.steps.contains { $0.label == "Scenario withdrawals / conversions" && $0.amount == 50_000 })
        // Every subtotal foots to the running total.
        #expect(abs(runningTotalAt(b, label: "Total income (sources + RMDs)") - 155_000) < 0.01)
        #expect(abs(runningTotalAt(b, label: "Taxable income from sources") - 130_000) < 0.01)
        #expect(abs(runningTotalAt(b, label: "Gross income (with scenario)") - 180_000) < 0.01)
        // No em dash anywhere.
        #expect(b.steps.allSatisfy { !$0.label.contains("\u{2014}") })
    }
}
