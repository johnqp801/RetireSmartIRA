import SwiftUI

/// Editable strip for the inputs with no home elsewhere. Mutates the bound assumptions and
/// triggers a recompute via the closure.
struct AssumptionsStripView: View {
    // Taxable accounts are entered in the Accounts tab now; this is a read-only roll-up so the
    // balance isn't owned in two places. Editing lives where the rest of the balance sheet lives.
    let taxableSummary: (count: Int, total: Double)
    /// Annual living expenses in today's dollars; the engine inflates by CPI over the horizon.
    /// Drives how much is actually spent (vs accumulated), which materially changes ending balances.
    @Binding var annualExpenses: Double
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
            LabeledContent("Annual living expenses") {
                TextField("0", value: $annualExpenses, format: .number).multilineTextAlignment(.trailing)
            }
            LabeledContent("HSA balance") {
                TextField("0", value: $hsaBalance, format: .number).multilineTextAlignment(.trailing)
            }
            Stepper("Plan through age \(horizonEndAge)", value: $horizonEndAge, in: 70...110)
        }
        .onChange(of: annualExpenses) { _, _ in onCommit() }
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
                metricRow("Ending taxable", comparison.terminal(comparison.endingTaxable, units: units))
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
    /// Per-year living-expense overrides — read only to decide whether a row's badge shows.
    var overrides: [Int: YearOverride] = [:]
    /// Invoked with `row.year` when the row's edit control is tapped.
    var onEditYear: (Int) -> Void = { _ in }
    private var anyIRMAA: Bool { rows.contains(where: \.hasIRMAASurcharge) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Modeled conversion ladder").font(.headline)
            ForEach(rows) { row in
                ladderRow(row)
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

    // Extracted from `body` so the type-checker isn't asked to solve one giant ForEach closure
    // (precedent: SettingsView.localIncomeTaxField) — keeps the per-row edit control + badge cheap
    // to add without a "unable to type-check in reasonable time" regression.
    @ViewBuilder
    private func ladderRow(_ row: LadderRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(String(row.year)).monospacedDigit()
                Text(row.conversionLabel)
                if LadderRow.hasOverride(year: row.year, overrides: overrides) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.blue)
                        .accessibilityLabel("Customized")
                }
                Spacer()
                Text(row.agiLabel).foregroundStyle(.secondary)
                if row.hasIRMAASurcharge {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(row.irmaaLabel).foregroundStyle(.orange)
                }
                Button {
                    onEditYear(row.year)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Edit \(String(row.year))")
            }
            .font(.callout)
            // A4: when taxable funding was short, the engine took an ADDITIONAL IRA
            // withdrawal to pay the conversion tax — surface it so "convert $Y" is not
            // read as the whole IRA outflow for the year.
            if row.hasTaxFundingWithdrawal {
                Text(row.taxFundingLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
