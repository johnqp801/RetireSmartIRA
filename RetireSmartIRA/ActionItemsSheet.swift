//
//  ActionItemsSheet.swift
//  RetireSmartIRA
//

import SwiftUI

struct ActionItemsSheet: View {
    let year: Int
    let rothAmount: Double
    let qcdAmount: Double
    let stockDonationAmount: Double
    let requiredRMDAmount: Double

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if rothAmount > 0 {
                        ActionItemRow(
                            year: year,
                            action: .roth,
                            title: "Roth Conversion — $\(Int(rothAmount).formatted())",
                            instruction: "Contact your custodian to convert from a Traditional IRA to a Roth IRA before Dec 31."
                        )
                    }
                    if qcdAmount > 0 {
                        ActionItemRow(
                            year: year,
                            action: .qcd,
                            title: "QCD — $\(Int(qcdAmount).formatted())",
                            instruction: "Direct distribution from your IRA to charity. Counts toward RMD; excluded from taxable income."
                        )
                    }
                    if stockDonationAmount > 0 {
                        ActionItemRow(
                            year: year,
                            action: .stockDonation,
                            title: "Stock Donation — $\(Int(stockDonationAmount).formatted())",
                            instruction: "Transfer appreciated shares to charity's brokerage account before Dec 31."
                        )
                    }
                    if requiredRMDAmount > 0 {
                        ActionItemRow(
                            year: year,
                            action: .rmd,
                            title: "Required RMD — $\(Int(requiredRMDAmount).formatted())",
                            instruction: "Required minimum distribution. Custodian usually handles this automatically; verify before Dec 31."
                        )
                    }
                } header: {
                    Text("Due by Dec 31, \(year)")
                }
            }
            .navigationTitle("Action Items")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ActionItemRow: View {
    let year: Int
    let action: ActionItemType
    let title: String
    let instruction: String

    @AppStorage private var isDone: Bool

    init(year: Int, action: ActionItemType, title: String, instruction: String) {
        self.year = year
        self.action = action
        self.title = title
        self.instruction = instruction
        self._isDone = AppStorage(wrappedValue: false, actionItemKey(year: year, action: action))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                isDone.toggle()
            } label: {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .foregroundColor(isDone ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(isDone)
                    .foregroundColor(isDone ? .secondary : .primary)
                Text(instruction)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
