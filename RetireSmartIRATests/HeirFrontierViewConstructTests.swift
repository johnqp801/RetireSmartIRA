import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("HeirFrontierView constructs", .serialized)
@MainActor
struct HeirFrontierViewConstructTests {
    @Test("builds from a frontier result")
    func builds() {
        let p = FrontierPoint(weight: 0, ownerLifetimeTaxToday: 1, heirAfterTaxInheritanceToday: 1,
            heirTaxToday: 0, pvDiscountFactor: 1, recommendedPath: [])
        let result = HeirFrontierResult(points: [p])
        var weight = 0.0
        let view = HeirFrontierView(result: result,
            selectedWeight: Binding(get: { weight }, set: { weight = $0 }),
            units: .todaysDollars)
        _ = view.body
        #expect(true)
    }
}
