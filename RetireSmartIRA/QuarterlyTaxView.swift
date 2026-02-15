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
        .background(Color(.systemGroupedBackground))
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
                summaryRow(label: "State Tax", value: dataManager.scenarioStateTax, color: .orange)

                Divider()

                summaryRow(label: "Total Estimated Tax", value: dataManager.scenarioTotalTax, isBold: true)

                if dataManager.totalWithholding > 0 {
                    summaryRow(label: "Withholding Already Paid", value: dataManager.totalWithholding, color: .green, prefix: "−")
                    summaryRow(label: "Remaining Tax Due", value: dataManager.scenarioRemainingTax, isBold: true)
                }

                Divider()

                HStack {
                    let payments = dataManager.scenarioQuarterlyPayments
                    let minQ = min(payments.q1, payments.q2, payments.q3, payments.q4)
                    let maxQ = max(payments.q1, payments.q2, payments.q3, payments.q4)

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
            }
        }
        .padding()
        .background(Color(.systemBackground))
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
        let sourcesWithWithholding = dataManager.incomeSources.filter { $0.taxWithholding > 0 }

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
                            Text(source.taxWithholding, format: .currency(code: "USD"))
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    }

                    if sourcesWithWithholding.count > 1 {
                        Divider()
                        HStack {
                            Text("Total Withholding")
                                .font(.callout)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(dataManager.totalWithholding, format: .currency(code: "USD"))
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
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

            VStack(spacing: 12) {
                QuarterRow(quarter: "Q1", dueDate: "April 15, \(year)", amount: payments.q1, events: eventsForQuarter(1))
                QuarterRow(quarter: "Q2", dueDate: "June 15, \(year)", amount: payments.q2, events: eventsForQuarter(2))
                QuarterRow(quarter: "Q3", dueDate: "September 15, \(year)", amount: payments.q3, events: eventsForQuarter(3))
                QuarterRow(quarter: "Q4", dueDate: "January 15, \(year + 1)", amount: payments.q4, events: eventsForQuarter(4))
            }

            Divider()

            HStack {
                Text("Annual Total (4 payments)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(payments.total, format: .currency(code: "USD"))
                    .font(.callout)
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    /// Returns event labels for a given quarter (e.g., "Your Withdrawal", "Roth Conv.")
    private func eventsForQuarter(_ q: Int) -> [String] {
        var events: [String] = []
        let dm = dataManager
        let spouseEnabled = dm.enableSpouse
        let spouseName = dm.spouseName.isEmpty ? "Spouse" : dm.spouseName

        if (dm.isRMDRequired || dm.yourExtraWithdrawal > 0) && dm.yourWithdrawalQuarter == q {
            events.append(spouseEnabled ? "Your Withdrawal" : "Withdrawal")
        }
        if spouseEnabled && (dm.spouseIsRMDRequired || dm.spouseExtraWithdrawal > 0) && dm.spouseWithdrawalQuarter == q {
            events.append("\(spouseName) Withdrawal")
        }
        if dm.yourRothConversion > 0 && dm.yourRothConversionQuarter == q {
            events.append(spouseEnabled ? "Your Roth Conv." : "Roth Conv.")
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
                    text: "Withholding from income sources (Social Security, pensions) is credited against your total tax liability",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct QuarterRow: View {
    let quarter: String
    let dueDate: String
    let amount: Double
    var events: [String] = []

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(quarter)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(dueDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !events.isEmpty {
                    Text(events.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Text(amount, format: .currency(code: "USD"))
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
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
