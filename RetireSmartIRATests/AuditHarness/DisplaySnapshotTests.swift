//
//  DisplaySnapshotTests.swift
//  RetireSmartIRATests
//
//  Stage 1, Task 3 of the Multi-Year Display Audit Harness. Verifies that
//  `DisplaySnapshot.capture(profile, provider:)` runs the REAL engine/coordinators
//  (the same ones the SwiftUI Multi-Year surfaces use) and records what each surface
//  renders. This task CAPTURES values only — invariant checks live in Task 4.
//
//  Deterministic: pinned 2026 config, no network, no Date(), no RNG.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite(.serialized)
struct DisplaySnapshotTests {

    private static var provider: TaxYearConfigProvider {
        .fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
    }

    @Test("snapshot captures the comparison columns and frontier points the views render")
    func snapshotMirrorsViews() {
        let p = AuditProfiles.all.first { $0.id.contains("pa62") }!
        let snap = DisplaySnapshot.capture(p, provider: Self.provider)
        #expect(snap.comparison.selected.deferredTaxOnRemainingIRA >= 0)
        #expect(snap.frontier.points.count == 6)
        #expect(!snap.balances.traditional.isEmpty)
    }

    @Test("snapshot captures the cumulative-tax (taximpact) surface")
    func snapshotCapturesTaxImpact() {
        let p = AuditProfiles.all.first { $0.id.contains("pa62") }!
        let snap = DisplaySnapshot.capture(p, provider: Self.provider)
        #expect(!snap.taximpact.cumulativePlan.isEmpty)
        #expect(snap.taximpact.cumulativePlan.count == snap.taximpact.cumulativeDoingNothing.count)
    }

    // Catalog-wide, so OPT-IN via RUN_AUDIT_HARNESS (see AuditGateTests header). Reuses the shared
    // capture pass rather than re-capturing all 27 profiles.
    @Test("every catalog profile captures without crashing and is Codable",
          .enabled(if: AuditCaptureCache.runFullHarness,
                   "set RUN_AUDIT_HARNESS=1 to run the full 27-profile encodability sweep"))
    func snapshotAllProfilesEncodable() throws {
        for (_, snap) in AuditCaptureCache.all {
            #expect(snap.frontier.points.count == 6)
            #expect(!snap.cliffmap.years.isEmpty)
            let data = try JSONEncoder().encode(snap)
            #expect(!data.isEmpty)
        }
    }
}
