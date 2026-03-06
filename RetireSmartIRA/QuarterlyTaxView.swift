//
//  QuarterlyTaxView.swift
//  RetireSmartIRA
//
//  Scenario-aware quarterly estimated tax payment tracking
//

import SwiftUI

struct QuarterlyTaxView: View {
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
        .background(Color(PlatformColor.systemGroupedBackground))
    }

    // MARK: - Layout Variants

    private var compactBody: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                scenarioBanner
                annualTaxSummary
                withholdingBreakdown
                paymentSchedule
                importantNotes
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    scenarioBanner
                    annualTaxSummary
                    withholdingBreakdown
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(spacing: 24) {
                    paymentSchedule
                    importantNotes
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Quarterly Estimated Tax Payments")
            .font(.title2)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Scenario Banner

    @ViewBuilder
    private var scenarioBanner: some View {
        if dataManager.hasActiveScenario {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.orange)
                    Text("Reflects Scenario Decisions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if dataManager.scenarioTotalRothConversion > 0 {
                        scenarioItem("Roth Conversions", amount: dataManager.scenarioTotalRothConversion)
                    }
                    if dataManager.scenarioTotalExtraWithdrawal > 0 {
                        scenarioItem("Extra Withdrawals", amount: dataManager.scenarioTotalExtraWithdrawal)
                    }
                    if dataManager.scenarioTotalQCD > 0 {
                        scenarioItem("QCD", amount: dataManager.scenarioTotalQCD)
                    }
                    if dataManager.stockDonationEnabled && dataManager.stockCurrentValue > 0 {
                        scenarioItem("Stock Donation", amount: dataManager.stockCurrentValue)
                    }
                    if dataManager.cashDonationAmount > 0 {
                        scenarioItem("Cash Donation", amount: dataManager.cashDonationAmount)
                    }
                }

                // Timing summary
                if dataManager.scenarioTotalRothConversion > 0 || dataManager.scenarioTotalExtraWithdrawal > 0 || dataManager.scenarioCombinedRMD > 0 {
                    Divider()
                    Text("Timing")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if dataManager.isRMDRequired || dataManager.yourExtraWithdrawal > 0 {
                        timingItem(dataManager.enableSpouse ? "Your Withdrawals" : "Withdrawals", quarter: dataManager.yourWithdrawalQuarter)
                    }
                    if dataManager.enableSpouse && (dataManager.spouseIsRMDRequired || dataManager.spouseExtraWithdrawal > 0) {
                        timingItem("\(dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName) Withdrawals", quarter: dataManager.spouseWithdrawalQuarter)
                    }
                    if dataManager.yourRothConversion > 0 {
                        timingItem(dataManager.enableSpouse ? "Your Roth Conv." : "Roth Conv.", quarter: dataManager.yourRothConversionQuarter)
                    }
                    if dataManager.enableSpouse && dataManager.spouseRothConversion > 0 {
                        timingItem("\(dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName) Roth Conv.", quarter: dataManager.spouseRothConversionQuarter)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func scenarioItem(_ label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func timingItem(_ label: String, quarter: Int) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Q\(quarter)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Annual Tax Summary

    private var annualTaxSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(dataManager.currentYear) Annual Tax Summary")
                .font(.headline)

            VStack(spacing: 12) {
                summaryRow(label: "Gross Income", value: dataManager.scenarioGrossIncome)

                summaryRow(
                    label: "Deduction (\(dataManager.scenarioEffectiveItemize ? "Itemized" : "Standard"))",
                    value: dataManager.effectiveDeductionAmount,
                    prefix: "−"
                )

                Divider()

                summaryRow(label: "Taxable Income", value: dataManager.scenarioTaxableIncome, isBold: true)

                Divider()

                summaryRow(label: "Federal Tax", value: dataManager.scenarioFederalTax, color: .blue)
                summaryRow(label: "State Tax (\(dataManager.selectedState.abbreviation))", value: dataManager.scenarioStateTax, color: .orange)

                if dataManager.scenarioNIITAmount > 0 {
                    summaryRow(label: "NIIT (3.8% Surtax)", value: dataManager.scenarioNIITAmount, color: .red)
                }

                if dataManager.scenarioAMTAmount > 0 {
                    summaryRow(label: "AMT (26%/28%)", value: dataManager.scenarioAMTAmount, color: .red)
                }

                Divider()

                summaryRow(label: "Total Estimated Tax", value: dataManager.scenarioTotalTax, isBold: true)

                if dataManager.totalWithholding > 0 {
                    if dataManager.totalFederalWithholding > 0 {
                        summaryRow(label: "Federal Withholding Paid", value: dataManager.totalFederalWithholding, color: .green, prefix: "−")
                    }
                    if dataManager.totalStateWithholding > 0 {
                        summaryRow(label: "State Withholding Paid", value: dataManager.totalStateWithholding, color: .green, prefix: "−")
                    }
                    summaryRow(label: "Remaining Federal Tax", value: dataManager.scenarioRemainingFederalTax, isBold: true)
                    summaryRow(label: "Remaining State Tax", value: dataManager.scenarioRemainingStateTax, isBold: true)
                }

                Divider()

                let payments = dataManager.scenarioQuarterlyPayments
                let minQ = min(payments.q1, payments.q2, payments.q3, payments.q4)
                let maxQ = max(payments.q1, payments.q2, payments.q3, payments.q4)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("90% Safe Harbor")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(minQ == maxQ ? "Per Quarter Payment" : "Quarterly Range")
                            .font(.callout)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    if minQ == maxQ {
                        Text(payments.q1, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                    } else {
                        Text("\(minQ.formatted(.currency(code: "USD"))) \u{2013} \(maxQ.formatted(.currency(code: "USD")))")
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                    }
                }

                // Federal/State estimated payment subtotals
                if payments.federalTotal > 0 {
                    HStack {
                        Text("Federal Estimated Payments")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(payments.federalTotal, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
                if payments.stateTotal > 0 {
                    HStack {
                        Text("State Estimated Payments")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(payments.stateTotal, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func summaryRow(label: String, value: Double, isBold: Bool = false, color: Color? = nil, prefix: String = "") -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .fontWeight(isBold ? .semibold : .regular)
            Spacer()
            Text("\(prefix)\(value.formatted(.currency(code: "USD")))")
                .font(isBold ? .callout : .callout)
                .fontWeight(isBold ? .bold : .semibold)
                .foregroundStyle(color ?? .primary)
        }
    }

    // MARK: - Withholding Breakdown

    @ViewBuilder
    private var withholdingBreakdown: some View {
        let sourcesWithWithholding = dataManager.incomeSources.filter { $0.federalWithholding > 0 || $0.stateWithholding > 0 }

        if !sourcesWithWithholding.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Withholding Breakdown")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(sourcesWithWithholding) { source in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                    .font(.callout)
                                Text(source.type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                if source.federalWithholding > 0 {
                                    Text("Fed \(source.federalWithholding, format: .currency(code: "USD"))")
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                                if source.stateWithholding > 0 {
                                    Text("State \(source.stateWithholding, format: .currency(code: "USD"))")
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }

                    if sourcesWithWithholding.count > 1 {
                        Divider()
                        VStack(spacing: 4) {
                            if dataManager.totalFederalWithholding > 0 {
                                HStack {
                                    Text("Total Federal")
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(dataManager.totalFederalWithholding, format: .currency(code: "USD"))
                                        .font(.callout)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)
                                }
                            }
                            if dataManager.totalStateWithholding > 0 {
                                HStack {
                                    Text("Total State")
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(dataManager.totalStateWithholding, format: .currency(code: "USD"))
                                        .font(.callout)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Payment Schedule

    private var paymentSchedule: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Schedule")
                .font(.headline)

            let year = dataManager.currentYear
            let payments = dataManager.scenarioQuarterlyPayments
            let currentYearPayments = dataManager.quarterlyPayments
                .filter { $0.year == year }
                .sorted { $0.quarter < $1.quarter }

            VStack(spacing: 12) {
                ForEach(currentYearPayments) { payment in
                    QuarterRow(
                        payment: bindingForPayment(payment.id),
                        federalAmount: federalForQuarter(payment.quarter, payments: payments),
                        stateAmount: stateForQuarter(payment.quarter, payments: payments),
                        events: eventsForQuarter(payment.quarter)
                    )
                }
            }

            Divider()

            if payments.federalTotal > 0 {
                HStack {
                    Text("Federal Annual Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(payments.federalTotal, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            }
            if payments.stateTotal > 0 {
                HStack {
                    Text("State Annual Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(payments.stateTotal, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                Text("Combined Annual Total")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(payments.total, format: .currency(code: "USD"))
                    .font(.callout)
                    .fontWeight(.bold)
            }

            paidSummary
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .onAppear { dataManager.syncQuarterlyPayments() }
    }

    private var paidSummary: some View {
        let currentYearPayments = dataManager.quarterlyPayments
            .filter { $0.year == dataManager.currentYear }
        let totalPaid = currentYearPayments.filter { $0.isPaid }.reduce(0.0) { $0 + $1.paidAmount }
        let totalEstimated = dataManager.scenarioQuarterlyPayments.total
        let hasPaidAny = currentYearPayments.contains { $0.isPaid }

        return Group {
            if hasPaidAny {
                Divider()
                HStack {
                    Text("Paid So Far")
                        .font(.callout)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(totalPaid, format: .currency(code: "USD"))
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                HStack {
                    Text("Remaining")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(max(0, totalEstimated - totalPaid), format: .currency(code: "USD"))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func bindingForPayment(_ id: UUID) -> Binding<QuarterlyPayment> {
        Binding(
            get: {
                dataManager.quarterlyPayments.first { $0.id == id }
                    ?? QuarterlyPayment(quarter: 1, year: dataManager.currentYear, dueDate: Date(), estimatedAmount: 0)
            },
            set: { newValue in
                if let idx = dataManager.quarterlyPayments.firstIndex(where: { $0.id == id }) {
                    dataManager.quarterlyPayments[idx] = newValue
                    dataManager.saveAllData()
                }
            }
        )
    }

    private func federalForQuarter(_ q: Int, payments: FederalStateQuarterlyBreakdown) -> Double {
        payments.federal[q]
    }

    private func stateForQuarter(_ q: Int, payments: FederalStateQuarterlyBreakdown) -> Double {
        payments.state[q]
    }

    /// Returns event labels for a given quarter (e.g., "Your Withdrawal", "Roth Conv.")
    private func eventsForQuarter(_ q: Int) -> [String] {
        var events: [String] = []
        let dm = dataManager
        let spouseEnabled = dm.enableSpouse
        let spouseName = dm.spouseName.isEmpty ? "Spouse" : dm.spouseName

        if (dm.isRMDRequired || dm.yourExtraWithdrawal > 0) && dm.yourWithdrawalQuarter == q {
            events.append(spouseEnabled ? "\(dm.primaryLabel) Withdrawal" : "Withdrawal")
        }
        if spouseEnabled && (dm.spouseIsRMDRequired || dm.spouseExtraWithdrawal > 0) && dm.spouseWithdrawalQuarter == q {
            events.append("\(spouseName) Withdrawal")
        }
        if dm.yourRothConversion > 0 && dm.yourRothConversionQuarter == q {
            events.append(spouseEnabled ? "\(dm.primaryLabel) Roth Conv." : "Roth Conv.")
        }
        if spouseEnabled && dm.spouseRothConversion > 0 && dm.spouseRothConversionQuarter == q {
            events.append("\(spouseName) Roth Conv.")
        }
        return events
    }

    // MARK: - Important Notes

    private var importantNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Important Notes")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                NoteRow(
                    icon: "exclamationmark.triangle.fill",
                    text: "Pay 90% of current year tax OR 100% of prior year tax to avoid penalties",
                    color: .orange
                )

                NoteRow(
                    icon: "calendar",
                    text: "These are estimated payments \u{2014} actual tax owed is calculated when filing your return",
                    color: .blue
                )

                NoteRow(
                    icon: "dollarsign.circle",
                    text: "Adjust payments if income or Scenario decisions change significantly during the year",
                    color: .purple
                )

                NoteRow(
                    icon: "checkmark.shield",
                    text: "Federal and state withholding from income sources is credited against each tax liability separately",
                    color: .green
                )

                NoteRow(
                    icon: "building.2",
                    text: "Local and city income taxes (e.g. NYC, Yonkers) are not included in these estimates",
                    color: .secondary
                )
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct QuarterRow: View {
    @Binding var payment: QuarterlyPayment
    var federalAmount: Double = 0
    var stateAmount: Double = 0
    var events: [String] = []

    private var showSplit: Bool { federalAmount > 0 && stateAmount > 0 }

    private static let dueDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d, yyyy"
        return fmt
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Q\(payment.quarter)")
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text(Self.dueDateFormatter.string(from: payment.dueDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !events.isEmpty {
                        Text(events.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                Text(payment.estimatedAmount, format: .currency(code: "USD"))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            // Federal/State sub-rows
            if showSplit {
                HStack {
                    Text("Federal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(federalAmount, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue.opacity(0.7))
                }
                .padding(.leading, 8)

                HStack {
                    Text("State")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stateAmount, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange.opacity(0.8))
                }
                .padding(.leading, 8)
            }

            Divider()

            // Payment tracking
            HStack {
                Toggle(isOn: $payment.isPaid) {
                    Text(payment.isPaid ? "Paid" : "Not Paid")
                        .font(.caption)
                        .foregroundStyle(payment.isPaid ? .green : .secondary)
                }
                .toggleStyle(.switch)
                .onChange(of: payment.isPaid) {
                    if payment.isPaid && payment.paidAmount == 0 {
                        payment.paidAmount = payment.estimatedAmount
                    }
                }

                if payment.isPaid {
                    Spacer()
                    TextField("Amount", value: $payment.paidAmount, format: .currency(code: "USD"))
                        .font(.caption)
                        #if canImport(UIKit)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct NoteRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    QuarterlyTaxView()
        .environmentObject(DataManager())
}
