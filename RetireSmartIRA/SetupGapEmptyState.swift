import SwiftUI

struct SetupGapEmptyState: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var selectedTab: Int

    private var gaps: [Gap] {
        var list: [Gap] = []
        if dataManager.iraAccounts.isEmpty {
            list.append(Gap(label: "IRA account balances", deepLinkTab: 3, tabName: "Accounts"))
        }
        if dataManager.primarySSBenefit == nil {
            list.append(Gap(label: "Social Security plan", deepLinkTab: 9, tabName: "Social Security"))
        }
        return list
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Set up your data first")
                .font(.title3.weight(.semibold))
            Text("Multi-year strategy needs:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(gaps, id: \.label) { gap in
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                        Text(gap.label)
                        Spacer()
                        Button("Go to \(gap.tabName)") {
                            selectedTab = gap.deepLinkTab
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .padding()
    }

    private struct Gap {
        let label: String
        let deepLinkTab: Int
        let tabName: String
    }
}
