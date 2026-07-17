//
//  DisplayInvariants.swift
//  RetireSmartIRATests
//
//  Stage 1, Task 4 of the Multi-Year Display Audit Harness — the deterministic property
//  oracle. `DisplayInvariants.check(profile, snapshot, provider:)` asserts the display
//  invariants defined in `docs/superpowers/audit/multi-year-display-spec.md` (§8 cross-surface
//  reconciliation + the per-key "Invariants" columns of §1–§6). It returns a violation ONLY
//  when an invariant is BROKEN; a satisfied invariant contributes nothing.
//
//  The oracle asserts relationships on the ALREADY-CAPTURED snapshot output. It runs the engine
//  a second time for NO invariant (the `state.paConversionExempt` check reads the differential
//  already captured in `comparison.consequenceDelta.state`, which is selected-path minus
//  no-conversion-path state tax summed over years — exactly the conversion isolate the spec
//  describes, so no second engine run is needed).
//
//  ε = 1.0 for every check (spec's hard-invariant tolerance; the display-materiality bar of
//  $1,000 is deliberately looser and NOT used here).
//
//  Deterministic: no Date(), no RNG.
//

import Foundation
@testable import RetireSmartIRA

/// A single broken display invariant. `key` is the exact dotted invariant name (Task 5's
/// standing gate asserts on these strings); `detail` names the profile/year/values so a
/// failure is debuggable from the packet alone.
struct InvariantViolation: Codable, Equatable {
    let key: String
    let detail: String
}

enum DisplayInvariants {

    /// Hard-invariant tolerance (dollars). Absorbs floating-point noise only — far tighter than
    /// the $1,000 display-materiality threshold, so a real divergence still fires.
    static let epsilon = 1.0

    /// Check every display invariant for one captured profile snapshot. Returns all violations
    /// (empty ⇒ every invariant holds).
    static func check(_ profile: AuditProfile,
                      _ snap: DisplaySnapshot,
                      provider: TaxYearConfigProvider) -> [InvariantViolation] {
        var out: [InvariantViolation] = []
        out += deferredReconciliation(profile, snap)
        out += frontierNonDominated(profile, snap)
        out += ladderNoPhantom(profile, snap)
        out += magiGeAGI(profile, snap)
        out += balancesNonNegative(profile, snap)
        out += statePAConversionExempt(profile, snap)
        return out
    }

    // MARK: - comparison.deferredReconciliation  (spec §1, §8-1)
    //
    // `endingRoth + endingTaxable + endingTraditional − deferredTaxOnRemainingIRA == heirsKeep`
    // for each comparison column, in the same nominal basis. This is `HeirValue.afterTaxToHeirs`'s
    // own definition, so it must hold by construction; a violation means two call sites diverged.

    private static func deferredReconciliation(_ p: AuditProfile,
                                               _ s: DisplaySnapshot) -> [InvariantViolation] {
        let columns: [(String, ComparisonColumnSnapshot)] = [
            ("selected", s.comparison.selected),
            ("recommended", s.comparison.recommended),
            ("noAdditionalConversions", s.comparison.noAdditionalConversions),
        ]
        var out: [InvariantViolation] = []
        for (name, c) in columns {
            let gross = c.endingRoth + c.endingTaxable + c.endingTraditional
            let reconciled = gross - c.deferredTaxOnRemainingIRA
            let residual = abs(reconciled - c.heirsKeep)
            if residual >= epsilon {
                out.append(InvariantViolation(
                    key: "comparison.deferredReconciliation",
                    detail: "\(p.id) [\(name)]: endingRoth(\(c.endingRoth)) + endingTaxable(\(c.endingTaxable)) "
                        + "+ endingTraditional(\(c.endingTraditional)) − deferred(\(c.deferredTaxOnRemainingIRA)) "
                        + "= \(reconciled), but heirsKeep = \(c.heirsKeep); residual \(residual) ≥ ε(\(epsilon))"))
            }
        }
        return out
    }

    // MARK: - frontier.nonDominated  (spec §2, §8-2)
    //
    // Owner wants LOWER ownerLifetimeTax; heirs want HIGHER heirsKeep. Two conditions:
    //  (a) Pareto: no plotted point is dominated on BOTH axes by another (weakly better on both,
    //      strictly better on at least one — all with an ε cushion so near-ties never false-fire).
    //  (b) Monotone: heirsKeep is non-decreasing as the heir weight rises (within ε).
    // This is the I3 fix's target (de-dominate at every λ, not only λ=0).

    private static func frontierNonDominated(_ p: AuditProfile,
                                             _ s: DisplaySnapshot) -> [InvariantViolation] {
        var out: [InvariantViolation] = []
        let pts = s.frontier.points

        for i in pts.indices {
            let pi = pts[i]
            for j in pts.indices where j != i {
                let pj = pts[j]
                let jNoWorseTax = pj.ownerLifetimeTaxToday <= pi.ownerLifetimeTaxToday + epsilon
                let jNoWorseHeirs = pj.heirsKeepToday >= pi.heirsKeepToday - epsilon
                let jStrictlyBetter = pj.ownerLifetimeTaxToday < pi.ownerLifetimeTaxToday - epsilon
                    || pj.heirsKeepToday > pi.heirsKeepToday + epsilon
                if jNoWorseTax && jNoWorseHeirs && jStrictlyBetter {
                    out.append(InvariantViolation(
                        key: "frontier.nonDominated",
                        detail: "\(p.id): weight \(pi.weight) (ownerTax \(pi.ownerLifetimeTaxToday), "
                            + "heirsKeep \(pi.heirsKeepToday)) is dominated by weight \(pj.weight) "
                            + "(ownerTax \(pj.ownerLifetimeTaxToday), heirsKeep \(pj.heirsKeepToday))"))
                    break   // one dominator is enough to condemn this point
                }
            }
        }

        let sorted = pts.sorted { $0.weight < $1.weight }
        if sorted.count >= 2 {
            for k in 1..<sorted.count where sorted[k].heirsKeepToday < sorted[k - 1].heirsKeepToday - epsilon {
                out.append(InvariantViolation(
                    key: "frontier.nonDominated",
                    detail: "\(p.id): heirsKeep decreased with weight — weight \(sorted[k - 1].weight) "
                        + "heirsKeep \(sorted[k - 1].heirsKeepToday) > weight \(sorted[k].weight) "
                        + "heirsKeep \(sorted[k].heirsKeepToday)"))
            }
        }
        return out
    }

    // MARK: - ladder.noPhantom  (spec §4, §8-3)
    //
    // Each year's executed Roth conversion must fit inside the traditional balance actually
    // available to convert. `ProjectionEngine` clamps every conversion to
    // `startOfYearTrad − requiredRMD ≤ startOfYearTrad`, and applies investment growth only AFTER
    // the conversion step — so START-OF-YEAR OWN traditional is a hard ceiling on the executed
    // conversion. We use that ceiling directly (prior year's end-of-year own traditional; the
    // profile's starting own traditional for year 0). We deliberately do NOT subtract the RMD
    // reservation, making the bound strictly LOOSER (safer) than spec §4's net figure — it cannot
    // false-positive a legitimate conversion, yet still catches a phantom conversion that exceeds
    // the available balance (INV1/B4: reporting the requested, not the actual clamped, amount).
    // Inherited traditional is excluded from the ceiling because inherited IRAs are not convertible.

    private static func ladderNoPhantom(_ p: AuditProfile,
                                        _ s: DisplaySnapshot) -> [InvariantViolation] {
        var out: [InvariantViolation] = []
        let a = s.pathAudit
        for idx in a.years.indices {
            let executed = a.executedRothConversionByYear[idx]
            let available = idx == 0 ? a.startOwnTraditional : a.ownTraditionalEndByYear[idx - 1]
            if executed > available + epsilon {
                out.append(InvariantViolation(
                    key: "ladder.noPhantom",
                    detail: "\(p.id) year \(a.years[idx]): executedRothConversion \(executed) exceeds "
                        + "start-of-year own traditional \(available) (+ε) — phantom conversion"))
            }
        }
        return out
    }

    // MARK: - magi.geAGI  (spec §6, §8-4)
    //
    // The canonical, always-populated `YearRecommendation.magi` = AGI + addbacks, so it is never
    // less than `.agi` for the same year. Checked against the canonical fields (NOT the display
    // fallback `cliffmap.magiPoints`, which legitimately prefers the pre-gross-up irmaaMagi/acaMagi
    // and so can dip below `.agi` in a gross-up year per spec §6). Surfaces the A3 fingerprint.

    private static func magiGeAGI(_ p: AuditProfile, _ s: DisplaySnapshot) -> [InvariantViolation] {
        var out: [InvariantViolation] = []
        let a = s.pathAudit
        for idx in a.years.indices where a.magiByYear[idx] < a.agiByYear[idx] - epsilon {
            out.append(InvariantViolation(
                key: "magi.geAGI",
                detail: "\(p.id) year \(a.years[idx]): canonical magi \(a.magiByYear[idx]) "
                    + "< agi \(a.agiByYear[idx]) − ε"))
        }
        return out
    }

    // MARK: - balances.nonNegative  (spec §5, §8-6)
    //
    // Every account-balance series shown on the balances chart is ≥ 0 every year (mirroring the
    // `AccountSnapshot` max(0,…) clamp). ε lets a value sit at −1 without firing.

    private static func balancesNonNegative(_ p: AuditProfile,
                                            _ s: DisplaySnapshot) -> [InvariantViolation] {
        var out: [InvariantViolation] = []
        let b = s.balances
        func scan(_ series: [Double], _ label: String) {
            for idx in series.indices where series[idx] < -epsilon {
                let year = idx < b.years.count ? b.years[idx] : -1
                out.append(InvariantViolation(
                    key: "balances.nonNegative",
                    detail: "\(p.id) year \(year): \(label) balance \(series[idx]) < −ε"))
            }
        }
        scan(b.traditional, "traditional")
        scan(b.roth, "roth")
        scan(b.taxable, "taxable")
        return out
    }

    // MARK: - state.paConversionExempt  (spec §1 consequenceDelta.state, catches I1)
    //
    // PA/IL/MS exempt qualifying retirement-account conversions from state tax for a 59½+ owner,
    // so the incremental state tax attributable to the conversion (`comparison.consequenceDelta.state`
    // = selected-path minus no-conversion-path state tax, summed over years — exactly the isolate
    // the spec describes) should be ~0 even for a large conversion. Guarded so the check is NEVER
    // vacuous: it only asserts when the profile is a PA/IL/MS household with a 59½+ owner that
    // actually converted a positive amount. (I1 regression: PA conversions were incorrectly taxed.)

    private static func statePAConversionExempt(_ p: AuditProfile,
                                                _ s: DisplaySnapshot) -> [InvariantViolation] {
        let exemptStates: Set<String> = ["PA", "IL", "MS"]
        guard exemptStates.contains(p.inputs.state.uppercased()) else { return [] }
        guard p.inputs.primaryCurrentAge >= 60 else { return [] }                       // 59½+ owner
        guard s.comparison.selected.peakAnnualRothConversion > 0 else { return [] }      // actually converted
        let stateDelta = s.comparison.consequenceDelta.state
        if abs(stateDelta) >= epsilon {
            return [InvariantViolation(
                key: "state.paConversionExempt",
                detail: "\(p.id) [\(p.inputs.state)]: consequenceDelta.state \(stateDelta) attributable to a "
                    + "peak conversion of \(s.comparison.selected.peakAnnualRothConversion) ≥ ε — a qualifying "
                    + "retirement-account conversion should be state-exempt for a 59½+ owner")]
        }
        return []
    }
}
