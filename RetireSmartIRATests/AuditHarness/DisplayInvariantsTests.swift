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

    /// Run every catalog invariant off the SHARED capture pass and bucket violations by key,
    /// tagged with their originating profile id. Reuses `AuditCaptureCache.all` (one 27-profile
    /// capture shared across the whole harness) rather than re-capturing.
    private func catalogViolations() -> [(profileId: String, v: InvariantViolation)] {
        var out: [(profileId: String, v: InvariantViolation)] = []
        for (p, snap) in AuditCaptureCache.all {
            out += DisplayInvariants.check(p, snap, provider: AuditCaptureCache.provider()).map { (p.id, $0) }
        }
        return out
    }

    // Five of the six invariants (heir reconciliation, no-phantom conversion, MAGI ≥ AGI, balance
    // non-negativity, state-conversion exemption) must hold across the ENTIRE catalog on this
    // (I1/I3/B2-fixed) branch. A regression in any of them fails here immediately. Catalog-wide, so
    // OPT-IN via RUN_AUDIT_HARNESS (see AuditGateTests header).
    @Test("reconciliation / phantom / magi / balances / state invariants are catalog-clean",
          .enabled(if: AuditCaptureCache.runFullHarness,
                   "set RUN_AUDIT_HARNESS=1 to run the full 27-profile catalog invariant sweep"))
    func fiveInvariantsAreClean() {
        let all = catalogViolations()
        for key in ["comparison.deferredReconciliation", "ladder.noPhantom", "magi.geAGI",
                    "balances.nonNegative", "state.paConversionExempt"] {
            let fired = all.filter { $0.v.key == key }
            #expect(fired.isEmpty,
                    Comment(rawValue: "\(key) fired:\n" + fired.map { $0.v.detail }.joined(separator: "\n")))
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
    @Test("heir-frontier is non-dominated across the whole catalog (no offenders)",
          .enabled(if: AuditCaptureCache.runFullHarness,
                   "set RUN_AUDIT_HARNESS=1 to run the full 27-profile catalog invariant sweep"))
    func frontierFindingIsPinned() {
        // Structured offender set (profile id per violation), NOT a detail-string parse. Since the
        // 2026-07-17 fixes (Pareto repair + wealth-consistent objective) `frontierBaseline` is empty,
        // so this asserts the whole catalog is domination-free; any offender is a regression.
        let offenderIDs = Set(catalogViolations()
            .filter { $0.v.key == "frontier.nonDominated" }
            .map { $0.profileId })
        #expect(offenderIDs == AuditCaptureCache.frontierBaseline,
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
