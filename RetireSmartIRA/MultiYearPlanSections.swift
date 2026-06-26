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
