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
                        .foregroundStyle(Color.UI.textPrimary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(PlatformColor.systemBackground))
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
                                    .background(Color.UI.brandTeal)
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
                .background(Color(PlatformColor.systemBackground))
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
                                    .foregroundStyle(Color.UI.brandTeal)
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
                                    Text("7.5% of AGI Floor (\(dataManager.estimatedAGI.formatted(.currency(code: "USD"))))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("−\(dataManager.medicalAGIFloor.formatted(.currency(code: "USD")))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.UI.textPrimary)
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
                                        .foregroundStyle(dataManager.deductibleMedicalExpenses > 0 ? Color.UI.textPrimary : Color.UI.textSecondary)
                                }
                            }

                            Text("Only medical expenses exceeding 7.5% of your adjusted gross income (AGI) are deductible. AGI is estimated from your entered income sources and Scenario decisions. If you have above-the-line deductions (HSA, IRA contributions), your actual AGI may be slightly lower.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.UI.surfaceInset)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Prior Year State Tax Balance
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(Color.UI.brandTeal)
                            Text("\(dataManager.priorPlanYear, format: .number.grouping(.never)) State Tax Balance")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Balance Due Paid (or Refund)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0", value: $dataManager.priorYearStateBalance, format: .currency(code: "USD"))
                                .font(.caption)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                #if os(iOS)
                                .keyboardType(.numbersAndPunctuation)
                                #endif
                                .onChange(of: dataManager.priorYearStateBalance) {
                                    dataManager.saveAllData()
                                }
                        }

                        if dataManager.priorYearStateBalance > 0 {
                            Text("The balance due you paid with your \(dataManager.priorPlanYear, format: .number.grouping(.never)) state return is included in your SALT deduction.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if dataManager.priorYearStateBalance < 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.Semantic.amber)
                                    .font(.caption2)
                                Text("A state tax refund may be taxable on your federal return if you itemized in \(dataManager.priorPlanYear, format: .number.grouping(.never)). Consider adding a \u{201C}State Tax Refund\u{201D} income source for \(abs(dataManager.priorYearStateBalance).formatted(.currency(code: "USD"))).")
                                    .font(.caption2)
                                    .foregroundStyle(Color.Semantic.amber)
                            }
                        }

                        Text("Enter the amount you paid with your \(dataManager.priorPlanYear, format: .number.grouping(.never)) state tax return (positive for balance due paid, negative for refund received).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.UI.surfaceInset)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // SALT cap note
                    if dataManager.totalSALTBeforeCap > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "building.columns.fill")
                                    .foregroundStyle(Color.UI.brandTeal)
                                Text("SALT Deduction Cap")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            // Component breakdown
                            VStack(alignment: .leading, spacing: 4) {
                                if dataManager.propertyTaxAmount > 0 {
                                    HStack {
                                        Text("Property Tax")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(dataManager.propertyTaxAmount, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                if dataManager.totalStateWithholding > 0 {
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text("State Withholding")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("(from income sources)")
                                                .font(.caption2)
                                                .foregroundStyle(Color.UI.textSecondary)
                                        }
                                        Spacer()
                                        Text(dataManager.totalStateWithholding, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                if dataManager.priorYearSALTDeductible > 0 {
                                    HStack {
                                        Text("\(dataManager.priorPlanYear, format: .number.grouping(.never)) Balance Due")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(dataManager.priorYearSALTDeductible, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                if dataManager.additionalSALTAmount > 0 {
                                    HStack {
                                        Text("Additional SALT")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(dataManager.additionalSALTAmount, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }
                                if dataManager.autoEstimatedStatePayments > 0 {
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text("Est. State Tax Payments")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text("(auto-calculated for \(dataManager.planYear, format: .number.grouping(.never)))")
                                                .font(.caption2)
                                                .foregroundStyle(Color.UI.textSecondary)
                                        }
                                        Spacer()
                                        Text(dataManager.autoEstimatedStatePayments, format: .currency(code: "USD"))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                }

                                Divider()

                                HStack {
                                    Text("Total SALT Before Cap")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dataManager.totalSALTBeforeCap, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                HStack {
                                    Text("Federal Cap")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(dataManager.saltCap, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(dataManager.totalSALTBeforeCap > dataManager.saltCap ? Color.UI.textPrimary : Color.UI.textSecondary)
                                }
                                Divider()
                                HStack {
                                    Text("Deductible Amount")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(dataManager.saltAfterCap, format: .currency(code: "USD"))
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(dataManager.totalSALTBeforeCap > dataManager.saltCap ? Color.Semantic.amber : Color.UI.textPrimary)
                                }
                            }

                            // Double-count warning
                            if dataManager.additionalSALTAmount > 0 && dataManager.totalStateWithholding > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(Color.Semantic.amber)
                                        .font(.caption2)
                                    Text("State withholding is now auto-included. If your \u{201C}State & Local Tax\u{201D} entries include withholding amounts, remove them to avoid double-counting.")
                                        .font(.caption2)
                                        .foregroundStyle(Color.Semantic.amber)
                                }
                            }

                            Text("SALT deductions \u{2014} property tax, state withholding, prior year balance due, and local taxes \u{2014} are capped at \(dataManager.saltCap.formatted(.currency(code: "USD").precision(.fractionLength(0)))) for \(String(dataManager.currentYear)) under the OBBBA. State withholding from your income sources and prior year balance due are included automatically. If you received a state tax refund and itemized last year, enter it as a \u{201C}State Tax Refund\u{201D} income source \u{2014} it\u{2019}s taxable on your federal return.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if dataManager.stateHasIncomeTax {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gearshape.2.fill")
                                            .foregroundStyle(Color.UI.brandTeal)
                                            .font(.caption2)
                                        Text("Smart SALT: Estimated State Payments")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color.UI.brandTeal)
                                    }
                                    Text("The estimated state income tax you\u{2019}ll pay during \(String(dataManager.currentYear)) is deductible as SALT on your federal return. RetireSmart IRA automatically calculates this amount based on your income, accounts, and scenario decisions \u{2014} and includes it in your SALT total above. As you complete each tab (Social Security, Income, Accounts, Scenarios), this number updates automatically. No manual entry needed.")
                                        .font(.caption2)
                                        .foregroundStyle(Color.UI.brandTeal.opacity(0.8))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.UI.surfaceInset)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Note about charitable deductions
                    if dataManager.scenarioTotalCharitable > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.UI.brandTeal)
                            Text("Charitable contributions of \(dataManager.scenarioTotalCharitable.formatted(.currency(code: "USD"))) from Scenarios are included in your itemized total.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.UI.surfaceInset)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((!dataManager.scenarioEffectiveItemize ? Color.UI.brandTeal.opacity(0.10) : Color(PlatformColor.secondarySystemBackground)))
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
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background((dataManager.scenarioEffectiveItemize ? Color.UI.brandTeal.opacity(0.10) : Color(PlatformColor.secondarySystemBackground)))
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
                Text("Auto compares your itemized total against the standard deduction and selects whichever saves you more — currently \(dataManager.recommendedDeductionType == .itemized ? "itemized" : "standard") (\(dataManager.effectiveDeductionAmount.formatted(.currency(code: "USD"))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text("Tip: Auto compares your itemized total against the standard deduction and selects whichever saves you more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Supporting Views

    struct IncomeRow: View {
        let source: IncomeSource

        private var isManagedBySSPlanner: Bool {
            source.type == .socialSecurity && source.name.hasSuffix("(SS Planner)")
        }

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

                        HStack(spacing: 6) {
                            Text(source.type.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if isManagedBySSPlanner {
                                HStack(spacing: 3) {
                                    Image(systemName: "link")
                                        .font(.caption2)
                                    Text("Managed by SS Planner")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.UI.brandTeal.opacity(0.10))
                                .foregroundStyle(Color.UI.brandTeal)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Text(source.annualAmount, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                }

                if source.federalWithholding > 0 || source.stateWithholding > 0 {
                    HStack(spacing: 8) {
                        Text("Withholding:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if source.federalWithholding > 0 {
                            Text("Fed \(source.federalWithholding, format: .currency(code: "USD"))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        if source.stateWithholding > 0 {
                            Text("State \(source.stateWithholding, format: .currency(code: "USD"))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        var ownerColor: Color {
            switch source.owner {
            case .primary: return Color.UI.brandTeal
            case .spouse: return Color.Chart.callout
            case .joint: return Color.Chart.gray2
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
                    .foregroundStyle(Color.UI.textPrimary)
            }
            .padding()
            .background(Color(PlatformColor.secondarySystemBackground))
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
        @State private var federalWithholding: String
        @State private var stateWithholding: String
        @State private var owner: Owner
        @State private var showDeleteConfirmation = false

        init(incomeToEdit: IncomeSource? = nil) {
            self.incomeToEdit = incomeToEdit
            _name = State(initialValue: incomeToEdit?.name ?? "")
            _incomeType = State(initialValue: incomeToEdit?.type ?? .socialSecurity)
            _annualAmount = State(initialValue: incomeToEdit?.annualAmount.formatted() ?? "")
            _federalWithholding = State(initialValue: incomeToEdit?.federalWithholding.formatted() ?? "")
            _stateWithholding = State(initialValue: incomeToEdit?.stateWithholding.formatted() ?? "")
            _owner = State(initialValue: incomeToEdit?.owner ?? .primary)
        }

        var body: some View {
            NavigationStack {
                Form {
                    Section("Income Details") {
                        TextField("Description", text: $name)

                        Picker("Income Type", selection: $incomeType) {
                            ForEach(IncomeType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }

                        TextField("Annual Amount", text: $annualAmount)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif

                        TextField("Annual Federal Withholding (W-2 Box 2, optional)", text: $federalWithholding)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif

                        TextField("Annual State Withholding (W-2 Box 17, optional)", text: $stateWithholding)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif

                        Picker("Owner", selection: $owner) {
                            ForEach(Owner.allCases, id: \.self) { owner in
                                Text(owner.rawValue).tag(owner)
                            }
                        }
                    }

                    if incomeType == .consulting {
                        Section("About Employment / W-2 Income") {
                            Text("Enter **W-2 Box 1** — Wages, tips, other compensation. This is the amount *after* any pre-tax 401(k), HSA, or FSA contributions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Do not use Box 3 (Social Security wages), which is typically larger because it excludes only the 401(k) portion. Box 1 is what flows to line 1a of your Form 1040.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Self-employment / 1099 income goes here too — use your net profit after business expenses.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .interest {
                        Section("About Taxable Interest") {
                            Text("Enter taxable interest from bank accounts, CDs, Treasuries, corporate bonds, and money-market funds — Form 1099-INT Box 1. This is what the IRS taxes at ordinary income rates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Don't use this for municipal bond interest — select 'Tax-Exempt Interest' instead. Don't use this for mortgage interest you paid (that's an itemized deduction, not income).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .dividends {
                        Section("About Ordinary Dividends") {
                            Text("Enter ordinary (non-qualified) dividends from Form 1099-DIV. These are taxed at your ordinary income rate.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("The value to enter is **Box 1a minus Box 1b** (total ordinary dividends minus the qualified portion). If your 1099-DIV shows a non-zero Box 1b, create a separate entry using the 'Qualified Dividends' type for that amount — qualified dividends are taxed at capital-gains rates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .qualifiedDividends {
                        Section("About Qualified Dividends") {
                            Text("Enter the qualified-dividend portion from Form 1099-DIV **Box 1b**. Qualified dividends are taxed at the preferential capital-gains rates (0% / 15% / 20%) instead of ordinary income rates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("If you also have non-qualified dividends (Box 1a minus Box 1b), add a separate entry with type 'Ordinary Dividends'.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .stateTaxRefund {
                        Section("About State Tax Refunds") {
                            Text("If you itemized deductions last year and received a state tax refund, that refund is taxable as income on your federal return (tax benefit rule). If you took the standard deduction last year, the refund is not taxable and does not need to be entered here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .taxExemptInterest {
                        Section("About Tax-Exempt Interest") {
                            Text("Enter interest from municipal bond funds, tax-free money market funds, and individual muni bonds. This income is not subject to federal income tax, but the IRS includes it in the MAGI used to calculate IRMAA Medicare premium surcharges and Social Security taxation.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("State tax note: National muni funds may hold bonds from other states. The out-of-state portion is generally taxable by your state. Your fund company provides a year-end state breakdown. This app treats all tax-exempt interest as state-exempt for simplicity.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Delete button — only visible when editing an existing income source
                    if incomeToEdit != nil {
                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Delete Income Source", systemImage: "trash")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(incomeToEdit == nil ? "Add Income" : "Edit Income")
                #if os(iOS)
                #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveIncome() }
                            .disabled(name.isEmpty || annualAmount.isEmpty)
                    }
                }
                .alert("Delete Income Source", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if let source = incomeToEdit,
                           let index = dataManager.incomeSources.firstIndex(where: { $0.id == source.id }) {
                            dataManager.incomeSources.remove(at: index)
                            dataManager.saveAllData()
                            dismiss()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete this income source? This cannot be undone.")
                }
            }
        }

        private func saveIncome() {
            let cleanAmount = annualAmount.replacingOccurrences(of: ",", with: "")
            let cleanFederal = federalWithholding.replacingOccurrences(of: ",", with: "")
            let cleanState = stateWithholding.replacingOccurrences(of: ",", with: "")
            guard let amount = Double(cleanAmount) else { return }
            let fedWH = Double(cleanFederal) ?? 0
            let stateWH = Double(cleanState) ?? 0

            if let existing = incomeToEdit,
               let index = dataManager.incomeSources.firstIndex(where: { $0.id == existing.id }) {
                dataManager.incomeSources[index] = IncomeSource(
                    id: existing.id, name: name, type: incomeType,
                    annualAmount: amount, federalWithholding: fedWH, stateWithholding: stateWH, owner: owner
                )
            } else {
                dataManager.incomeSources.append(IncomeSource(
                    name: name, type: incomeType,
                    annualAmount: amount, federalWithholding: fedWH, stateWithholding: stateWH, owner: owner
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
        @State private var showDeleteConfirmation = false

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
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif

                        Picker("Owner", selection: $owner) {
                            ForEach(Owner.allCases, id: \.self) { owner in
                                Text(owner.rawValue).tag(owner)
                            }
                        }
                    }

                    if deductionType == .medicalExpenses {
                        Section("About Medical Deductions") {
                            Text("Enter your total unreimbursed medical expenses (insurance premiums, copays, prescriptions, dental, vision, long-term care, etc.). Only the amount exceeding 7.5% of your adjusted gross income (AGI) is deductible \u{2014} the app calculates this automatically. For most retirees, AGI is essentially your total taxable income before itemized/standard deductions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if deductionType == .saltTax {
                        Section("About SALT Deductions") {
                            Text("State withholding from your income sources and any prior year state tax balance due are now automatically included in your SALT deduction. Use this field only for additional local or city income taxes not already captured. Combined with property taxes, SALT is capped at \(dataManager.saltCap.formatted(.currency(code: "USD").precision(.fractionLength(0)))) for \(String(dataManager.currentYear)) under the OBBBA (2025\u{2013}2029: $40,000 base with 1% inflation; phases out for MAGI over $500K; reverts to $10,000 in 2030).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if deductionType == .propertyTax {
                        Section("About Property Tax Deductions") {
                            Text("Enter your annual property tax amount. Property taxes are combined with state and local income taxes for the SALT deduction, which is capped at \(dataManager.saltCap.formatted(.currency(code: "USD").precision(.fractionLength(0)))) for \(String(dataManager.currentYear)) under the OBBBA (2025\u{2013}2029: $40,000 base with 1% inflation; phases out for MAGI over $500K; reverts to $10,000 in 2030).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Delete button — only visible when editing an existing deduction
                    if deductionToEdit != nil {
                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Delete Deduction", systemImage: "trash")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(deductionToEdit == nil ? "Add Deduction" : "Edit Deduction")
                #if os(iOS)
                #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveDeduction() }
                            .disabled(name.isEmpty || annualAmount.isEmpty)
                    }
                }
                .alert("Delete Deduction", isPresented: $showDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if let item = deductionToEdit,
                           let index = dataManager.deductionItems.firstIndex(where: { $0.id == item.id }) {
                            dataManager.deductionItems.remove(at: index)
                            dataManager.saveAllData()
                            dismiss()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete this deduction? This cannot be undone.")
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
