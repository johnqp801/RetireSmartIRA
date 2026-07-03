import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("Year1EditorView construct", .serialized)
@MainActor
struct Year1EditorViewTests {
    @Test("editor and badge build for each status")
    func build() {
        for status in [OffPlanStatus.onPlan, .nearOptimal, .offPlan, .significantlyOffPlan] {
            let editor = Year1EditorView(
                year1RothConversion: .constant(40_000),
                plannedYear1: 40_000,
                status: status,
                onCommit: {},
                onResetToOptimal: {})
            _ = editor.body
            _ = OffPlanBadge(status: status).body
        }
        // nil status (no results yet) still builds
        _ = Year1EditorView(year1RothConversion: .constant(0), plannedYear1: 0, status: nil,
                            onCommit: {}, onResetToOptimal: {}).body
        #expect(true)
    }
}
