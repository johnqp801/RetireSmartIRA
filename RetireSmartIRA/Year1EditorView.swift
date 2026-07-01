import SwiftUI

/// Editable Year-1 Roth conversion for the Multi-Year Plan tab, with an off-plan badge and a
/// one-tap reset to the engine-optimal. Year-1 is the shared single-year scenario; this edits the
/// combined household Roth conversion (the only Year-1 lever the v2.0 optimizer honors).
///
/// The field is a plain String input backed by local state: a keystroke only appends to that string
/// (no live number-reformatting, no model write, no recompute). It parses + commits to the shared
/// model ~0.4s after the user stops typing, so editing is buttery and the engine work happens once
/// the user pauses.
struct Year1EditorView: View {
    /// The user's explicit override for this year (0 = no override, follow the plan).
    @Binding var year1RothConversion: Double
    /// What the modeled plan actually converts in Year 1. Shown in the field so it agrees with
    /// the ladder/chart instead of displaying a bare 0 when there is no override.
    let plannedYear1: Double
    let status: OffPlanStatus?
    var onCommit: () -> Void
    var onResetToOptimal: () -> Void

    @State private var text: String = ""
    @State private var commitTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This year").font(.headline)
                Spacer()
                if let status { OffPlanBadge(status: status) }
            }
            LabeledContent("Roth conversion this year") {
                TextField("0", text: $text)
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            if year1RothConversion == 0 {
                Text("Following the modeled plan. Enter an amount to set your own conversion for this year.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                if let status, !status.isOnPlan {
                    Text(status.caption).font(.caption).foregroundStyle(.secondary)
                }
                Button("Reset to optimal", action: onResetToOptimal).font(.callout)
            }
        }
        // The field displays the plan's Year-1 amount (so it agrees with the ladder/chart). When
        // there is no override it shows what the engine chose; when overridden it shows the pinned
        // value (the plan's Year-1 equals the override once pinned).
        .onAppear { text = Self.string(from: plannedYear1) }
        .onChange(of: plannedYear1) { _, newValue in
            // Plan recomputed (or Reset): sync the field to the new modeled amount; do not re-commit.
            if Self.parse(text) != newValue { text = Self.string(from: newValue) }
        }
        .onChange(of: text) { _, newValue in
            // Debounced commit: keystrokes only mutate `text`; the model write + recompute fire
            // ~0.4s after the user stops typing.
            let parsed = Self.parse(newValue)
            commitTask?.cancel()
            commitTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                // Editing to the plan's own Year-1 amount clears the override (follow the plan);
                // any other value is an explicit override. This also makes the on-appear sync
                // (text := plannedYear1) a no-op rather than a spurious override.
                let target = abs(parsed - plannedYear1) < 1 ? 0 : parsed
                guard year1RothConversion != target else { return }
                year1RothConversion = target
                onCommit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Plain whole-dollar string (no grouping) so typing never triggers a live reformat.
    private static func string(from value: Double) -> String {
        value == 0 ? "" : String(Int(value.rounded()))
    }

    /// Parse digits only (tolerant of any separators the user pastes).
    private static func parse(_ s: String) -> Double {
        Double(s.filter { $0.isNumber }) ?? 0
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
