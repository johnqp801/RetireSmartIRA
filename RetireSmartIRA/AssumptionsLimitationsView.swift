import SwiftUI

/// Always-available honest-scope section: the positioning line plus a disclosable list of what
/// V2.0 simplifies. Pulls copy from V2Disclosures so the UI and the CPA PDF stay in sync.
struct AssumptionsLimitationsView: View {
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this plan covers").font(.headline)
            Text(V2Disclosures.positioning).font(.callout).foregroundStyle(.secondary)
            DisclosureGroup("Assumptions & limitations", isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(V2Disclosures.limitations, id: \.self) { item in
                        Label(item, systemImage: "info.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
