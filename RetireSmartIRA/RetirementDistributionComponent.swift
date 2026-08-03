//
//  RetirementDistributionComponent.swift
//  RetireSmartIRA
//
//  Phase 3b Task 3: a single component of a taxpayer's retirement
//  distribution income, carrying owner, structure and source alongside its
//  amount. See
//  docs/superpowers/specs/2026-08-03-state-tax-phase3b-per-source-design.md
//  section 3.4.
//
//  `TaxCalculationEngine.applyRetirementExemptions` (and its DataManager
//  mirror, `stateTaxBreakdown`) pool these components into ONE figure and
//  hand that pooled figure to the SAME age-gate and exemption logic the
//  `scenarioRetirementDistributions` scalar already uses today. Neither
//  function evaluates any exemption or cap per component. Task 4 introduces
//  per-source rule matching as a partition step that runs BEFORE the cap
//  machinery; see spec section 3.4a. Do not read "iterate components" as
//  "apply a cap per component" anywhere in or after this file -- that is the
//  single largest correctness risk in this phase, and this codebase has
//  already shipped that exact bug once (New York's shared pension-and-IRA
//  cap exists because an earlier version granted $20,000 to pension and
//  another $20,000 to IRA).
//
//  `owner` exists so a LATER phase can correct per-spouse attribution. This
//  phase does not activate that: pooling happens before any age gate or
//  attribution check runs, so nothing downstream ever inspects a
//  component's `owner`. See `Phase3bDistributionComponentTests.componentOwnerDoesNotChangeAttributionInThisPhase`.
//

import Foundation

struct RetirementDistributionComponent: Equatable, Sendable {
    let owner: Owner
    let structure: PlanStructure
    let source: PlanSource
    let amount: Double
}

extension RetirementDistributionComponent {

    /// Set once `resolvePooledAmount` encounters a components/scalar
    /// mismatch in a RELEASE build, where `assertionFailure` below compiles
    /// to a no-op and the resolution silently falls back to the scalar.
    /// Never set while the invariant holds, and never set by this file's
    /// own tests -- see `resolvePooledAmount`'s doc comment for why.
    /// Follows the precedent of `StateTaxDataLoader.legacyFallbackFired`: a
    /// static, observable marker for a failure mode a debug test run
    /// cannot itself trigger without aborting. Not reset once set.
    static private(set) var sumInvariantFallbackFired = false

    /// Whether `components`' amounts agree with `scalar` within one cent
    /// (spec section 3.4): `abs(total - scalar) <= 0.01`. Never exact
    /// `Double` equality, which is unsafe for currency. Pure and
    /// side-effect-free -- this is the exact condition `resolvePooledAmount`
    /// guards its debug trap on, pulled out so a test can exercise the
    /// gating logic directly instead of triggering the trap itself.
    static func sumInvariantHolds(components: [RetirementDistributionComponent], scalar: Double) -> Bool {
        abs(components.reduce(0) { $0 + $1.amount } - scalar) <= 0.01
    }

    /// The value `resolvePooledAmount` resolves to for a components/scalar
    /// pair: their sum when the invariant holds, otherwise `scalar` itself
    /// -- exactly what production falls back to once `assertionFailure` has
    /// compiled away to a no-op in a release build. Deliberately does not
    /// call `assertionFailure` or touch `sumInvariantFallbackFired`, so a
    /// test can exercise this exact assignment without the debug trap
    /// firing or permanently flipping the shared flag for the remainder of
    /// this (parallelized) test run. Mirrors
    /// `StateTaxDataLoader.resolveConfigs`.
    static func fallbackAmount(components: [RetirementDistributionComponent], scalar: Double) -> Double {
        sumInvariantHolds(components: components, scalar: scalar)
            ? components.reduce(0) { $0 + $1.amount }
            : scalar
    }

    /// Pools `components` into the single figure `applyRetirementExemptions`
    /// (engine) and `stateTaxBreakdown` (mirror) both hand to the EXISTING,
    /// unchanged age-gate and exemption logic. `nil` synthesises one
    /// `.unknown`/`.unknown` component from `scalar`, which is today's
    /// behavior exactly -- the invariant is not even evaluated on that path.
    ///
    /// **Debug:** an out-of-tolerance sum traps immediately via
    /// `assertionFailure`, so a caller that sets one side of the invariant
    /// and forgets the other is caught in every test run and in
    /// development, never shipped silently.
    ///
    /// **Release:** `assertionFailure` compiles to a no-op, so execution
    /// falls through to `fallbackAmount`'s scalar -- the same value
    /// production has always computed -- and `sumInvariantFallbackFired` is
    /// set so the drift is observable rather than swallowed. A
    /// `precondition` was rejected deliberately: it would crash a
    /// customer's app over what is, by construction, a programming defect
    /// in a caller, not bad user data.
    static func resolvePooledAmount(components: [RetirementDistributionComponent]?, scalar: Double) -> Double {
        guard let components else { return scalar }
        guard sumInvariantHolds(components: components, scalar: scalar) else {
            let total = components.reduce(0) { $0 + $1.amount }
            assertionFailure(
                "RetirementDistributionComponent amounts sum to \(total), which does not agree with " +
                "the scalar \(scalar) within one cent; falling back to the scalar path."
            )
            sumInvariantFallbackFired = true
            return fallbackAmount(components: components, scalar: scalar)
        }
        return components.reduce(0) { $0 + $1.amount }
    }
}
