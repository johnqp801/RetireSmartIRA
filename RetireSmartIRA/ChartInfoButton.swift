import SwiftUI

/// A quiet ⓘ affordance that presents a chart's plain-language explanation in a popover.
/// Reused by every Multi-Year chart header. Presentational only; the text comes from the
/// chart model's deterministic `commentary` (see ChartCommentary+Models).
struct ChartInfoButton: View {
    let commentary: ChartCommentary
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Explain this chart")
        .accessibilityHint(commentary.body)
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(commentary.title).font(.headline)
                Text(commentary.body).font(.callout).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 320, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
}
