//
//  DisplayInvariantsTests.swift
//  RetireSmartIRATests
//
//  Stage 1, Task 4 of the Multi-Year Display Audit Harness. Exercises the property
//  oracle `DisplayInvariants.check` — the six display invariants that must hold on this
//  (I1/I3/B2-fixed) branch: heir reconciliation, frontier Pareto-efficiency, no-phantom
//  conversion, MAGI ≥ AGI, balance non-negativity, and state-conversion exemption.
//
//  Deterministic: pinned 2026 config, no network, no Date(), no RNG.
//

import Testing
import Foundation
@testable import RetireSmartIRA

@MainActor
@Suite(.serialized)
struct DisplayInvariantsTests {

    private static var provider: TaxYearConfigProvider {
        .fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
    }

    @Test("deferred-tax reconciliation invariant holds for a residual-IRA profile")
    func deferredTaxReconciles() {
        let p = AuditProfiles.all.first { $0.id.contains("residual") }!
        let provider = TaxYearConfigProvider.fixed(TaxYearConfig.loadOrFallback(forYear: 2026))
        let snap = DisplaySnapshot.capture(p, provider: provider)
        let violations = DisplayInvariants.check(p, snap, provider: provider)
        // No reconciliation violation: grossEnding - deferred == heirsKeep.
        #expect(!violations.contains { $0.key == "comparison.deferredReconciliation" })
    }

    /// Run the whole catalog once and bucket every violation by invariant key.
    private func catalogViolationsByKey() -> [String: [InvariantViolation]] {
        var byKey: [String: [InvariantViolation]] = [:]
        for p in AuditProfiles.all {
            let snap = DisplaySnapshot.capture(p, provider: Self.provider)
            for v in DisplayInvariants.check(p, snap, provider: Self.provider) {
                byKey[v.key, default: []].append(v)
            }
        }
        return byKey
    }

    // Five of the six invariants (heir reconciliation, no-phantom conversion, MAGI ≥ AGI, balance
    // non-negativity, state-conversion exemption) must hold across the ENTIRE catalog on this
    // (I1/I3/B2-fixed) branch. A regression in any of them fails here immediately.
    @Test("reconciliation / phantom / magi / balances / state invariants are catalog-clean")
    func fiveInvariantsAreClean() {
        let byKey = catalogViolationsByKey()
        for key in ["comparison.deferredReconciliation", "ladder.noPhantom", "magi.geAGI",
                    "balances.nonNegative", "state.paConversionExempt"] {
            let fired = byKey[key] ?? []
            #expect(fired.isEmpty,
                    Comment(rawValue: "\(key) fired:\n" + fired.map(\.detail).joined(separator: "\n")))
        }
    }

    // KNOWN FINDING (see .superpowers/sdd/task-4-report.md): the I3 fix de-dominates only the
    // frontier points that DON'T greedily converge (its `!greedyConverged` perf gate). Three
    // catalog regimes converge greedily yet still return a dominated/backwards heir frontier
    // (higher owner tax AND less to heirs as the heir weight rises). The oracle correctly flags
    // them. This is the exact class of defect the harness exists to surface — pinned here as a
    // baseline so a NEW offender (regression) or a later engine fix (fewer offenders) both trip
    // this test and force a conscious update. Task 5's standing gate must decide policy (fix the
    // engine, or allowlist these) before frontier.nonDominated can be a hard build gate.
    @Test("heir-frontier domination finding is confined to the three known regimes")
    func frontierFindingIsPinned() {
        let byKey = catalogViolationsByKey()
        let offenderIDs = Set((byKey["frontier.nonDominated"] ?? []).compactMap {
            $0.detail.split(separator: ":", maxSplits: 1).first.map(String.init)
        })
        #expect(offenderIDs == ["mfj-b6-ca-verylarge-old",
                                "single-c3-nj-shorthorizon",
                                "mfj-c3-il-shorthorizon"],
                Comment(rawValue: "frontier.nonDominated offender set changed: \(offenderIDs.sorted())"))
    }

    @Test("PA/IL/MS 59½+ converting profiles exercise the state-exemption invariant (non-vacuous)")
    func stateExemptionIsExercised() {
        // At least one PA/IL/MS profile actually converts, so the guarded check is not vacuous.
        let exercised = AuditProfiles.all.contains { p in
            guard ["PA", "IL", "MS"].contains(p.inputs.state.uppercased()),
                  p.inputs.primaryCurrentAge >= 60 else { return false }
            let snap = DisplaySnapshot.capture(p, provider: Self.provider)
            return snap.comparison.selected.peakAnnualRothConversion > 0
        }
        #expect(exercised)
    }
}
