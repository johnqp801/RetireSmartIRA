import SwiftUI

/// Editable strip for the inputs with no home elsewhere. Mutates the bound assumptions and
/// triggers a recompute via the closure.
struct AssumptionsStripView: View {
    // Taxable accounts are entered in the Accounts tab now; this is a read-only roll-up so the
    // balance isn't owned in two places. Editing lives where the rest of the balance sheet lives.
    let taxableSummary: (count: Int, total: Double)
    @Binding var hsaBalance: Double
    @Binding var horizonEndAge: Int
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assumptions").font(.subheadline).foregroundStyle(.secondary)
            // One field per row: side-by-side LabeledContent crowded values against labels (tight on
            // iPad, worse on iPhone). Full-width rows match the stepper below and read cleanly.
            LabeledContent("Taxable accounts") {
                if taxableSummary.count == 0 {
                    Text("None entered").foregroundStyle(.secondary)
                } else {
                    Text("\(taxableSummary.total, format: .currency(code: "USD").precision(.fractionLength(0))) across \(taxableSummary.count) accounts")
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("HSA balance") {
                TextField("0", value: $hsaBalance, format: .number).multilineTextAlignment(.trailing)
            }
            Stepper("Plan through age \(horizonEndAge)", value: $horizonEndAge, in: 70...110)
        }
        .onChange(of: hsaBalance) { _, _ in onCommit() }
        .onChange(of: horizonEndAge) { _, _ in onCommit() }
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlanSummaryView: View {
    let summary: PlanSummary
    let units: DisplayUnits
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your plan").font(.headline)
            Text("Projected lifetime tax: \(PlanSummary.shortDollars(summary.lifetimeTax(units: units)))")
            Text(summary.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlanComparisonView: View {
    let comparison: PlanComparison
    let units: DisplayUnits
    /// When legacy planning is off, the heir metric is hidden (owner-lifetime-only view).
    var showHeirs: Bool = true

    private var titleSuffix: String { units == .presentValue ? " · present value" : "" }
    private var rmdLabel: String { units == .presentValue ? "Peak forced RMD (nominal)" : "Peak forced RMD" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your plan vs. doing nothing\(titleSuffix)").font(.headline)
            Text(comparison.headline(units: units)).font(.callout).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("")
                    Text("Your plan").font(.caption.bold()).gridColumnAlignment(.trailing)
                    Text("Doing nothing").font(.caption.bold()).gridColumnAlignment(.trailing)
                }
                metricRow("Lifetime tax", comparison.lifetimeTax(units: units))
                metricRow("Ending traditional IRA", comparison.terminal(comparison.endingTraditional, units: units))
                metricRow("Ending Roth IRA", comparison.terminal(comparison.endingRoth, units: units))
                metricRow(rmdLabel, comparison.peakForcedRMD)
                if showHeirs {
                    metricRow("What heirs keep", comparison.terminal(comparison.heirsKeep, units: units))
                }
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metricRow(_ label: String, _ pair: PlanComparison.Pair) -> some View {
        GridRow {
            Text(label)
            Text(PlanSummary.shortDollars(pair.plan))
                .monospacedDigit().gridColumnAlignment(.trailing)
            Text(PlanSummary.shortDollars(pair.doingNothing))
                .monospacedDigit().foregroundStyle(.secondary).gridColumnAlignment(.trailing)
        }
    }
}

struct LadderListView: View {
    let rows: [LadderRow]
    /// How many years the no-conversion baseline pays IRMAA on its own. Drives a clarifying note
    /// when your income triggers IRMAA in far more years than the conversions add to.
    var baselineIRMAAYears: Int = 0
    private var anyIRMAA: Bool { rows.contains(where: \.hasIRMAASurcharge) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Modeled conversion ladder").font(.headline)
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Text(String(row.year)).monospacedDigit()
                    Text(row.conversionLabel)
                    Spacer()
                    Text(row.agiLabel).foregroundStyle(.secondary)
                    if row.hasIRMAASurcharge {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(row.irmaaLabel).foregroundStyle(.orange)
                    }
                }
                .font(.callout)
            }
            if baselineIRMAAYears >= 3 {
                Label(
                    "Your other income already triggers Medicare IRMAA in \(baselineIRMAAYears) of these years, mainly from required distributions. The ladder flags only the extra surcharge a conversion adds on top.",
                    systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            if anyIRMAA {
                Label(
                    "IRMAA = the EXTRA Medicare premium these conversions add, beyond what your other income would trigger anyway. Medicare sets the premium from your income two years earlier, so a conversion shows up as a surcharge later. Amounts are estimates under current thresholds; future Medicare rules and your actual income may change them.",
                    systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
