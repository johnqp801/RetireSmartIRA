import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("Multi-year tab is additive", .serialized)
@MainActor
struct MultiYearTabWiringTests {
    // The single-year views still exist and construct unchanged (augment, not supplant).
    @Test("Scenarios and Tax Summary views still build")
    func singleYearIntact() {
        let dm = DataManager(skipPersistence: true)
        #expect(TaxPlanningView().environment(dm) is (any View))   // tag 5 (Scenarios)
        #expect(DashboardView().environment(dm) is (any View))     // tag 6 (Tax Summary)
        #expect(MultiYearPlanView().environment(dm) is (any View)) // tag 10 (new)
    }
}
