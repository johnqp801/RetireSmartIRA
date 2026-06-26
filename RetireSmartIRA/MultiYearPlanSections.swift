import SwiftUI

/// Editable strip for the inputs with no home elsewhere. Mutates the bound assumptions and
/// triggers a recompute via the closure.
struct AssumptionsStripView: View {
    @Binding var taxableBalance: Double
    @Binding var hsaBalance: Double
    @Binding var horizonEndAge: Int
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assumptions").font(.subheadline).foregroundStyle(.secondary)
            HStack {
                LabeledContent("Taxable balance") {
                    TextField("0", value: $taxableBalance, format: .number).multilineTextAlignment(.trailing)
                }
                LabeledContent("HSA balance") {
                    TextField("0", value: $hsaBalance, format: .number).multilineTextAlignment(.trailing)
                }
            }
            Stepper("Plan through age \(horizonEndAge)", value: $horizonEndAge, in: 70...110)
        }
        .onChange(of: taxableBalance) { _, _ in onCommit() }
        .onChange(of: hsaBalance) { _, _ in onCommit() }
        .onChange(of: horizonEndAge) { _, _ in onCommit() }
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlanSummaryView: View {
    let summary: PlanSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your plan").font(.headline)
            Text("Projected lifetime tax: \(PlanSummary.shortDollars(summary.lifetimeTax))")
            Text(summary.headline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlanComparisonView: View {
    let comparison: PlanComparison
    let units: DisplayUnits

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
                metricRow("What heirs keep", comparison.terminal(comparison.heirsKeep, units: units))
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
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recommended ladder").font(.headline)
            ForEach(rows) { row in
                HStack {
                    Text(String(row.year)).monospacedDigit()
                    Text(row.conversionLabel)
                    Spacer()
                    Text(row.agiLabel).foregroundStyle(.secondary)
                    if row.hasIRMAASurcharge {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                .font(.callout)
            }
        }
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
