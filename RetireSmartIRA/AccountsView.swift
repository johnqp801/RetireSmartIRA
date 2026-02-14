//
//  AccountsView.swift
//  RetireSmartIRA
//
//  Manage IRA and 401(k) accounts
//

import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddAccount = false
    @State private var selectedAccount: IRAAccount?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Total Balance Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total IRA Balance")
                        .font(.headline)
                    
                    HStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Traditional")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(dataManager.totalTraditionalIRABalance, format: .currency(code: "USD"))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Roth")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(dataManager.totalRothBalance, format: .currency(code: "USD"))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                
                // Accounts List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Accounts")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showingAddAccount = true }) {
                            Label("Add Account", systemImage: "plus.circle.fill")
                                .font(.callout)
                        }
                    }
                    
                    if dataManager.iraAccounts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "building.columns")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            
                            Text("No accounts yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Text("Add your IRA and 401(k) accounts to calculate RMDs")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { showingAddAccount = true }) {
                                Text("Add Account")
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        ForEach(dataManager.iraAccounts) { account in
                            AccountRow(account: account)
                                .onTapGesture {
                                    selectedAccount = account
                                    showingAddAccount = true
                                }
                        }
                        .onDelete(perform: deleteAccounts)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingAddAccount, onDismiss: {
            selectedAccount = nil
        }) {
            AddAccountView(accountToEdit: selectedAccount)
        }
    }
    
    private func deleteAccounts(at offsets: IndexSet) {
        dataManager.iraAccounts.remove(atOffsets: offsets)
        dataManager.saveAllData()
    }
}

struct AccountRow: View {
    let account: IRAAccount
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(account.name)
                            .font(.callout)
                            .fontWeight(.semibold)
                        
                        // Owner tag
                        Text(account.owner.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ownerColor.opacity(0.2))
                            .foregroundStyle(ownerColor)
                            .clipShape(Capsule())
                    }
                    
                    Text(account.accountType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(account.balance, format: .currency(code: "USD"))
                    .font(.title3)
                    .fontWeight(.bold)
            }
            
            if !account.institution.isEmpty {
                Text(account.institution)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    var ownerColor: Color {
        switch account.owner {
        case .primary: return .blue
        case .spouse: return .purple
        case .joint: return .green
        }
    }
}

struct AddAccountView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var accountToEdit: IRAAccount?
    
    @State private var name: String
    @State private var accountType: AccountType
    @State private var balance: String
    @State private var institution: String
    @State private var owner: Owner
    
    init(accountToEdit: IRAAccount? = nil) {
        self.accountToEdit = accountToEdit
        _name = State(initialValue: accountToEdit?.name ?? "")
        _accountType = State(initialValue: accountToEdit?.accountType ?? .traditionalIRA)
        _balance = State(initialValue: accountToEdit?.balance.formatted() ?? "")
        _institution = State(initialValue: accountToEdit?.institution ?? "")
        _owner = State(initialValue: accountToEdit?.owner ?? .primary)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $name)
                    
                    Picker("Account Type", selection: $accountType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    TextField("Balance", text: $balance)
                        .keyboardType(.decimalPad)
                    
                    TextField("Institution (optional)", text: $institution)
                    
                    Picker("Owner", selection: $owner) {
                        ForEach(Owner.allCases, id: \.self) { owner in
                            Text(owner.rawValue).tag(owner)
                        }
                    }
                }
            }
            .navigationTitle(accountToEdit == nil ? "Add Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccount()
                    }
                    .disabled(name.isEmpty || balance.isEmpty)
                }
            }
        }
    }
    
    /// Validates and persists the IRA account form data.
    ///
    /// Strips commas from the balance string and converts it to a `Double`.
    /// If `accountToEdit` is set, the existing account is updated in place;
    /// otherwise a new `IRAAccount` is appended to `dataManager.iraAccounts`.
    /// Dismisses the view on success. Logs an error and returns early if the
    /// balance cannot be parsed.
    private func saveAccount() {
        let cleanBalance = balance.replacingOccurrences(of: ",", with: "")
        
        guard let balanceValue = Double(cleanBalance) else {
            print("ERROR: Cannot convert balance to Double: '\(balance)'")
            return
        }
        
        if let existingAccount = accountToEdit,
           let index = dataManager.iraAccounts.firstIndex(where: { $0.id == existingAccount.id }) {
            dataManager.iraAccounts[index] = IRAAccount(
                id: existingAccount.id,
                name: name,
                accountType: accountType,
                balance: balanceValue,
                institution: institution,
                owner: owner
            )
        } else {
            let newAccount = IRAAccount(
                name: name,
                accountType: accountType,
                balance: balanceValue,
                institution: institution,
                owner: owner
            )
            dataManager.iraAccounts.append(newAccount)
        }

        dataManager.saveAllData()
        dismiss()
    }
}
