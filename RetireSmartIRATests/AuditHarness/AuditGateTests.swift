//
//  AuditGateTests.swift
//  RetireSmartIRATests
//
//  Stage 1, Task 5 (final) of the Multi-Year Display Audit Harness — the STANDING GATE.
//
//  Every build, this test runs the full profile catalog (`AuditProfiles.all`) through the real
//  engine/coordinators (`DisplaySnapshot.capture`) and the deterministic property oracle
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
//  Deterministic: config pinned via TaxYearConfigProvider.fixed(2026); no Date(), no RNG. The
//  capture pass is expensive (~13s/profile) so the gate captures each profile exactly ONCE and
//  reuses that snapshot for both packet-building and invariant-checking.
//

import Foundation
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite(.serialized)
struct AuditGateTests {

    /// The 3 profiles known to carry a materially dominated heir-frontier point on this branch.
    /// Pinned SET (not `isEmpty`): a 4th offender OR one of these dropping out both fail HARD GATE B.
    static let frontierBaseline: Set<String> = [
        "mfj-b6-ca-verylarge-old",
        "single-c3-nj-shorthorizon",
        "mfj-c3-il-shorthorizon",
    ]

    private static func provider() -> TaxYearConfigProvider {
        .fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
    }

    @Test("gate: every catalog profile snapshots, packets are written, and only the known frontier baseline fires")
    func gateRunsAndWritesPackets() throws {
        let provider = Self.provider()
        var packets: [AuditPacket] = []
        var allViolations: [(profileId: String, v: InvariantViolation)] = []
        for p in AuditProfiles.all {
            let snap = DisplaySnapshot.capture(p, provider: provider)     // one capture, reused below
            let v = DisplayInvariants.check(p, snap, provider: provider)
            allViolations += v.map { (p.id, $0) }
            packets.append(AuditPacket(profileId: p.id, inputsSummary: p.summary, snapshot: snap, violations: v))
        }
        let dir = URL(fileURLWithPath: "RetireSmartIRATests/AuditHarness/packets", isDirectory: true)
        try AuditPacketWriter.write(packets, to: dir)
        #expect(packets.count == AuditProfiles.all.count)

        // HARD GATE A: the 5 clean invariants must never fire on this branch.
        let nonFrontier = allViolations.filter { $0.v.key != "frontier.nonDominated" }
        #expect(nonFrontier.isEmpty, "unexpected non-frontier violations: \(nonFrontier)")

        // HARD GATE B: frontier.nonDominated offender SET must equal exactly the known baseline.
        let frontierOffenders = Set(allViolations.filter { $0.v.key == "frontier.nonDominated" }.map { $0.profileId })
        #expect(frontierOffenders == Self.frontierBaseline,
                "frontier offender set drifted from baseline: got \(frontierOffenders)")
    }

    // MARK: - Magnitude pin

    /// Reference magnitude of the worst dominated point (vs the λ=0 point) for each baseline
    /// offender, in today's dollars: (ownerTaxDelta, heirsDelta). Derived from the captured
    /// frontier exactly as HARD GATE B / the oracle's dominance check does (no engine re-run).
    /// A silent shrink toward immaterial trips the ±10% band.
    private static let referenceMagnitudes: [String: (ownerTaxDelta: Double, heirsDelta: Double)] = [
        "mfj-b6-ca-verylarge-old": (ownerTaxDelta: 14_295, heirsDelta: -191_285),
        "single-c3-nj-shorthorizon": (ownerTaxDelta: 33_408, heirsDelta: -33_328),
        "mfj-c3-il-shorthorizon": (ownerTaxDelta: 141_358, heirsDelta: -59_683),
    ]

    /// Worst dominated point for a captured frontier, measured against the λ=0 (weight 0) point.
    /// "Dominated" uses the SAME ε-cushioned Pareto rule as `DisplayInvariants.frontierNonDominated`.
    /// Returns the (ownerTaxDelta, heirsDelta) of the dominated point whose owner-tax delta from the
    /// λ=0 point is the largest (the "worst" one the finding narrates). nil if no dominated point.
    private static func worstDominatedDelta(_ snap: DisplaySnapshot) -> (ownerTaxDelta: Double, heirsDelta: Double)? {
        let eps = DisplayInvariants.epsilon
        let pts = snap.frontier.points
        guard let lambda0 = pts.first(where: { $0.weight == 0.0 }) else { return nil }

        func isDominated(_ pi: FrontierPointSnapshot) -> Bool {
            for pj in pts where pj.weight != pi.weight {
                let jNoWorseTax = pj.ownerLifetimeTaxToday <= pi.ownerLifetimeTaxToday + eps
                let jNoWorseHeirs = pj.heirsKeepToday >= pi.heirsKeepToday - eps
                let jStrictlyBetter = pj.ownerLifetimeTaxToday < pi.ownerLifetimeTaxToday - eps
                    || pj.heirsKeepToday > pi.heirsKeepToday + eps
                if jNoWorseTax && jNoWorseHeirs && jStrictlyBetter { return true }
            }
            return false
        }

        let dominated = pts.filter(isDominated)
        guard let worst = dominated.max(by: {
            ($0.ownerLifetimeTaxToday - lambda0.ownerLifetimeTaxToday)
                < ($1.ownerLifetimeTaxToday - lambda0.ownerLifetimeTaxToday)
        }) else { return nil }

        return (ownerTaxDelta: worst.ownerLifetimeTaxToday - lambda0.ownerLifetimeTaxToday,
                heirsDelta: worst.heirsKeepToday - lambda0.heirsKeepToday)
    }

    @Test("gate: each baseline frontier offender's worst-dominated magnitude stays within tolerance")
    func baselineOffenderMagnitudesArePinned() throws {
        let provider = Self.provider()
        let tolerance = 0.10   // ±10% band per the revised gate policy
        for id in Self.frontierBaseline.sorted() {
            guard let profile = AuditProfiles.all.first(where: { $0.id == id }) else {
                Issue.record("baseline profile \(id) missing from catalog")
                continue
            }
            let snap = DisplaySnapshot.capture(profile, provider: provider)
            guard let delta = Self.worstDominatedDelta(snap) else {
                Issue.record("\(id): expected a dominated frontier point but found none")
                continue
            }
            guard let ref = Self.referenceMagnitudes[id] else {
                Issue.record("\(id): no reference magnitude pinned")
                continue
            }
            let taxOK = abs(delta.ownerTaxDelta - ref.ownerTaxDelta) <= abs(ref.ownerTaxDelta) * tolerance
            let heirsOK = abs(delta.heirsDelta - ref.heirsDelta) <= abs(ref.heirsDelta) * tolerance
            #expect(taxOK,
                    "\(id): owner-tax delta \(delta.ownerTaxDelta) drifted from reference \(ref.ownerTaxDelta) (±\(tolerance*100)%)")
            #expect(heirsOK,
                    "\(id): heirs delta \(delta.heirsDelta) drifted from reference \(ref.heirsDelta) (±\(tolerance*100)%)")
        }
    }
}
