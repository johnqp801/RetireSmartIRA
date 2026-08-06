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

    /// Phase 5b Task 9: whether this component is a SURVIVOR benefit. Same
    /// three-valued meaning as `IncomeSource.isSurvivorBenefit`: `nil` means
    /// the question was never asked, not "no".
    ///
    /// `var` with a default rather than `let` with a default, because Swift
    /// excludes a `let` with an initial value from the synthesized memberwise
    /// initializer entirely, which would make it impossible to construct a
    /// component that carries the fact. That is Task 1's Critical finding in
    /// its non-Codable form.
    ///
    /// NOTHING IN PRODUCTION CONSTRUCTS THIS TYPE TODAY -- `distributionComponents`
    /// is `nil` at every production call site of
    /// `TaxCalculationEngine.calculateStateTax`, verified by grep for
    /// `RetirementDistributionComponent(` under `RetireSmartIRA/`. The field
    /// exists so the engine's third per-source matching site passes a real
    /// value rather than a hardcoded `nil`, and so a later task that starts
    /// building components from accounts has a seam to fill instead of a
    /// silent hole.
    var isSurvivorBenefit: Bool? = nil
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

    /// The one-cent tolerance spec section 3.4 sets for the sum invariant,
    /// named so a test can assert its value directly rather than only
    /// proving it lies somewhere inside an interval bracketed by two probe
    /// points (which is all `sumInvariantBoundary` proved before this
    /// constant existed: that the true tolerance sits in `[0.005, 0.02)`,
    /// not that it is exactly `0.01`).
    static let sumInvariantTolerance: Double = 0.01

    /// Whether `components`' amounts agree with `scalar` within
    /// `sumInvariantTolerance` (spec section 3.4). Never exact `Double`
    /// equality, which is unsafe for currency. Pure and side-effect-free --
    /// this is the exact condition `resolvePooledAmount` guards its debug
    /// trap on, pulled out so a test can exercise the gating logic directly
    /// instead of triggering the trap itself.
    static func sumInvariantHolds(components: [RetirementDistributionComponent], scalar: Double) -> Bool {
        abs(components.reduce(0) { $0 + $1.amount } - scalar) <= sumInvariantTolerance
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
    /// unchanged age-gate and exemption logic. `nil` short-circuits straight
    /// to `scalar` below -- it does NOT construct a
    /// `.unknown`/`.unknown` component and pool a one-element array. The two
    /// are numerically identical (a single `.unknown` component would sum to
    /// the same value the scalar already holds), which is why callers may
    /// describe the nil path as "behaving like" a synthesized `.unknown`
    /// component, but no such component object is ever created, and the sum
    /// invariant is not even evaluated on this path.
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
