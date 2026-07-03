import SwiftUI

/// Dismissible banner highlighting the pre-RMD window, when Roth conversions are most flexible.
struct ConversionWindowBanner: View {
    let yearsBeforeFirstRMD: Int?
    @Binding var dismissed: Bool

    static func shouldShow(yearsBeforeFirstRMD: Int?, dismissed: Bool) -> Bool {
        guard !dismissed, let y = yearsBeforeFirstRMD else { return false }
        return y > 0
    }

    var body: some View {
        if let y = yearsBeforeFirstRMD, Self.shouldShow(yearsBeforeFirstRMD: yearsBeforeFirstRMD, dismissed: dismissed) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "hourglass").foregroundStyle(Color.Semantic.green)
                    Text("Conversion opportunity window").font(.headline)
                    Spacer()
                    Button { dismissed = true } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }.buttonStyle(.plain)
                }
                Text("You have about \(y) year\(y == 1 ? "" : "s") before required minimum distributions begin. These pre-RMD years are often the best window for Roth conversions, while you have the most control over your taxable income.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding().background(Color.Semantic.greenTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
