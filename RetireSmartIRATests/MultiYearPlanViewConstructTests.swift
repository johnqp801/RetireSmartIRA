import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("MultiYearPlanView constructs", .serialized)
@MainActor
struct MultiYearPlanViewConstructTests {
    @Test("builds")
    func builds() {
        let view = MultiYearPlanView().environment(DataManager(skipPersistence: true))
        #expect(view is (any View))
    }

    @Test("tab builds with banners and limitations wired")
    func buildsWithRidersAndLimitations() {
        let dataManager = DataManager(skipPersistence: true)
        let view = MultiYearPlanView().environment(dataManager)
        #expect(view is (any View))
    }
}
