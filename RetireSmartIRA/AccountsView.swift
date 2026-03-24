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

                        if dataManager.hasInheritedAccounts {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Inherited")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dataManager.totalInheritedBalance, format: .currency(code: "USD"))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(PlatformColor.systemBackground))
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
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
            .padding()
        }
        .background(Color(PlatformColor.systemGroupedBackground))
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

            if account.accountType.isInherited, let beneficiary = account.beneficiaryType {
                HStack(spacing: 8) {
                    Text(beneficiary.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())

                    if let year = account.yearOfInheritance {
                        Text("Inherited \(String(year))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemBackground))
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

    // Inherited IRA fields
    @State private var beneficiaryType: BeneficiaryType
    @State private var decedentRBDStatus: DecedentRBDStatus
    @State private var yearOfInheritance: String
    @State private var decedentBirthYear: String
    @State private var beneficiaryBirthYear: String
    @State private var minorChildMajorityYear: String
    @State private var showBeneficiaryGuide = false
    @State private var showDeleteConfirmation = false

    init(accountToEdit: IRAAccount? = nil) {
        self.accountToEdit = accountToEdit
        _name = State(initialValue: accountToEdit?.name ?? "")
        _accountType = State(initialValue: accountToEdit?.accountType ?? .traditionalIRA)
        _balance = State(initialValue: accountToEdit?.balance.formatted() ?? "")
        _institution = State(initialValue: accountToEdit?.institution ?? "")
        _owner = State(initialValue: accountToEdit?.owner ?? .primary)
        _beneficiaryType = State(initialValue: accountToEdit?.beneficiaryType ?? .nonEligibleDesignated)
        _decedentRBDStatus = State(initialValue: accountToEdit?.decedentRBDStatus ?? .beforeRBD)
        _yearOfInheritance = State(initialValue: accountToEdit?.yearOfInheritance.map { String($0) } ?? "")
        _decedentBirthYear = State(initialValue: accountToEdit?.decedentBirthYear.map { String($0) } ?? "")
        _beneficiaryBirthYear = State(initialValue: accountToEdit?.beneficiaryBirthYear.map { String($0) } ?? "")
        _minorChildMajorityYear = State(initialValue: accountToEdit?.minorChildMajorityYear.map { String($0) } ?? "")
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
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif

                    TextField("Institution (optional)", text: $institution)

                    Picker("Owner", selection: $owner) {
                        ForEach(Owner.allCases, id: \.self) { owner in
                            Text(owner.rawValue).tag(owner)
                        }
                    }
                }

                if accountType.isInherited {
                    Section("Inherited IRA Details") {
                        Picker("Beneficiary Type", selection: $beneficiaryType) {
                            ForEach(BeneficiaryType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }

                        DisclosureGroup("Which category am I?", isExpanded: $showBeneficiaryGuide) {
                            VStack(alignment: .leading, spacing: 12) {
                                beneficiaryCategoryRow(
                                    icon: "heart.fill",
                                    color: .pink,
                                    title: "Spouse",
                                    description: "You were married to the original account owner at the time of their death.",
                                    rule: "Eligible — Lifetime stretch distributions"
                                )
                                beneficiaryCategoryRow(
                                    icon: "figure.and.child.holdinghands",
                                    color: .blue,
                                    title: "Minor Child",
                                    description: "You are the decedent's child who had not yet reached age 21 at the time of their death.",
                                    rule: "Eligible — Stretch until age 21, then 10-year rule"
                                )
                                beneficiaryCategoryRow(
                                    icon: "accessibility",
                                    color: .purple,
                                    title: "Disabled Individual",
                                    description: "You meet the IRS definition of disabled under IRC §72(m)(7) — unable to engage in substantial gainful activity due to a medically determinable condition.",
                                    rule: "Eligible — Lifetime stretch distributions"
                                )
                                beneficiaryCategoryRow(
                                    icon: "cross.case.fill",
                                    color: .purple,
                                    title: "Chronically Ill Individual",
                                    description: "You are certified by a licensed healthcare practitioner as unable to perform at least 2 daily living activities for at least 90 days, or require substantial supervision due to cognitive impairment.",
                                    rule: "Eligible — Lifetime stretch distributions"
                                )
                                beneficiaryCategoryRow(
                                    icon: "calendar.badge.clock",
                                    color: .teal,
                                    title: "Not >10 Years Younger",
                                    description: "You are not more than 10 years younger than the deceased account owner. Example: the decedent was born in 1950 and you were born in 1945–1960.",
                                    rule: "Eligible — Lifetime stretch distributions"
                                )
                                beneficiaryCategoryRow(
                                    icon: "clock.badge.exclamationmark",
                                    color: .orange,
                                    title: "Non-Eligible Designated",
                                    description: "You are a named beneficiary (person, not an entity) who does not fit any of the above categories. This is the most common category for adult children, siblings, friends, etc.",
                                    rule: "10-year rule — Must empty account within 10 years"
                                )
                            }
                            .padding(.top, 8)
                        }

                        TextField("Year Inherited *", text: $yearOfInheritance)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif

                        TextField("Decedent's Birth Year *", text: $decedentBirthYear)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif

                        TextField("Beneficiary's Birth Year *", text: $beneficiaryBirthYear)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif

                        if beneficiaryType == .nonEligibleDesignated {
                            Picker("Decedent RBD Status *", selection: $decedentRBDStatus) {
                                ForEach(DecedentRBDStatus.allCases, id: \.self) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                        }

                        if beneficiaryType == .minorChild {
                            TextField("Year Child Reaches Age 21 *", text: $minorChildMajorityYear)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                        }

                        Text("* Required for RMD calculations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        inheritedInfoText
                    } header: {
                        Text("Rule Summary")
                    }
                }

                // Delete button — only visible when editing an existing account
                if accountToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Account", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(accountToEdit == nil ? "Add Account" : "Edit Account")
            #if os(iOS)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #endif
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
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let account = accountToEdit,
                       let index = dataManager.iraAccounts.firstIndex(where: { $0.id == account.id }) {
                        dataManager.iraAccounts.remove(at: index)
                        dataManager.saveAllData()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this account? This cannot be undone.")
            }
        }
    }
    
    /// Summary text describing the withdrawal rule for the selected beneficiary type
    private var inheritedInfoText: some View {
        let text: String
        switch beneficiaryType {
        case .spouse:
            text = "Spouse beneficiaries can stretch distributions over their lifetime using the IRS Single Life Expectancy table, recalculated annually."
        case .minorChild:
            text = "Minor children can stretch distributions using the SLE table until age 21, then the 10-year rule begins."
        case .disabled:
            text = "Disabled beneficiaries qualify for lifetime stretch distributions using the SLE table."
        case .chronicallyIll:
            text = "Chronically ill beneficiaries qualify for lifetime stretch distributions using the SLE table."
        case .notTenYearsYounger:
            text = "Beneficiaries not more than 10 years younger than the decedent can stretch distributions over their lifetime."
        case .nonEligibleDesignated:
            if decedentRBDStatus == .afterRBD {
                text = "Non-eligible beneficiaries must take annual RMDs (years 1-9) and empty the account by the end of year 10."
            } else {
                text = "Non-eligible beneficiaries have no annual RMD requirement but must empty the account by the end of year 10."
            }
        }
        return Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Displays a single beneficiary category row with icon, title, description, and rule.
    private func beneficiaryCategoryRow(icon: String, color: Color, title: String, description: String, rule: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(rule)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(rule.hasPrefix("Eligible") ? .green : .orange)
            }
        }
    }

    /// Validates and persists the IRA account form data.
    private func saveAccount() {
        let cleanBalance = balance.replacingOccurrences(of: ",", with: "")

        guard let balanceValue = Double(cleanBalance) else {
            print("ERROR: Cannot convert balance to Double: '\(balance)'")
            return
        }

        // Parse inherited IRA fields if applicable
        let inheritedBeneficiary: BeneficiaryType? = accountType.isInherited ? beneficiaryType : nil
        let inheritedRBDStatus: DecedentRBDStatus? = (accountType.isInherited && beneficiaryType == .nonEligibleDesignated) ? decedentRBDStatus : nil
        let inheritedYear: Int? = accountType.isInherited ? Int(yearOfInheritance) : nil
        let decedentBY: Int? = accountType.isInherited ? Int(decedentBirthYear) : nil
        let beneficiaryBY: Int? = accountType.isInherited ? Int(beneficiaryBirthYear) : nil
        let majorityYear: Int? = (accountType.isInherited && beneficiaryType == .minorChild) ? Int(minorChildMajorityYear) : nil

        if let existingAccount = accountToEdit,
           let index = dataManager.iraAccounts.firstIndex(where: { $0.id == existingAccount.id }) {
            dataManager.iraAccounts[index] = IRAAccount(
                id: existingAccount.id,
                name: name,
                accountType: accountType,
                balance: balanceValue,
                institution: institution,
                owner: owner,
                beneficiaryType: inheritedBeneficiary,
                decedentRBDStatus: inheritedRBDStatus,
                yearOfInheritance: inheritedYear,
                decedentBirthYear: decedentBY,
                beneficiaryBirthYear: beneficiaryBY,
                minorChildMajorityYear: majorityYear
            )
        } else {
            let newAccount = IRAAccount(
                name: name,
                accountType: accountType,
                balance: balanceValue,
                institution: institution,
                owner: owner,
                beneficiaryType: inheritedBeneficiary,
                decedentRBDStatus: inheritedRBDStatus,
                yearOfInheritance: inheritedYear,
                decedentBirthYear: decedentBY,
                beneficiaryBirthYear: beneficiaryBY,
                minorChildMajorityYear: majorityYear
            )
            dataManager.iraAccounts.append(newAccount)
        }

        dataManager.saveAllData()
        dismiss()
    }
}
