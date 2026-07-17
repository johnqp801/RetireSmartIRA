//
//  AuditGateTests.swift
//  RetireSmartIRATests
//
//  Stage 1, Task 5 (final) of the Multi-Year Display Audit Harness — the STANDING GATE.
//
//  Every (opt-in) run, this test runs the full profile catalog (`AuditProfiles.all`) through the
//  real engine/coordinators (`DisplaySnapshot.capture`) and the deterministic property oracle
//  (`DisplayInvariants.check`), writes one JSON `AuditPacket` per profile for Stage 2's later
//  multi-model reviewer, and enforces the gate policy:
//
//    HARD GATE A — the 5 "clean" invariants (every key except `frontier.nonDominated`) must
//                  NEVER fire on this branch. Any such violation fails the build.
//    HARD GATE B — the set of profileIds producing a `frontier.nonDominated` violation must
//                  equal EXACTLY the known baseline of 3. A NEW offender (regression) OR a
//                  baseline profile that STOPS firing (partial engine fix) both trip the gate,
//                  forcing a conscious, reviewed update. (Revised gate policy 2026-07-16; the
//                  cross-λ Pareto-domination of the heir frontier is a tracked engine backlog
//                  item — see memory `frontier-cross-lambda-domination`.)
//
//  A separate focused test pins each baseline offender's worst-dominated-point magnitude
//  (owner-tax delta and heirs delta vs the λ=0 point) so a silent shrink toward immaterial also
//  trips the gate.
//
//  RUNNING THE FULL GATE: the catalog-wide tests here are EXPENSIVE (~13s/profile, one shared
//  27-profile capture pass) and are OPT-IN — they run only when the test process sees the env var
//  `RUN_AUDIT_HARNESS`. This test bundle is APP-HOSTED (TEST_HOST = RetireSmartIRA.app), and the
//  host is launched via LaunchServices, which does NOT inherit the invoking shell's environment.
//  `xcodebuild` forwards any variable prefixed `TEST_RUNNER_` to the test host WITH THE PREFIX
//  STRIPPED, so set it that way:
//
//      TEST_RUNNER_RUN_AUDIT_HARNESS=1 xcodebuild test -project RetireSmartIRA.xcodeproj \
//          -scheme RetireSmartIRA -destination 'platform=macOS' \
//          -only-testing:RetireSmartIRATests/AuditGateTests
//
//  (Inside the process the variable is plain `RUN_AUDIT_HARNESS`. A plain `RUN_AUDIT_HARNESS=1`
//  on the CLI is silently dropped by the app-hosted launch, so the gate skips — use the prefix.)
//  Without the flag they SKIP, keeping the normal local loop fast. Packets are written to
//  `AUDIT_PACKET_DIR` if set, else `<temporaryDirectory>/audit-packets` (guaranteed writable);
//  the absolute path is printed once per run.
//
//  Deterministic: config pinned via TaxYearConfigProvider.fixed(2026); no Date(), no RNG. The
//  capture pass is shared once via `AuditCaptureCache` and reused for packet-building, invariant-
//  checking, and the magnitude pin.
//

import Foundation
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite(.serialized)
struct AuditGateTests {

    @Test("gate: every catalog profile snapshots, packets are written, and only the known frontier baseline fires",
          .enabled(if: AuditCaptureCache.runFullHarness,
                   "set RUN_AUDIT_HARNESS=1 to run the full 27-profile display gate"))
    func gateRunsAndWritesPackets() throws {
        let provider = AuditCaptureCache.provider()
        var packets: [AuditPacket] = []
        var allViolations: [(profileId: String, v: InvariantViolation)] = []
        for (p, snap) in AuditCaptureCache.all {          // one shared capture pass, reused below
            let v = DisplayInvariants.check(p, snap, provider: provider)
            allViolations += v.map { (p.id, $0) }
            packets.append(AuditPacket(profileId: p.id, inputsSummary: p.summary, snapshot: snap, violations: v))
        }

        // Write packets to a deterministic, guaranteed-writable dir. A write failure must NOT fail
        // the DISPLAY gate (the #expects below assert only on display invariants, not on I/O), so
        // the write is wrapped and any failure recorded as a non-fatal note.
        let dir = AuditCaptureCache.packetOutputDir()
        do {
            try AuditPacketWriter.write(packets, to: dir)
            print("[audit] wrote \(packets.count) packets to \(dir.path)")
        } catch {
            print("[audit] WARNING: packet write to \(dir.path) failed (non-fatal): \(error)")
        }
        #expect(packets.count == AuditProfiles.all.count)

        // HARD GATE A: the 5 clean invariants must never fire on this branch.
        let nonFrontier = allViolations.filter { $0.v.key != "frontier.nonDominated" }
        #expect(nonFrontier.isEmpty, "unexpected non-frontier violations: \(nonFrontier)")

        // HARD GATE B: no profile may carry a frontier.nonDominated violation. The 3 former
        // offenders were fixed 2026-07-17 (see AuditCaptureCache.frontierBaseline), so the offender
        // set must now be EMPTY — any member is a regression. frontierBaseline is retained as the
        // single source of truth (empty today) so a legitimately-reintroduced known offender can be
        // whitelisted there rather than by weakening this assertion.
        let frontierOffenders = Set(allViolations.filter { $0.v.key == "frontier.nonDominated" }.map { $0.profileId })
        #expect(frontierOffenders == AuditCaptureCache.frontierBaseline,
                "frontier offender set drifted from baseline: got \(frontierOffenders), expected \(AuditCaptureCache.frontierBaseline). A non-empty set means the engine regressed and is plotting dominated heir-frontier points; see memory `frontier-cross-lambda-domination`.")
    }

    // The per-offender worst-dominated magnitude pin was removed 2026-07-17: with the frontier now
    // guaranteed non-dominated, there is no offender magnitude to pin, and HARD GATE B (offender set
    // must be empty) fully covers regression detection. Restore it alongside a non-empty
    // frontierBaseline if a known offender is ever legitimately reintroduced.
}
