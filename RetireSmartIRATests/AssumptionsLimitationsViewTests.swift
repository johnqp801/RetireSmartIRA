import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("AssumptionsLimitationsView construct", .serialized)
@MainActor
struct AssumptionsLimitationsViewTests {
    @Test("builds without crashing")
    func build() {
        let view = AssumptionsLimitationsView()
        _ = view.body
        #expect(true)
    }
}
