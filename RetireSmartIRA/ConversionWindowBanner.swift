import SwiftUI

/// Dismissible banner about the pre-RMD window, when Roth conversions are most flexible.
///
/// The wording, and the decision to say anything at all, live in
/// `RMDStatusPresentation.multiYearBanner`: the banner used to build its own
/// sentence from a primary-only countdown, which is how it came to promise an
/// open window to a household whose spouse was already taking distributions.
struct ConversionWindowBanner: View {
    let content: RMDStatusPresentation.MultiYearBanner?
    @Binding var dismissed: Bool

    static func shouldShow(content: RMDStatusPresentation.MultiYearBanner?, dismissed: Bool) -> Bool {
        !dismissed && content != nil
    }

    var body: some View {
        if let content, Self.shouldShow(content: content, dismissed: dismissed) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: content.isOpen ? "hourglass" : "hourglass.bottomhalf.filled")
                        .foregroundStyle(content.isOpen ? Color.Semantic.green : Color.Semantic.amber)
                    Text(content.title).font(.headline)
                    Spacer()
                    Button { dismissed = true } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
                Text(content.message)
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding()
            // Amber is this app's "action required" tint. A household already
            // taking distributions is not looking at an opportunity, so the
            // closed case must not be painted as one.
            .background(content.isOpen ? Color.Semantic.greenTint : Color.Semantic.amberTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
