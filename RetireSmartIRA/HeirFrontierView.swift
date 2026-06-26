import SwiftUI

struct HeirFrontierView: View {
    let result: HeirFrontierResult
    @Binding var selectedWeight: Double
    @Binding var units: DisplayUnits

    private var selected: FrontierPoint {
        result.points.first(where: { $0.weight == selectedWeight }) ?? result.points[0]
    }
    private var vm: HeirFrontierViewModel? {
        guard let baseline = result.baseline else { return nil }
        return HeirFrontierViewModel(baseline: baseline, selected: selected, units: units)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your taxes vs. what your heirs keep").font(.headline)
                Spacer()
                Picker("", selection: $units) {
                    Text("Today's $").tag(DisplayUnits.todaysDollars)
                    Text("Present value").tag(DisplayUnits.presentValue)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            ForEach(result.points) { p in
                Button {
                    selectedWeight = p.weight
                } label: {
                    HStack {
                        Text("\(Int(p.weight * 100))% to heirs")
                            .fontWeight(p.weight == selectedWeight ? .bold : .regular)
                        Spacer()
                        Text("You: \(PlanSummary.shortDollars(p.ownerLifetimeTax(units: units)))")
                            .foregroundStyle(.secondary)
                        Text("Heirs: \(PlanSummary.shortDollars(p.heirAfterTaxInheritance(units: units)))")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            if let vm {
                Text(vm.readoutText)
                    .font(.callout)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
