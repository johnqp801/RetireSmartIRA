import SwiftUI

struct TaxableAccountsSection: View {
    @Environment(DataManager.self) private var dataManager
    @State private var showingAdd = false
    @State private var editing: TaxableAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Taxable Accounts").font(.headline)
                Spacer()
                Button { showingAdd = true } label: {
                    Label("Add", systemImage: "plus.circle.fill").font(.callout)
                }
            }
            Text("Brokerage accounts, cash, muni ladders, taxable trusts, and other non-retirement assets.")
                .font(.caption).foregroundStyle(.secondary)

            if dataManager.taxableAccounts.isEmpty {
                Text("None entered").font(.callout).foregroundStyle(.secondary).padding(.vertical, 4)
            } else {
                ForEach(dataManager.taxableAccounts) { acct in
                    Button { editing = acct } label: { TaxableAccountRow(account: acct) }
                        .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { TaxableAccountEditor(existing: nil) }
        .sheet(item: $editing) { TaxableAccountEditor(existing: $0) }
    }
}

struct TaxableAccountRow: View {
    let account: TaxableAccount
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name.isEmpty ? "Untitled" : account.name).font(.body)
                Text(account.category.rawValue).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(account.balance, format: .currency(code: "USD").precision(.fractionLength(0)))
                if account.basisNeedsConfirmation {
                    Text("Confirm basis").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TaxableAccountEditor: View {
    @Environment(DataManager.self) private var dataManager
    @Environment(\.dismiss) private var dismiss
    let existing: TaxableAccount?

    @State private var draft: TaxableAccount
    @State private var showAdvanced = false

    init(existing: TaxableAccount?) {
        self.existing = existing
        _draft = State(initialValue: existing ?? TaxableAccount(name: "", balance: 0, costBasis: 0))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Name", text: $draft.name)
                    Picker("Owner", selection: $draft.owner) {
                        ForEach(Owner.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Type", selection: $draft.category) {
                        ForEach(TaxableAccountCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                Section {
                    currencyField("Balance", $draft.balance)
                    currencyField("Cost basis / amount invested", $draft.costBasis)
                    if draft.basisNeedsConfirmation {
                        Label("Confirm basis", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    percentField("Expected price growth, excluding income yield", $draft.expectedAppreciationRate)
                } footer: {
                    Text("Cost basis is used to estimate capital gains if this account is sold to pay expenses or conversion taxes. Dividends, interest, and tax-exempt income are entered under Advanced.")
                }
                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    percentField("Qualified dividend yield", $draft.qualifiedDividendYield)
                    percentField("Ordinary income yield (interest, non-qualified dividends)", $draft.ordinaryIncomeYield)
                    percentField("Tax-exempt (muni) yield", $draft.taxExemptYield)
                    percentField("Long-term capital gain distributions", $draft.realizedLongTermGainYield)
                    currencyField("Reserve (never spend below)", $draft.protectedAmount)
                    Toggle("Can be used for living expenses", isOn: $draft.availableForExpenses)
                    Toggle("Can be used to pay Roth conversion taxes", isOn: $draft.availableForConversionTaxes)
                }
            }
            .navigationTitle(existing == nil ? "Add Taxable Account" : "Edit Taxable Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        draft.basisNeedsConfirmation = false  // saving confirms the basis the user sees
        if let existing, let i = dataManager.taxableAccounts.firstIndex(where: { $0.id == existing.id }) {
            dataManager.taxableAccounts[i] = draft
        } else {
            dataManager.taxableAccounts.append(draft)
        }
        dataManager.saveAllData()
    }

    private func currencyField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number).multilineTextAlignment(.trailing)
        }
    }
    private func percentField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .percent).multilineTextAlignment(.trailing).frame(width: 90)
        }
    }
}
