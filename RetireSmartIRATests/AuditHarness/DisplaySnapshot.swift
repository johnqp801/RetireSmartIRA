//
//  DisplaySnapshot.swift
//  RetireSmartIRATests
//
//  Stage 1, Task 3 of the Multi-Year Display Audit Harness.
//
//  `DisplaySnapshot.capture(profile, provider:)` runs the REAL engine and coordinators —
//  the exact ones the SwiftUI Multi-Year surfaces consume — and records what each surface
//  renders, as plain `Codable` structs. Field names mirror the app model field names 1:1
//  (see `docs/superpowers/audit/multi-year-display-spec.md` §1–§7) so Task 4's property
//  oracle and Stage-2 reviewers can map a snapshot field to a `surface.field` spec key.
//
//  This task CAPTURES values only — it adds no invariant assertions (that is Task 4).
//
//  Surfaces captured:
//    §1 comparison.*   (ApproachComparisonCoordinator.compare → ApproachComparison)
//    §2 frontier.*     (HeirFrontierCoordinator.computeFrontier → HeirFrontierResult)
//    §3 taximpact.*    (TaxImpactChart — plan vs the no-conversion baseline)  ← per design-doc §6
//    §4 ladder.*       (ConversionLadderChart over the active path)
//    §5 balances.*     (BalancesChart over the active path + sensitivity bands)
//    §6 cliffmap.*     (ThresholdMapChart + ThresholdMapThresholds, pinned config)
//    §7 cpa.*          (CPA briefing figures — PlanSummary + PlanComparison + frontier)
//
//  Deterministic: no Date(), no RNG, config pinned via the injected provider.
//
//  ── Deterministic derivations for view/DataManager inputs the profile does not carry ──
//   • Legacy planning: treated as ON for every profile (each AuditProfile carries a meaningful
//     `heirWeight`, the frontier is always computed, and the heir columns/rows are always
//     surfaced). So `effectiveHeirWeight = profile.heirWeight`, `includeHeirs = true`, and the
//     active-path base is the frontier point at `profile.heirWeight` (the view's legacy-on branch,
//     MultiYearPlanView.activePath).
//   • The "doing nothing" baseline is the no-conversion ProjectionEngine run over an empty action
//     map — identical to both `manager.baselineProjection` (taximpact/CPA source) and
//     `comparison.noAdditionalConversions.path` (they use the same helper + engine).
//   • cliffmap threshold lines use the pinned `provider.config(forYear: baseYear)` (the view uses
//     TaxCalculationEngine.config, which is the same 2026 config); householdSize/includeACA come
//     from `inputs.acaHouseholdSize` / `inputs.acaEnrolled` (mirrors scenario.acaHouseholdSize /
//     scenario.enableACAModeling at the call site).
//

import Foundation
@testable import RetireSmartIRA

// MARK: - Snapshot value types (plain Codable — no SwiftUI / engine reference types)

struct DisplaySnapshot: Codable {
    let profileID: String
    let comparison: ComparisonSnapshot   // §1
    let frontier: FrontierSnapshot       // §2
    let taximpact: TaxImpactSnapshot     // §3
    let ladder: LadderSnapshot           // §4
    let balances: BalancesSnapshot       // §5
    let cliffmap: CliffMapSnapshot       // §6
    let cpa: CPASnapshot                 // §7
}

// §1 ─ comparison.*
struct ComparisonColumnSnapshot: Codable {
    // Mirrors ApproachColumn exactly.
    let lifetimeTaxNominal: Double
    let lifetimeTaxPV: Double
    let deferredTaxOnRemainingIRA: Double
    let endingTraditional: Double
    let endingRoth: Double
    let endingTaxable: Double
    let heirsKeep: Double
    let peakForcedRMD: Double
    let peakAnnualRothConversion: Double
    let terminalPVFactor: Double
    /// ApproachUILogic.displayedLifetimeTax(column) — the row the table actually renders (always PV).
    let displayedLifetimeTax: Double

    init(_ c: ApproachColumn) {
        lifetimeTaxNominal = c.lifetimeTaxNominal
        lifetimeTaxPV = c.lifetimeTaxPV
        deferredTaxOnRemainingIRA = c.deferredTaxOnRemainingIRA
        endingTraditional = c.endingTraditional
        endingRoth = c.endingRoth
        endingTaxable = c.endingTaxable
        heirsKeep = c.heirsKeep
        peakForcedRMD = c.peakForcedRMD
        peakAnnualRothConversion = c.peakAnnualRothConversion
        terminalPVFactor = c.terminalPVFactor
        displayedLifetimeTax = ApproachUILogic.displayedLifetimeTax(c)
    }
}

struct ConsequenceDeltasSnapshot: Codable {
    let federal: Double
    let state: Double
    let irmaa: Double
    let aca: Double
    let niit: Double
    let total: Double

    init(_ d: ConsequenceDeltas) {
        federal = d.federal; state = d.state; irmaa = d.irmaa
        aca = d.aca; niit = d.niit; total = d.total
    }
}

struct ConsequenceFlagsSnapshot: Codable {
    let ssTaxationIncreased: Bool
    let irmaaTierCrossed: Bool
    let acaCliffCrossed: Bool
    let ordinaryBracketCrossed: Bool
    let capGainBracketAffected: Bool
    let niitIncreased: Bool

    init(_ f: ConsequenceFlags) {
        ssTaxationIncreased = f.ssTaxationIncreased
        irmaaTierCrossed = f.irmaaTierCrossed
        acaCliffCrossed = f.acaCliffCrossed
        ordinaryBracketCrossed = f.ordinaryBracketCrossed
        capGainBracketAffected = f.capGainBracketAffected
        niitIncreased = f.niitIncreased
    }
}

struct ComparisonSnapshot: Codable {
    let selectedApproach: String
    let collapsesToTwoColumns: Bool
    let selected: ComparisonColumnSnapshot
    let recommended: ComparisonColumnSnapshot           // the anchor
    let noAdditionalConversions: ComparisonColumnSnapshot
    let consequenceDelta: ConsequenceDeltasSnapshot
    let flags: ConsequenceFlagsSnapshot
    // Headline-strip deltas (selected vs anchor) — MultiYearCPABriefing.approachDeltaSummary.
    let deltaLifetimeTax: Double     // pv$
    let deltaPeakConversion: Double  // nominal$
    let deltaMedicareCost: Double    // nominal$
}

// §2 ─ frontier.*
struct FrontierPointSnapshot: Codable {
    let weight: Double
    let ownerLifetimeTaxToday: Double
    let ownerLifetimeTaxPV: Double
    let heirsKeepToday: Double       // heirAfterTaxInheritanceToday
    let heirsKeepPV: Double
    let heirTaxToday: Double
    let heirTaxPV: Double
    let pvDiscountFactor: Double

    init(_ p: FrontierPoint) {
        weight = p.weight
        ownerLifetimeTaxToday = p.ownerLifetimeTaxToday
        ownerLifetimeTaxPV = p.ownerLifetimeTax(units: .presentValue)
        heirsKeepToday = p.heirAfterTaxInheritanceToday
        heirsKeepPV = p.heirAfterTaxInheritance(units: .presentValue)
        heirTaxToday = p.heirTaxToday
        heirTaxPV = p.heirTax(units: .presentValue)
        pvDiscountFactor = p.pvDiscountFactor
    }
}

struct FrontierSnapshot: Codable {
    let points: [FrontierPointSnapshot]
}

// §3 ─ taximpact.*
struct TaxImpactSnapshot: Codable {
    let years: [Int]
    let cumulativePlan: [Double]
    let cumulativeDoingNothing: [Double]
    let totalSavings: Double
}

// §4 ─ ladder.*  (windowed exactly as ConversionLadderChart renders)
struct LadderSnapshot: Codable {
    let years: [Int]                 // windowed x-axis
    let conversionByYear: [Double]   // executedRothConversion, windowed
    let hasAnyConversion: Bool
    let windowStart: Int?
    let windowEnd: Int?
}

// §5 ─ balances.*
struct BalancesSnapshot: Codable {
    let years: [Int]
    let traditional: [Double]
    let roth: [Double]
    let taxable: [Double]
    let totalLow: [Double?]
    let totalHigh: [Double?]
    let hasBand: Bool
}

// §6 ─ cliffmap.*
struct CliffLineSnapshot: Codable {
    let id: String
    let label: String
    let value: Double

    init(_ l: ThresholdMapChart.Line) { id = l.id; label = l.label; value = l.value }
}

struct CliffMapSnapshot: Codable {
    let years: [Int]
    let magiPoints: [Double]       // irmaaMagi ?? acaMagi ?? agi, per year
    let bracketPoints: [Double]    // taxableIncome, per year
    let magiLines: [CliffLineSnapshot]
    let bracketLines: [CliffLineSnapshot]
}

// §7 ─ cpa.*
struct CPALadderRowSnapshot: Codable {
    let year: Int
    let conversion: Double
    let taxFundingWithdrawal: Double
}

struct CPASnapshot: Codable {
    let includeHeirs: Bool
    // Executive summary
    let recommendedConversionsTotal: Double
    let recommendedConversionYears: Int
    let lifetimeTaxPlan: Double            // nominal
    let lifetimeTaxDoingNothing: Double    // nominal
    let lifetimeTaxDifference: Double      // savings
    // "Your plan vs doing nothing" (plan / doingNothing pairs, all nominal)
    let planVsNothingLifetimeTaxPlan: Double
    let planVsNothingLifetimeTaxDoingNothing: Double
    let endingTraditionalPlan: Double
    let endingTraditionalDoingNothing: Double
    let endingRothPlan: Double
    let endingRothDoingNothing: Double
    let heirsKeepPlan: Double
    let heirsKeepDoingNothing: Double
    let peakForcedRMDPlan: Double
    let peakForcedRMDDoingNothing: Double
    // Recommended conversions by year (unwindowed; > 0 rows only) + gross-up note
    let ladderRows: [CPALadderRowSnapshot]
    let grossUpYears: [Int]
    // Selected-approach section (nil when the comparison collapses / no approach section renders)
    let approachSelectedLifetimeTaxDelta: Double?
    let approachSelectedPeakConversionDelta: Double?
    let approachSelectedMedicareCostDelta: Double?
    // Owner-vs-heirs table (today's dollars, per weight)
    let frontierWeights: [Double]
    let frontierOwnerLifetimeTaxToday: [Double]
    let frontierHeirsKeepToday: [Double]
    // Assumptions
    let assumptionInvestmentGrowthRate: Double
    let assumptionCPIRate: Double
    let assumptionTerminalLiquidationTaxRate: Double
    let assumptionHorizonEndAge: Int
    let assumptionWithdrawalOrdering: String
    // Year-by-year ending balances (for §7/§8 last-year reconciliation)
    let yearByYearEndTraditional: [Double]
    let yearByYearEndRoth: [Double]
    let yearByYearEndTaxable: [Double]
}

// MARK: - Capture

extension DisplaySnapshot {

    /// Run the real engine/coordinators for `profile` and record what every Multi-Year surface
    /// renders. `provider` pins the tax-year config (the test injects `.fixed(2026)`).
    static func capture(_ profile: AuditProfile, provider: TaxYearConfigProvider) -> DisplaySnapshot {
        let inputs = profile.inputs
        let assumptions = profile.assumptions
        let approach = profile.approach
        let heirWeight = profile.heirWeight

        // §1 — approach comparison (heir-aware; legacy-on ⇒ pass the profile's heir weight).
        let comparison = ApproachComparisonCoordinator().compare(
            inputs: inputs, assumptions: assumptions,
            selectedApproach: approach, heirWeight: heirWeight,
            configProvider: provider)

        // §2 — heir frontier (always computed; six preset weights).
        let frontier = HeirFrontierCoordinator().computeFrontier(
            inputs: inputs, assumptions: assumptions, configProvider: provider)

        // No-conversion baseline ("doing nothing") — the ProjectionEngine run over an empty action
        // map, exactly as manager.baselineProjection (taximpact + CPA source) is built.
        let baseline = ProjectionEngine(configProvider: provider).project(
            inputs: inputs, assumptions: assumptions,
            actionsPerYear: ApproachComparisonCoordinator.emptyActionsMap(
                inputs: inputs, assumptions: assumptions))

        // Active/selected path — resolve the SAME way MultiYearPlanView.activePath does (legacy-on
        // branch: base = frontier point at the selected weight; deterministic approaches read the
        // comparison's selected column path).
        let framePath = frontier.points.first(where: { $0.weight == heirWeight })?.recommendedPath
            ?? frontier.baseline?.recommendedPath
            ?? []
        let activePath = ApproachUILogic.activePath(
            selected: approach, comparison: comparison, frontierOrCurrent: framePath)

        // Sensitivity bands for the balances chart — from the MultiYearTaxStrategyEngine run that
        // backs manager.currentResult (stressTestEnabled=false ⇒ bands mirror the recommended path).
        let currentResult = MultiYearTaxStrategyEngine().compute(
            inputs: inputs, assumptions: assumptions, configProvider: provider)

        // ── §1 assemble ──
        let approachDeltas = MultiYearCPABriefing.approachDeltaSummary(comparison)
        let comparisonSnap = ComparisonSnapshot(
            selectedApproach: String(describing: approach),
            collapsesToTwoColumns: comparison.collapsesToTwoColumns,
            selected: ComparisonColumnSnapshot(comparison.selected),
            recommended: ComparisonColumnSnapshot(comparison.recommended),
            noAdditionalConversions: ComparisonColumnSnapshot(comparison.noAdditionalConversions),
            consequenceDelta: ConsequenceDeltasSnapshot(comparison.deltas),
            flags: ConsequenceFlagsSnapshot(comparison.flags),
            deltaLifetimeTax: approachDeltas.deltaLifetimeTax,
            deltaPeakConversion: approachDeltas.deltaPeakConversion,
            deltaMedicareCost: approachDeltas.deltaMedicareCost)

        // ── §2 assemble ──
        let frontierSnap = FrontierSnapshot(points: frontier.points.map(FrontierPointSnapshot.init))

        // ── §3 assemble ── (TaxImpactChart(plan: activePath, doingNothing: baseline))
        let taxImpact = TaxImpactChart(plan: activePath, doingNothing: baseline)
        let taxImpactSnap = TaxImpactSnapshot(
            years: taxImpact.points.map(\.year),
            cumulativePlan: taxImpact.points.map(\.cumulativePlan),
            cumulativeDoingNothing: taxImpact.points.map(\.cumulativeDoingNothing),
            totalSavings: taxImpact.totalSavings)

        // ── §4 assemble ── (ConversionLadderChart windows leading/trailing zero-conversion years)
        let ladderChart = ConversionLadderChart(path: activePath)
        let firstConvYear = activePath.first(where: { $0.executedRothConversion > 0 })?.year
        let lastConvYear = activePath.last(where: { $0.executedRothConversion > 0 })?.year
        let ladderSnap = LadderSnapshot(
            years: ladderChart.points.map(\.year),
            conversionByYear: ladderChart.points.map(\.conversion),
            hasAnyConversion: ladderChart.hasAnyConversion,
            windowStart: firstConvYear,
            windowEnd: lastConvYear)

        // ── §5 assemble ── (BalancesChart with the sensitivity band paths)
        let balancesChart = BalancesChart(
            path: activePath,
            pessimistic: currentResult.sensitivityBands.pessimistic,
            optimistic: currentResult.sensitivityBands.optimistic)
        let balancesSnap = BalancesSnapshot(
            years: balancesChart.points.map(\.year),
            traditional: balancesChart.points.map(\.traditional),
            roth: balancesChart.points.map(\.roth),
            taxable: balancesChart.points.map(\.taxable),
            totalLow: balancesChart.points.map(\.totalLow),
            totalHigh: balancesChart.points.map(\.totalHigh),
            hasBand: balancesChart.hasBand)

        // ── §6 assemble ── (ThresholdMapChart + pinned-config threshold lines)
        let config = provider.config(forYear: inputs.baseYear)
        let magiLines = ThresholdMapThresholds.magiLines(
            config: config, filingStatus: inputs.filingStatus,
            householdSize: inputs.acaHouseholdSize, includeACA: inputs.acaEnrolled)
        let bracketLines = ThresholdMapThresholds.bracketLines(
            config: config, filingStatus: inputs.filingStatus)
        let thresholdChart = ThresholdMapChart(
            path: activePath, magiLines: magiLines, bracketLines: bracketLines)
        let cliffmapSnap = CliffMapSnapshot(
            years: thresholdChart.magiPoints.map(\.year),
            magiPoints: thresholdChart.magiPoints.map(\.value),
            bracketPoints: thresholdChart.bracketPoints.map(\.value),
            magiLines: thresholdChart.magiLines.map(CliffLineSnapshot.init),
            bracketLines: thresholdChart.bracketLines.map(CliffLineSnapshot.init))

        // ── §7 assemble ── (CPA briefing figures — same builders as makeBriefingModel())
        let includeHeirs = true   // legacy-on for the harness (see file header)
        let summary = PlanSummary(path: activePath,
                                  pvRealDiscountRate: assumptions.pvRealDiscountRate,
                                  cpiRate: assumptions.cpiRate)
        let planComparison = PlanComparison(
            plan: activePath, doingNothing: baseline,
            heirSalary: inputs.heirSalary, heirFilingStatus: inputs.heirFilingStatus,
            heirDrawdownYears: inputs.heirDrawdownYears,
            pvRealDiscountRate: assumptions.pvRealDiscountRate, cpiRate: assumptions.cpiRate)
        let lifetimeSavings = planComparison.lifetimeTax.doingNothing - planComparison.lifetimeTax.plan

        // Selected-approach section renders only when a comparison exists AND it does not collapse
        // (selected ≠ anchor); mirror briefingApproachSummary's nil gate.
        let approachSectionShown = !comparison.collapsesToTwoColumns

        let cpaLadderRows: [CPALadderRowSnapshot] = activePath
            .filter { $0.executedRothConversion > 0 }
            .map { CPALadderRowSnapshot(year: $0.year, conversion: $0.executedRothConversion,
                                        taxFundingWithdrawal: $0.taxFundingWithdrawal) }
        let grossUpYears = activePath.filter { $0.taxFundingWithdrawal > 0 }.map(\.year)

        let cpaSnap = CPASnapshot(
            includeHeirs: includeHeirs,
            recommendedConversionsTotal: summary.totalConversions,
            recommendedConversionYears: summary.conversionYears,
            lifetimeTaxPlan: summary.lifetimeTax,
            lifetimeTaxDoingNothing: planComparison.lifetimeTax.doingNothing,
            lifetimeTaxDifference: lifetimeSavings,
            planVsNothingLifetimeTaxPlan: planComparison.lifetimeTax.plan,
            planVsNothingLifetimeTaxDoingNothing: planComparison.lifetimeTax.doingNothing,
            endingTraditionalPlan: planComparison.endingTraditional.plan,
            endingTraditionalDoingNothing: planComparison.endingTraditional.doingNothing,
            endingRothPlan: planComparison.endingRoth.plan,
            endingRothDoingNothing: planComparison.endingRoth.doingNothing,
            heirsKeepPlan: planComparison.heirsKeep.plan,
            heirsKeepDoingNothing: planComparison.heirsKeep.doingNothing,
            peakForcedRMDPlan: planComparison.peakForcedRMD.plan,
            peakForcedRMDDoingNothing: planComparison.peakForcedRMD.doingNothing,
            ladderRows: cpaLadderRows,
            grossUpYears: grossUpYears,
            approachSelectedLifetimeTaxDelta: approachSectionShown ? approachDeltas.deltaLifetimeTax : nil,
            approachSelectedPeakConversionDelta: approachSectionShown ? approachDeltas.deltaPeakConversion : nil,
            approachSelectedMedicareCostDelta: approachSectionShown ? approachDeltas.deltaMedicareCost : nil,
            frontierWeights: frontier.points.map(\.weight),
            frontierOwnerLifetimeTaxToday: frontier.points.map(\.ownerLifetimeTaxToday),
            frontierHeirsKeepToday: frontier.points.map(\.heirAfterTaxInheritanceToday),
            assumptionInvestmentGrowthRate: assumptions.investmentGrowthRate,
            assumptionCPIRate: assumptions.cpiRate,
            assumptionTerminalLiquidationTaxRate: assumptions.terminalLiquidationTaxRate,
            assumptionHorizonEndAge: assumptions.horizonEndAge,
            assumptionWithdrawalOrdering: assumptions.withdrawalOrderingRule.displayName,
            yearByYearEndTraditional: activePath.map {
                $0.endOfYearBalances.traditional + $0.endOfYearBalances.inheritedTraditional },
            yearByYearEndRoth: activePath.map {
                $0.endOfYearBalances.roth + $0.endOfYearBalances.inheritedRoth },
            yearByYearEndTaxable: activePath.map { $0.endOfYearBalances.taxable })

        return DisplaySnapshot(
            profileID: profile.id,
            comparison: comparisonSnap,
            frontier: frontierSnap,
            taximpact: taxImpactSnap,
            ladder: ladderSnap,
            balances: balancesSnap,
            cliffmap: cliffmapSnap,
            cpa: cpaSnap)
    }
}
