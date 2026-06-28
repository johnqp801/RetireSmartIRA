import SwiftUI

/// Editable Year-1 Roth conversion for the Multi-Year Plan tab, with an off-plan badge and a
/// one-tap reset to the engine-optimal. Year-1 is the shared single-year scenario; this edits the
/// combined household Roth conversion (the only Year-1 lever the v2.0 optimizer honors).
struct Year1EditorView: View {
    @Binding var year1RothConversion: Double
    let status: OffPlanStatus?
    var onCommit: () -> Void
    var onResetToOptimal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This year").font(.headline)
                Spacer()
                if let status { OffPlanBadge(status: status) }
            }
            LabeledContent("Roth conversion this year") {
                TextField("0", value: $year1RothConversion, format: .number)
                    .multilineTextAlignment(.trailing)
            }
            if let status, !status.isOnPlan {
                Text(status.caption).font(.caption).foregroundStyle(.secondary)
                Button("Reset to optimal", action: onResetToOptimal).font(.callout)
            }
        }
        .onChange(of: year1RothConversion) { _, _ in onCommit() }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Compact capsule showing the off-plan status, tinted by severity.
struct OffPlanBadge: View {
    let status: OffPlanStatus
    var body: some View {
        Text(status.label)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(tint, in: Capsule())
    }
    private var tint: Color {
        switch status.severity {
        case .good:    return Color.Semantic.greenTint
        case .caution: return Color.Semantic.amberTint
        case .warning: return Color.Semantic.redTint
        }
    }
}
