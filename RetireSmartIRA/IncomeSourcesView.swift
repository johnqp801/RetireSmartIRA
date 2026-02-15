//
//  IncomeSourcesView.swift
//  RetireSmartIRA
//
//  Manage income sources and itemized deductions for tax calculations
//

import SwiftUI

struct IncomeSourcesView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAddIncome = false
    @State private var selectedIncomeSource: IncomeSource?
    @State private var showingAddDeduction = false
    @State private var selectedDeduction: DeductionItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Total Income Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Annual Income")
                        .font(.headline)

                    Text(dataManager.totalAnnualIncome(), format: .currency(code: "USD"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

                // Income Sources List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Income Sources")
                            .font(.headline)

                        Spacer()

                        Button(action: { showingAddIncome = true }) {
                            Label("Add Income", systemImage: "plus.circle.fill")
                                .font(.callout)
                        }
                    }

                    if dataManager.incomeSources.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            Text("No income sources yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Add your income sources to calculate taxes")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: { showingAddIncome = true }) {
                                Text("Add Income Source")
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
                        ForEach(dataManager.incomeSources) { source in
                            IncomeRow(source: source)
                                .onTapGesture {
                                    selectedIncomeSource = source
                                    showingAddIncome = true
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if let index = dataManager.incomeSources.firstIndex(where: { $0.id == source.id }) {
                                            dataManager.incomeSources.remove(at: index)
                                            dataManager.saveAllData()
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

                // MARK: - Deductions Section

                // Standard vs Itemized Comparison Card
                deductionComparisonCard

                // Itemized Deductions List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Itemized Deductions")
                            .font(.headline)

                        Spacer()

                        Button(action: { showingAddDeduction = true }) {
                            Label("Add Deduction", systemImage: "plus.circle.fill")
                                .font(.callout)
                        }
                    }

                    if dataManager.deductionItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)

                            Text("No itemized deductions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Add mortgage interest, property tax, and other deductions to compare against the standard deduction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    } else {
                        ForEach(dataManager.deductionItems) { item in
                            DeductionRow(item: item)
                                .onTapGesture {
                                    selectedDeduction = item
                                    showingAddDeduction = true
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if let index = dataManager.deductionItems.firstIndex(where: { $0.id == item.id }) {
                                            dataManager.deductionItems.remove(at: index)
                                            dataManager.saveAllData()
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }

                    // Medical deduction threshold note
                    if dataManager.totalMedicalExpenses > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "cross.case.fill")
                                    .foregroundStyle(.red)
                                Text("Medical Deduction")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Total Medical Expenses")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dataManager.totalMedicalExpenses, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                HStack {
                                    Text("7.5% of AGI Floor")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("−\(dataManager.medicalAGIFloor.formatted(.currency(code: "USD")))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.red)
                                }
                                Divider()
                                HStack {
                                    Text("Deductible Amount")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(dataManager.deductibleMedicalExpenses, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(dataManager.deductibleMedicalExpenses > 0 ? .green : .secondary)
                                }
                            }

                            Text("Only medical expenses exceeding 7.5% of your adjusted gross income are deductible. Enter total expenses — the app calculates the deductible portion automatically.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Note about charitable deductions
                    if dataManager.scenarioTotalCharitable > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("Charitable contributions of \(dataManager.scenarioTotalCharitable.formatted(.currency(code: "USD"))) from Scenarios are included in your itemized total.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .sheet(isPresented: $showingAddIncome, onDismiss: {
            selectedIncomeSource = nil
        }) {
            AddIncomeView(incomeToEdit: selectedIncomeSource)
        }
        .sheet(isPresented: $showingAddDeduction, onDismiss: {
            selectedDeduction = nil
        }) {
            AddDeductionView(deductionToEdit: selectedDeduction)
        }
    }

    // MARK: - Deduction Comparison Card

    private var deductionComparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deduction Comparison")
                .font(.headline)

            HStack(spacing: 16) {
                // Standard
                VStack(spacing: 8) {
                    Text("Standard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dataManager.standardDeductionAmount, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                    if !dataManager.scenarioEffectiveItemize {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((!dataManager.scenarioEffectiveItemize ? Color.green.opacity(0.1) : Color(.secondarySystemBackground)))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Itemized
                VStack(spacing: 8) {
                    Text("Itemized")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dataManager.totalItemizedDeductions, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                    if dataManager.scenarioEffectiveItemize {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((dataManager.scenarioEffectiveItemize ? Color.green.opacity(0.1) : Color(.secondarySystemBackground)))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Override control
            HStack {
                Text("Deduction Method")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: {
                        if let override = dataManager.deductionOverride {
                            return override == .standard ? 0 : 2
                        }
                        return 1 // auto
                    },
                    set: { newValue in
                        switch newValue {
                        case 0: dataManager.deductionOverride = .standard
                        case 2: dataManager.deductionOverride = .itemized
                        default: dataManager.deductionOverride = nil // auto
                        }
                        dataManager.saveAllData()
                    }
                )) {
                    Text("Standard").tag(0)
                    Text("Auto").tag(1)
                    Text("Itemized").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            if dataManager.deductionOverride == nil {
                Text("Auto-selecting \(dataManager.recommendedDeductionType == .itemized ? "itemized" : "standard") deduction (\(dataManager.effectiveDeductionAmount.formatted(.currency(code: "USD"))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Supporting Views

    struct IncomeRow: View {
        let source: IncomeSource

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(source.name)
                                .font(.callout)
                                .fontWeight(.semibold)

                            Text(source.owner.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ownerColor.opacity(0.2))
                                .foregroundStyle(ownerColor)
                                .clipShape(Capsule())
                        }

                        Text(source.type.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(source.annualAmount, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                }

                if source.taxWithholding > 0 {
                    HStack {
                        Text("Withholding:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(source.taxWithholding, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        var ownerColor: Color {
            switch source.owner {
            case .primary: return .blue
            case .spouse: return .purple
            case .joint: return .green
            }
        }
    }

    struct DeductionRow: View {
        let item: DeductionItem

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text(item.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.annualAmount, format: .currency(code: "USD"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Add/Edit Income

    struct AddIncomeView: View {
        @EnvironmentObject var dataManager: DataManager
        @Environment(\.dismiss) var dismiss
        var incomeToEdit: IncomeSource?

        @State private var name: String
        @State private var incomeType: IncomeType
        @State private var annualAmount: String
        @State private var taxWithholding: String
        @State private var owner: Owner

        init(incomeToEdit: IncomeSource? = nil) {
            self.incomeToEdit = incomeToEdit
            _name = State(initialValue: incomeToEdit?.name ?? "")
            _incomeType = State(initialValue: incomeToEdit?.type ?? .socialSecurity)
            _annualAmount = State(initialValue: incomeToEdit?.annualAmount.formatted() ?? "")
            _taxWithholding = State(initialValue: incomeToEdit?.taxWithholding.formatted() ?? "")
            _owner = State(initialValue: incomeToEdit?.owner ?? .primary)
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section("Income Details") {
                        TextField("Description", text: $name)

                        Picker("Income Type", selection: $incomeType) {
                            ForEach(IncomeType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }

                        TextField("Annual Amount", text: $annualAmount)
                            .keyboardType(.decimalPad)

                        TextField("Tax Withholding (optional)", text: $taxWithholding)
                            .keyboardType(.decimalPad)

                        Picker("Owner", selection: $owner) {
                            ForEach(Owner.allCases, id: \.self) { owner in
                                Text(owner.rawValue).tag(owner)
                            }
                        }
                    }
                }
                .navigationTitle(incomeToEdit == nil ? "Add Income" : "Edit Income")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveIncome() }
                            .disabled(name.isEmpty || annualAmount.isEmpty)
                    }
                }
            }
        }

        private func saveIncome() {
            let cleanAmount = annualAmount.replacingOccurrences(of: ",", with: "")
            let cleanWithholding = taxWithholding.replacingOccurrences(of: ",", with: "")
            guard let amount = Double(cleanAmount) else { return }
            let withholding = Double(cleanWithholding) ?? 0

            if let existing = incomeToEdit,
               let index = dataManager.incomeSources.firstIndex(where: { $0.id == existing.id }) {
                dataManager.incomeSources[index] = IncomeSource(
                    id: existing.id, name: name, type: incomeType,
                    annualAmount: amount, taxWithholding: withholding, owner: owner
                )
            } else {
                dataManager.incomeSources.append(IncomeSource(
                    name: name, type: incomeType,
                    annualAmount: amount, taxWithholding: withholding, owner: owner
                ))
            }
            dataManager.saveAllData()
            dismiss()
        }
    }

    // MARK: - Add/Edit Deduction

    struct AddDeductionView: View {
        @EnvironmentObject var dataManager: DataManager
        @Environment(\.dismiss) var dismiss
        var deductionToEdit: DeductionItem?

        @State private var name: String
        @State private var deductionType: DeductionType
        @State private var annualAmount: String
        @State private var owner: Owner

        init(deductionToEdit: DeductionItem? = nil) {
            self.deductionToEdit = deductionToEdit
            _name = State(initialValue: deductionToEdit?.name ?? "")
            _deductionType = State(initialValue: deductionToEdit?.type ?? .mortgageInterest)
            _annualAmount = State(initialValue: deductionToEdit?.annualAmount.formatted() ?? "")
            _owner = State(initialValue: deductionToEdit?.owner ?? .primary)
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section("Deduction Details") {
                        TextField("Description", text: $name)

                        Picker("Type", selection: $deductionType) {
                            ForEach(DeductionType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }

                        TextField("Annual Amount", text: $annualAmount)
                            .keyboardType(.decimalPad)

                        Picker("Owner", selection: $owner) {
                            ForEach(Owner.allCases, id: \.self) { owner in
                                Text(owner.rawValue).tag(owner)
                            }
                        }
                    }

                    if deductionType == .medicalExpenses {
                        Section("About Medical Deductions") {
                            Text("Enter your total unreimbursed medical expenses (insurance premiums, copays, prescriptions, dental, vision, long-term care, etc.). Only the amount exceeding 7.5% of your adjusted gross income (AGI) is deductible. The app calculates this automatically.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle(deductionToEdit == nil ? "Add Deduction" : "Edit Deduction")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveDeduction() }
                            .disabled(name.isEmpty || annualAmount.isEmpty)
                    }
                }
            }
        }

        private func saveDeduction() {
            let cleanAmount = annualAmount.replacingOccurrences(of: ",", with: "")
            guard let amount = Double(cleanAmount) else { return }

            if let existing = deductionToEdit,
               let index = dataManager.deductionItems.firstIndex(where: { $0.id == existing.id }) {
                dataManager.deductionItems[index] = DeductionItem(
                    id: existing.id, name: name, type: deductionType,
                    annualAmount: amount, owner: owner
                )
            } else {
                dataManager.deductionItems.append(DeductionItem(
                    name: name, type: deductionType,
                    annualAmount: amount, owner: owner
                ))
            }
            dataManager.saveAllData()
            dismiss()
        }
    }
}
