import SwiftUI

/// Editable Year-1 Roth conversion for the Multi-Year Plan tab, with an off-plan badge and a
/// one-tap reset to the engine-optimal. Year-1 is the shared single-year scenario; this edits the
/// combined household Roth conversion (the only Year-1 lever the v2.0 optimizer honors).
///
/// Typing edits a LOCAL draft (instant); it commits to the shared model — which triggers the
/// recompute and the chart re-render — only after a brief pause, so keystrokes never wait on the
/// engine.
struct Year1EditorView: View {
    @Binding var year1RothConversion: Double
    let status: OffPlanStatus?
    var onCommit: () -> Void
    var onResetToOptimal: () -> Void

    @State private var draft: Double = 0
    @State private var commitTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This year").font(.headline)
                Spacer()
                if let status { OffPlanBadge(status: status) }
            }
            LabeledContent("Roth conversion this year") {
                TextField("0", value: $draft, format: .number)
                    .multilineTextAlignment(.trailing)
            }
            if let status, !status.isOnPlan {
                Text(status.caption).font(.caption).foregroundStyle(.secondary)
                Button("Reset to optimal", action: onResetToOptimal).font(.callout)
            }
        }
        .onAppear { draft = year1RothConversion }
        .onChange(of: year1RothConversion) { _, newValue in
            // External change (e.g., Reset or a recompute): sync the field; do not re-commit.
            if newValue != draft { draft = newValue }
        }
        .onChange(of: draft) { _, newValue in
            // Debounced commit: keystrokes touch only `draft`; the model write + recompute fire
            // ~0.4s after the user stops typing, so editing stays instant.
            commitTask?.cancel()
            commitTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled, year1RothConversion != newValue else { return }
                year1RothConversion = newValue
                onCommit()
            }
        }
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
