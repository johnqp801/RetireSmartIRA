//
//  DashboardView.swift
//  RetireSmartIRA
//
//  Dashboard: income breakdown, live tax projection, action to-do list
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if isWideLayout {
                wideBody
            } else {
                compactBody
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Layout Variants

    private var compactBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerCard
                incomeBreakdown
                taxPlanningDecisions
                taxProjection
                actionToDoList
                accountBalances
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(spacing: 24) {
                    headerCard
                    incomeBreakdown
                    taxPlanningDecisions
                    accountBalances
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(spacing: 24) {
                    taxProjection
                    actionToDoList
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(dataManager.currentYear) Tax Year")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text(dataManager.filingStatus.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Age")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(dataManager.currentAge)")
                        .font(.title)
                        .fontWeight(.bold)
                }

                if dataManager.enableSpouse {
                    Spacer()
                    VStack(alignment: .center, spacing: 4) {
                        Text("\(dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName) Age")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(dataManager.spouseCurrentAge)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }

                Spacer()

                if dataManager.isRMDRequired {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("RMD Status")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Required")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Years Until RMD")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(dataManager.yearsUntilRMD)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Income Breakdown

    private var incomeBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income Breakdown")
                .font(.headline)

            // Individual income sources
            if dataManager.incomeSources.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Add income sources in the Income & Deductions tab")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(dataManager.incomeSources) { source in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.name)
                                .font(.subheadline)
                            Text(source.type.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(source.annualAmount, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                if dataManager.incomeSources.count > 1 {
                    Divider()
                    HStack {
                        Text("Subtotal: Income Sources")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(dataManager.totalAnnualIncome(), format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }

            // RMDs as separate line items
            let yourRMD = dataManager.calculatePrimaryRMD()
            let spouseRMD = dataManager.calculateSpouseRMD()
            let combinedRMD = yourRMD + spouseRMD
            let spouseLabel = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName

            if combinedRMD > 0 {
                Divider()

                if dataManager.enableSpouse {
                    if yourRMD > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your Required Minimum Distribution")
                                    .font(.subheadline)
                                Text("Traditional IRA/401(k)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(yourRMD, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                        }
                    }
                    if spouseRMD > 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(spouseLabel)'s Required Minimum Distribution")
                                    .font(.subheadline)
                                Text("Traditional IRA/401(k)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(spouseRMD, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                        }
                    }
                } else if yourRMD > 0 {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Required Minimum Distribution")
                                .font(.subheadline)
                            Text("Traditional IRA/401(k)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(yourRMD, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Total baseline income
            let totalBaseline = dataManager.totalAnnualIncome() + combinedRMD
            if totalBaseline > 0 {
                Divider()
                HStack {
                    Text("Total Baseline Income")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(totalBaseline, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Tax Planning Decisions

    @ViewBuilder
    private var taxPlanningDecisions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax Planning Decisions")
                .font(.headline)

            if dataManager.hasActiveScenario {
                if dataManager.scenarioTotalRothConversion > 0 {
                    decisionRow(
                        icon: "arrow.triangle.2.circlepath",
                        label: "Roth Conversions",
                        amount: dataManager.scenarioTotalRothConversion,
                        color: .purple
                    )
                }
                if dataManager.scenarioTotalExtraWithdrawal > 0 {
                    decisionRow(
                        icon: "arrow.down.circle.fill",
                        label: "Extra Withdrawals",
                        amount: dataManager.scenarioTotalExtraWithdrawal,
                        color: .blue
                    )
                }
                if dataManager.scenarioTotalQCD > 0 {
                    decisionRow(
                        icon: "heart.fill",
                        label: "Qualified Charitable Distribution",
                        amount: dataManager.scenarioTotalQCD,
                        color: .green
                    )
                }
                if dataManager.stockDonationEnabled && dataManager.stockCurrentValue > 0 {
                    decisionRow(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Appreciated Stock Donation",
                        amount: dataManager.stockCurrentValue,
                        color: .orange
                    )
                }
                if dataManager.cashDonationAmount > 0 {
                    decisionRow(
                        icon: "banknote.fill",
                        label: "Cash Donation",
                        amount: dataManager.cashDonationAmount,
                        color: .teal
                    )
                }

                Divider()

                // Deduction method
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.indigo)
                        .frame(width: 24)
                    Text("Deduction:")
                        .font(.subheadline)
                    Text(dataManager.scenarioEffectiveItemize ? "Itemized" : "Standard")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(dataManager.effectiveDeductionAmount, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                }
            } else {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.blue)
                    Text("Visit Tax Planning to model Roth conversions, withdrawals, and charitable giving")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Still show deduction even if no active scenario
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.indigo)
                        .frame(width: 24)
                    Text("Deduction:")
                        .font(.subheadline)
                    Text(dataManager.scenarioEffectiveItemize ? "Itemized" : "Standard")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(dataManager.effectiveDeductionAmount, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func decisionRow(icon: String, label: String, amount: Double, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    // MARK: - Tax Projection

    private var taxProjection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax Projection")
                .font(.headline)

            if dataManager.hasActiveScenario {
                Text("Includes Tax Planning decisions")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Group {
                taxRow(label: "Taxable Income", value: dataManager.scenarioTaxableIncome)

                Divider()

                taxRow(label: "Federal Tax", value: dataManager.scenarioFederalTax, color: .red)
                taxRow(label: "State Tax", value: dataManager.scenarioStateTax, color: .red)
                taxRow(label: "Total Tax", value: dataManager.scenarioTotalTax, isBold: true, color: .red)
            }

            if dataManager.totalWithholding > 0 {
                Divider()
                taxRow(label: "Withholding Already Paid", value: dataManager.totalWithholding, color: .green)
                taxRow(label: "Remaining Estimated Tax", value: dataManager.scenarioRemainingTax, isBold: true)
            }

            if dataManager.scenarioQuarterlyPayment > 0 {
                Divider()
                taxRow(label: "Per-Quarter Payment", value: dataManager.scenarioQuarterlyPayment, isBold: true, color: .orange)
                Text("Based on 90% safe harbor rule")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Tax Rates
            Divider()

            let taxableIncome = dataManager.scenarioTaxableIncome
            let fs = dataManager.filingStatus

            VStack(alignment: .leading, spacing: 8) {
                Text("Tax Rates")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Federal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Marginal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(dataManager.federalMarginalRate(income: taxableIncome, filingStatus: fs), specifier: "%.1f")%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            VStack(alignment: .leading) {
                                Text("Average")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(dataManager.federalAverageRate(income: taxableIncome, filingStatus: fs), specifier: "%.1f")%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("State")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Marginal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(dataManager.stateMarginalRate(income: taxableIncome, filingStatus: fs), specifier: "%.1f")%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            VStack(alignment: .leading) {
                                Text("Average")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(dataManager.stateAverageRate(income: taxableIncome, filingStatus: fs), specifier: "%.1f")%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func taxRow(label: String, value: Double, isBold: Bool = false, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundStyle(isBold ? .primary : .secondary)
            Spacer()
            Text(value, format: .currency(code: "USD"))
                .font(isBold ? .title3 : .subheadline)
                .fontWeight(isBold ? .bold : .semibold)
                .foregroundStyle(color ?? .primary)
        }
    }

    // MARK: - Action To-Do List

    private var actionToDoList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Action Items")
                    .font(.headline)
                Spacer()
                let items = dataManager.generatedActionItems
                let completed = items.filter { dataManager.completedActionKeys.contains($0.id) }.count
                if !items.isEmpty {
                    Text("\(completed)/\(items.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            let items = dataManager.generatedActionItems

            if items.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("No action items yet. Add income sources and explore Tax Planning to generate your to-do list.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(items) { item in
                    actionItemRow(item)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func actionItemRow(_ item: DataManager.ActionItem) -> some View {
        let isCompleted = dataManager.completedActionKeys.contains(item.id)

        return HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation {
                    if isCompleted {
                        dataManager.completedActionKeys.remove(item.id)
                    } else {
                        dataManager.completedActionKeys.insert(item.id)
                    }
                    dataManager.saveAllData()
                }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)

                HStack {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(item.deadline)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(categoryColor(item.category))
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func categoryColor(_ category: DataManager.ActionCategory) -> Color {
        switch category {
        case .rmd: return .red
        case .rothConversion: return .purple
        case .qcd: return .green
        case .withdrawal: return .blue
        case .estimatedTax: return .orange
        case .charitable: return .teal
        }
    }

    // MARK: - Account Balances

    private var accountBalances: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Balances")
                .font(.headline)

            HStack(spacing: 16) {
                BalanceCard(
                    title: "Traditional IRA/401(k)",
                    amount: dataManager.totalTraditionalIRABalance,
                    color: .blue
                )

                BalanceCard(
                    title: "Roth IRA/401(k)",
                    amount: dataManager.totalRothBalance,
                    color: .green
                )
            }

            if dataManager.enableSpouse {
                OwnerBalanceRow(
                    label: "You",
                    icon: "person.fill",
                    traditionalBalance: dataManager.primaryTraditionalIRABalance,
                    rothBalance: dataManager.primaryRothBalance
                )

                OwnerBalanceRow(
                    label: dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName,
                    icon: "person.fill",
                    traditionalBalance: dataManager.spouseTraditionalIRABalance,
                    rothBalance: dataManager.spouseRothBalance
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Supporting Views

struct BalanceCard: View {
    let title: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(amount, format: .currency(code: "USD"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct OwnerBalanceRow: View {
    let label: String
    let icon: String
    let traditionalBalance: Double
    let rothBalance: Double

    private var total: Double { traditionalBalance + rothBalance }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(total, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                    Text("Traditional")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(traditionalBalance, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Roth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(rothBalance, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct OwnerIncomeRow: View {
    let label: String
    let icon: String
    let amount: Double

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
}
