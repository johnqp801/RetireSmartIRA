import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("SurvivorStressBanner", .serialized)
@MainActor
struct SurvivorStressBannerTests {
    private func impact(delta: Double) -> TaxImpact {
        TaxImpact(baselineLifetimeTax: 0, scenarioLifetimeTax: delta)
    }

    @Test("shows when survivor penalty exceeds the minimum and not dismissed")
    func shows() {
        #expect(SurvivorStressBanner.shouldShow(widowDelta: impact(delta: 25_000), dismissed: false))
    }

    @Test("hidden when dismissed or below the minimum")
    func hidden() {
        #expect(!SurvivorStressBanner.shouldShow(widowDelta: impact(delta: 25_000), dismissed: true))
        #expect(!SurvivorStressBanner.shouldShow(widowDelta: impact(delta: 100), dismissed: false))
    }

    @Test("body builds")
    func build() {
        let view = SurvivorStressBanner(widowDelta: impact(delta: 25_000), dismissed: .constant(false))
        _ = view.body
        #expect(true)
    }
}
