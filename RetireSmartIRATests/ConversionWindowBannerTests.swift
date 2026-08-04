import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("ConversionWindowBanner", .serialized)
@MainActor
struct ConversionWindowBannerTests {
    private func content(
        title: String = "Conversion opportunity window",
        message: String = "You have about 5 years before required minimum distributions begin.",
        isOpen: Bool = true
    ) -> RMDStatusPresentation.MultiYearBanner {
        RMDStatusPresentation.MultiYearBanner(title: title, message: message, isOpen: isOpen)
    }

    @Test("shows when there is something to say and it is not dismissed")
    func shows() {
        #expect(ConversionWindowBanner.shouldShow(content: content(), dismissed: false))
    }

    @Test("hidden when there is nothing to say, or when dismissed")
    func hidden() {
        #expect(!ConversionWindowBanner.shouldShow(content: nil, dismissed: false))
        #expect(!ConversionWindowBanner.shouldShow(content: content(), dismissed: true))
    }

    @Test("the already-begun case is still dismissible")
    func closedCaseIsDismissible() {
        let begun = content(title: "Required distributions have already begun", isOpen: false)
        #expect(ConversionWindowBanner.shouldShow(content: begun, dismissed: false))
        #expect(!ConversionWindowBanner.shouldShow(content: begun, dismissed: true))
    }

    @Test("body builds in both states")
    func build() {
        _ = ConversionWindowBanner(content: content(), dismissed: .constant(false)).body
        _ = ConversionWindowBanner(content: content(isOpen: false), dismissed: .constant(false)).body
        _ = ConversionWindowBanner(content: nil, dismissed: .constant(false)).body
        #expect(true)
    }
}
