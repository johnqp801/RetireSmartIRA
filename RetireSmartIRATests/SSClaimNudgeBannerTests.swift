import Testing
import SwiftUI
@testable import RetireSmartIRA

@Suite("SSClaimNudgeBanner", .serialized)
@MainActor
struct SSClaimNudgeBannerTests {
    private func flag(current: Int, suggested: Int) -> ClaimAgeFlag {
        ClaimAgeFlag(spouse: .primary, currentClaimAge: current,
                     suggestedClaimAge: suggested, estimatedLifetimeTaxDelta: -30_000)
    }

    @Test("shows when a different claim age is suggested and not dismissed")
    func shows() {
        #expect(SSClaimNudgeBanner.shouldShow(nudge: flag(current: 65, suggested: 70), dismissed: false))
    }

    @Test("hidden when nil, dismissed, or the suggested age equals current")
    func hidden() {
        #expect(!SSClaimNudgeBanner.shouldShow(nudge: nil, dismissed: false))
        #expect(!SSClaimNudgeBanner.shouldShow(nudge: flag(current: 70, suggested: 70), dismissed: false))
        #expect(!SSClaimNudgeBanner.shouldShow(nudge: flag(current: 65, suggested: 70), dismissed: true))
    }

    @Test("message names the person and the savings")
    func message() {
        let msg = SSClaimNudgeBanner.message(flag(current: 65, suggested: 70))
        #expect(msg.contains("you"))
        #expect(msg.contains("70"))
        #expect(!msg.contains("\u{2014}"))
    }
}
