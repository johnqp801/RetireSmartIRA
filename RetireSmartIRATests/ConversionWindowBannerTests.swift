import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("ConversionWindowBanner", .serialized)
@MainActor
struct ConversionWindowBannerTests {
    @Test("shows when RMDs are still some years away and not dismissed")
    func shows() {
        #expect(ConversionWindowBanner.shouldShow(yearsBeforeFirstRMD: 5, dismissed: false))
    }

    @Test("hidden when nil, zero, or dismissed")
    func hidden() {
        #expect(!ConversionWindowBanner.shouldShow(yearsBeforeFirstRMD: nil, dismissed: false))
        #expect(!ConversionWindowBanner.shouldShow(yearsBeforeFirstRMD: 0, dismissed: false))
        #expect(!ConversionWindowBanner.shouldShow(yearsBeforeFirstRMD: 5, dismissed: true))
    }

    @Test("body builds")
    func build() {
        let view = ConversionWindowBanner(yearsBeforeFirstRMD: 5, dismissed: .constant(false))
        _ = view.body
        #expect(true)
    }
}
