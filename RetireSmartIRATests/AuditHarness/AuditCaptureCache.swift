//
//  AuditCaptureCache.swift
//  RetireSmartIRATests
//
//  Shared, computed-once capture pass for the Multi-Year Display Audit Harness (Stage 1).
//
//  `DisplaySnapshot.capture` runs the real engine/coordinators and costs ~13s/profile. The catalog
//  (`AuditProfiles.all`) and the pinned 2026 config are deterministic, so a SINGLE capture of all
//  27 profiles is reusable across every harness suite. Before this cache, several tests each
//  re-captured the whole catalog (~120 captures/run, +25-28 min per full `xcodebuild test`).
//
//  This cache captures each profile exactly once — lazily, on first access from any @MainActor
//  harness test — and hands the shared snapshots to every consumer (the gate, the two
//  catalog-wide invariant tests, the all-profiles-encodable test). The heavy catalog-wide tests
//  are ALSO opt-in (`runFullHarness`), so a normal local loop never triggers this cache at all.
//
//  Deterministic: pinned 2026 config, no network, no Date(), no RNG.
//

import Foundation
@testable import RetireSmartIRA

@MainActor
enum AuditCaptureCache {

    /// The pinned tax-year config provider every harness capture uses. Deterministic (2026).
    static func provider() -> TaxYearConfigProvider {
        .fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
    }

    /// All catalog profiles captured exactly once against the pinned provider. Computed on first
    /// access (dispatch-once `static let`), then reused by every catalog-wide harness test. Do NOT
    /// touch this from an always-on smoke test — the first access captures ALL 27 profiles.
    static let all: [(profile: AuditProfile, snapshot: DisplaySnapshot)] = {
        let p = provider()
        return AuditProfiles.all.map { ($0, DisplaySnapshot.capture($0, provider: p)) }
    }()

    /// Look up the shared snapshot for one profile id (nil if the id is not in the catalog).
    static func snapshot(for id: String) -> DisplaySnapshot? {
        all.first { $0.profile.id == id }?.snapshot
    }

    /// CANONICAL frontier baseline — the 3 profiles known to carry a materially dominated
    /// heir-frontier point on this branch. HARD GATE B (offender SET == this), the magnitude-pin
    /// iteration, and the catalog-wide frontier pin all read this ONE source, so there is a single
    /// place to edit if the engine backlog item (`frontier-cross-lambda-domination`) is fixed.
    static let frontierBaseline: Set<String> = [
        "mfj-b6-ca-verylarge-old",
        "single-c3-nj-shorthorizon",
        "mfj-c3-il-shorthorizon",
    ]

    /// True when the heavy full-catalog harness tests should run. They iterate all 27 profiles
    /// (~one shared capture pass, several minutes), so they are OPT-IN via `RUN_AUDIT_HARNESS`.
    /// Off by default keeps the normal local `xcodebuild test` loop fast. `nonisolated` so a
    /// Swift Testing `.enabled(if:)` trait autoclosure can read it off the MainActor.
    nonisolated static var runFullHarness: Bool {
        ProcessInfo.processInfo.environment["RUN_AUDIT_HARNESS"] != nil
    }

    /// Deterministic output directory for Stage-2 audit packets. Resolves from `AUDIT_PACKET_DIR`
    /// if set, else a guaranteed-writable temp dir (`<tmp>/audit-packets`). NEVER CWD-relative —
    /// under `xcodebuild test` the CWD is a sandbox container, not the repo, so a CWD-relative path
    /// silently lands packets where the `.gitignore` entry can't see them and Stage 2 can't find
    /// them.
    static func packetOutputDir() -> URL {
        if let override = ProcessInfo.processInfo.environment["AUDIT_PACKET_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-packets", isDirectory: true)
    }
}
