import Testing
import SwiftUI
@testable import RetireSmartIRA

@MainActor
@Suite("IncomeBreakdownView construct")
struct IncomeBreakdownViewTests {
    @Test("builds from a breakdown")
    func build() {
        let b = IncomeBreakdown(allSources: 120_000, regularRMD: 30_000, inheritedRMD: 5_000,
            taxableFromSources: 130_000, grossWithScenario: 180_000)
        _ = IncomeBreakdownView(breakdown: b).body
        // All RMD rows shown (both nonzero): 8 steps.
        #expect(b.steps.count == 8)
    }
}
