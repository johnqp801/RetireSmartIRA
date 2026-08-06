import SwiftUI

/// Three-way "compare conversion approaches" table: the selected approach, the objective anchor
/// (whatever the engine actually optimized for), and the no-added-conversions baseline. Replaces
/// the old two-way PlanComparisonView block on the Multi-Year Plan tab. Column headers always come
/// from ApproachUILogic so the anchor is described by what it optimizes, never labeled "Recommended".
struct ApproachComparisonView: View {
    let comparison: ApproachComparison
    let effectiveHeirWeight: Double
    let units: DisplayUnits
    /// When legacy planning is off, the heir metric is hidden (owner-lifetime-only view).
    var showHeirs: Bool = true

    /// The jurisdiction the accuracy affordance beside the State delta should
    /// describe, already resolved by the caller, or `nil` to show no affordance.
    ///
    /// RESOLVED BY THE CALLER, on purpose. `MultiYearPlanView` is the only
    /// place that holds both the state the engine modelled and the state the
    /// household lives in, so it is the only place the wrong one could be
    /// chosen, and therefore the place `StateAccuracyContent.stateForMultiYear`
    /// is called. This view does not read `DataManager` and must not start.
    ///
    /// `nil` before the engine has produced a plan, and for an input state no
    /// `USState` resolves: `ProjectionEngine` silently taxes that plan as
    /// California, so offering a page here would name a jurisdiction the
    /// figures were not computed in.
    var accuracyState: USState? = nil

    /// Filing status the accuracy page reports its bracket, deduction and
    /// exemption columns for. Ignored when `accuracyState` is `nil`.
    var filingStatus: FilingStatus = .single

    @State private var showingStateAccuracy = false

    private var titleSuffix: String { units == .presentValue ? " (present value)" : "" }
    private var rmdLabel: String { units == .presentValue ? "Peak forced RMD (nominal)" : "Peak forced RMD" }
    /// The lifetime-tax row always shows present value (see `ApproachUILogic.displayedLifetimeTax`),
    /// independent of the units toggle above, so it's labeled explicitly whenever the toggle itself
    /// reads "Future $" — otherwise the figure wouldn't match what the rest of the table implies.
    private var lifetimeTaxLabel: String { units == .presentValue ? "Lifetime tax" : "Lifetime tax (present value)" }

    /// Columns to render, left to right. The selected column is dropped when it IS the anchor
    /// (`collapsesToTwoColumns`), since showing it twice would just repeat the same numbers.
    private var columns: [(label: String, column: ApproachColumn)] {
        var cols: [(label: String, column: ApproachColumn)] = []
        if !comparison.collapsesToTwoColumns {
            cols.append((ApproachUILogic.columnLabel(comparison.selectedApproach, effectiveHeirWeight: effectiveHeirWeight),
                         comparison.selected))
        }
        cols.append((ApproachUILogic.anchorLabel(effectiveHeirWeight: effectiveHeirWeight), comparison.recommended))
        cols.append(("No added Roth conversions", comparison.noAdditionalConversions))
        return cols
    }

    private var deltaSummary: MultiYearCPABriefing.ApproachDeltaSummary {
        MultiYearCPABriefing.approachDeltaSummary(comparison)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compare conversion approaches\(titleSuffix)").font(.headline)

            if !comparison.collapsesToTwoColumns {
                Text(selectedVsAnchorHeadline).font(.callout).foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("")
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                        Text(col.label).font(.caption.bold()).gridColumnAlignment(.trailing)
                    }
                }
                metricRow(lifetimeTaxLabel) { lifetimeTax($0) }
                metricRow("Deferred tax on remaining IRA") { terminal($0.deferredTaxOnRemainingIRA, $0) }
                metricRow("Ending traditional IRA") { terminal($0.endingTraditional, $0) }
                metricRow("Ending Roth IRA") { terminal($0.endingRoth, $0) }
                if showHeirs {
                    metricRow("What heirs keep") { terminal($0.heirsKeep, $0) }
                }
                metricRow(rmdLabel) { $0.peakForcedRMD }
            }
            .font(.callout)

            consequenceStrip
            flagChips
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingStateAccuracy) {
            if let accuracyState {
                StateAccuracyView(state: accuracyState, filingStatus: filingStatus)
            }
        }
    }

    private var selectedVsAnchorHeadline: String {
        let d = deltaSummary
        // The lifetime-tax delta is PV (matching the row above and what the optimizer actually
        // minimizes); peak conversion and Medicare cost are nominal sums, so the PV figure is
        // called out explicitly to avoid implying all three share a basis.
        return "vs. \(ApproachUILogic.anchorLabel(effectiveHeirWeight: effectiveHeirWeight)): "
            + "\(signedDollars(d.deltaLifetimeTax)) lifetime tax (PV), "
            + "\(signedDollars(d.deltaPeakConversion)) peak conversion, "
            + "\(signedDollars(d.deltaMedicareCost)) Medicare cost"
    }

    private func lifetimeTax(_ col: ApproachColumn) -> Double {
        ApproachUILogic.displayedLifetimeTax(col)
    }

    /// Scales a terminal (ending-balance) figure for the chosen display units, mirroring
    /// PlanComparison.terminal(_:units:).
    private func terminal(_ nominal: Double, _ col: ApproachColumn) -> Double {
        units == .presentValue ? nominal * col.terminalPVFactor : nominal
    }

    private func signedDollars(_ v: Double) -> String {
        let sign = v > 0 ? "+" : ""
        return sign + PlanSummary.shortDollars(v)
    }

    private func metricRow(_ label: String, _ value: @escaping (ApproachColumn) -> Double) -> some View {
        GridRow {
            Text(label)
            ForEach(Array(columns.enumerated()), id: \.offset) { idx, col in
                Text(PlanSummary.shortDollars(value(col.column)))
                    .monospacedDigit()
                    .gridColumnAlignment(.trailing)
                    .foregroundStyle(idx == 0 ? .primary : .secondary)
            }
        }
    }

    // MARK: - Consequence strip (selected vs. no added conversions)

    private var consequenceStrip: some View {
        let d = comparison.deltas
        return VStack(alignment: .leading, spacing: 4) {
            // Total is pinned to the header line so it stays visible; the five channel tags scroll
            // horizontally when they can't fit (a rigid HStack of five tags + total crushed/clipped
            // on narrow iPhone widths). Identical to the single-line layout on Mac/iPad, where the
            // tags fit without scrolling.
            HStack(alignment: .firstTextBaseline) {
                Text("What the selected approach adds vs. no added Roth conversions")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("Total \(signedDollars(d.total))").font(.callout.bold())
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    deltaTag("Federal", d.federal)
                    stateDeltaTag(d.state)
                    deltaTag("IRMAA", d.irmaa)
                    deltaTag("ACA", d.aca)
                    deltaTag("NIIT", d.niit)
                }
            }
        }
        .padding(.top, 4)
    }

    /// The state tax delta, carrying the Multi-Year tab's accuracy affordance.
    ///
    /// THIS IS THE MULTI-YEAR TAB'S STATE TAX FIGURE. The plan's Task 7 calls
    /// it "the multi-year plan state tax row", which does not exist under that
    /// name: the ladder shows conversion, AGI and IRMAA per year, and the plan
    /// summary shows a lifetime total. This tag is the one place the tab prints
    /// a number that is specifically state income tax, so it is where the
    /// affordance belongs, per the design's "beside the state tax figure, at
    /// the moment the number is visible". See the task report.
    ///
    /// Falls back to the plain, untappable tag when no state resolved, rather
    /// than offering a page about a jurisdiction the figure may not belong to.
    @ViewBuilder
    private func stateDeltaTag(_ value: Double) -> some View {
        if let accuracyState {
            Button {
                showingStateAccuracy = true
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text("State (\(accuracyState.abbreviation))")
                            .font(.caption2).foregroundStyle(.secondary)
                        Image(systemName: "info.circle")
                            .font(.caption2).foregroundStyle(Color.UI.brandTeal)
                    }
                    Text(signedDollars(value)).font(.caption).monospacedDigit()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("State tax accuracy for \(accuracyState.rawValue)")
        } else {
            deltaTag("State", value)
        }
    }

    private func deltaTag(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(signedDollars(value)).font(.caption).monospacedDigit()
        }
    }

    // MARK: - Triggered-effect flags

    /// Small tags for the tax/benefit effects the selected approach triggered relative to the
    /// no-conversion baseline. The NIIT tag wording is deliberate: NIIT applies because MAGI
    /// crossed the threshold and the household already has net investment income, never implying
    /// the Roth conversion itself counts as net investment income.
    private var flagChips: some View {
        let flags = comparison.flags
        let active: [String] = [
            flags.ordinaryBracketCrossed ? "Moved into a higher ordinary tax bracket" : nil,
            flags.capGainBracketAffected ? "Affected the capital-gains tax bracket" : nil,
            flags.ssTaxationIncreased ? "More Social Security became taxable" : nil,
            flags.irmaaTierCrossed ? "Crossed a Medicare IRMAA tier" : nil,
            flags.acaCliffCrossed ? "Crossed the ACA subsidy cliff" : nil,
            flags.niitIncreased ? "NIIT increased because MAGI crossed the threshold and the household has net investment income" : nil
        ].compactMap { $0 }

        return Group {
            if !active.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(active, id: \.self) { text in
                        Label(text, systemImage: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}
