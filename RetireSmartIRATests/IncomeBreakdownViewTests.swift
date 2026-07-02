import Testing
import SwiftUI
@testable import RetireSmartIRA

@MainActor
@Suite("IncomeBreakdownView construct")
struct IncomeBreakdownViewTests {
    @Test("builds from a breakdown")
    func build() {
        let b = IncomeBreakdown(allSources: 176_054, inheritedRMD: 11_363, taxExempt: 46_927,
            taxableFromSources: 140_490, scenarioAdditions: 84_009, grossWithScenario: 224_499)
        _ = IncomeBreakdownView(breakdown: b).body
        #expect(b.steps.count == 7)
    }
}
