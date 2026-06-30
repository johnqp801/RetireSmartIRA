import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("AdvancedAssumptionsSheet", .serialized)
@MainActor
struct AdvancedAssumptionsSheetTests {
    @Test("every withdrawal rule has a non-empty, em-dash-free label")
    func ruleLabels() {
        for rule in WithdrawalOrderingRule.allCases {
            #expect(!rule.displayName.isEmpty)
            #expect(!rule.displayName.contains("\u{2014}"))
        }
    }

    @Test("sheet builds with and without spouse")
    func build() {
        _ = AdvancedAssumptionsSheet(
            assumptions: .constant(MultiYearAssumptions()),
            spouseEnabled: true, onCommit: {}).body
        _ = AdvancedAssumptionsSheet(
            assumptions: .constant(MultiYearAssumptions()),
            spouseEnabled: false, onCommit: {}).body
        #expect(true)
    }
}
