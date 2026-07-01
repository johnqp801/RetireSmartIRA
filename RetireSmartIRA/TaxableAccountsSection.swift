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
                    TextField("Balance", value: $draft.balance, format: .number)
                    TextField("Cost basis", value: $draft.costBasis, format: .number)
                    if draft.basisNeedsConfirmation {
                        Label("Confirm basis", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    TextField("Price growth (excludes yield)", value: $draft.expectedAppreciationRate, format: .percent)
                } header: {
                    Text("Balances")
                } footer: {
                    Text("Balance is the account's current value. Cost basis is your amount invested; it estimates capital gains if the account is sold to fund expenses or conversion taxes. Price growth is yearly appreciation as a percent of the balance, separate from the income yields under Advanced.")
                }
                Section {
                    TextField("Qualified dividend yield", value: $draft.qualifiedDividendYield, format: .percent)
                    TextField("Ordinary income yield", value: $draft.ordinaryIncomeYield, format: .percent)
                    TextField("Tax-exempt (muni) yield", value: $draft.taxExemptYield, format: .percent)
                    TextField("Capital gain distributions", value: $draft.realizedLongTermGainYield, format: .percent)
                    TextField("Reserve (keep at least)", value: $draft.protectedAmount, format: .number)
                    Toggle("Use for living expenses", isOn: $draft.availableForExpenses)
                    Toggle("Use to pay Roth conversion taxes", isOn: $draft.availableForConversionTaxes)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Each yield is annual income as a percent of this account's balance. Example: a $4M account at 2% qualified dividend yield produces about $80,000 a year. Ordinary income yield covers interest and non-qualified dividends. Reserve is a dollar amount the account never drops below when funding the plan.")
                }
                if let existing {
                    Section {
                        Button("Delete Account", role: .destructive) {
                            dataManager.removeTaxableAccount(id: existing.id)
                            dismiss()
                        }
                    }
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
}
