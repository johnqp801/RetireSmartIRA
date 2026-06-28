import SwiftUI

/// Owner-vs-heirs tradeoff as strategy-labeled rows with plain outcomes (lifetime tax paid, what
/// heirs keep) and a delta vs the owner-optimal plan, led by a factual headline. A flat frontier
/// collapses to a single outcome instead of showing identical rows.
struct HeirFrontierView: View {
    let result: HeirFrontierResult
    @Binding var selectedWeight: Double
    let units: DisplayUnits   // governed by the tab-level toggle (MultiYearPlanView)

    private let numberWidth: CGFloat = 92

    var body: some View {
        let p = HeirFrontierPresentation(result: result, selectedWeight: selectedWeight, units: units)
        VStack(alignment: .leading, spacing: 10) {
            Text("Owner vs. heirs tradeoff").font(.headline)
            Text(p.headline).font(.callout).foregroundStyle(.secondary)

            if p.hasMaterialTradeoff {
                HStack {
                    Text("Strategy").font(.caption.bold())
                    Spacer()
                    Text("Lifetime tax").font(.caption.bold()).frame(width: numberWidth, alignment: .trailing)
                    Text("Heirs keep").font(.caption.bold()).frame(width: numberWidth, alignment: .trailing)
                }
                ForEach(p.rows) { row in
                    Button { selectedWeight = row.weight } label: { rowView(row) }
                        .buttonStyle(.plain)
                }
                Text("Each strategy is a different optimizer emphasis. Leaning toward heirs converts more now, so you pay more lifetime tax but more passes to them tax-free.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if let owner = p.rows.first {
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow("Your lifetime tax", owner.lifetimeTax)
                    summaryRow("What your heirs keep", owner.heirsKeep)
                }
                .font(.callout)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func rowView(_ row: HeirFrontierPresentation.Row) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(row.strategy).fontWeight(row.isSelected ? .bold : .regular)
                Spacer()
                Text(PlanSummary.shortDollars(row.lifetimeTax))
                    .monospacedDigit().frame(width: numberWidth, alignment: .trailing)
                Text(PlanSummary.shortDollars(row.heirsKeep))
                    .monospacedDigit().frame(width: numberWidth, alignment: .trailing)
            }
            if !row.isBaseline {
                Text(row.comparison).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(row.isSelected ? Color.Semantic.greenTint : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private func summaryRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(PlanSummary.shortDollars(value)).monospacedDigit()
        }
    }
}
