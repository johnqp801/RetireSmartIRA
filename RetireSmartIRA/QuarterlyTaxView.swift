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
    @State private var timingGuideExpanded = false
    @State private var safeHarborExpanded = false
    @State private var strategiesExpanded = false
    @State private var withholdingTipExpanded = false
    @State private var form2210Expanded = false

    @Environment(\.availableWidth) private var availableWidth
    private var isWideLayout: Bool { horizontalSizeClass == .regular && availableWidth > 700 }

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
                safeHarborCard
                annualTaxSummary
                withholdingBreakdown
                paymentSchedule
                paymentTimingGuide
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
                    safeHarborCard
                    paymentTimingGuide
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
                        .foregroundStyle(Color.Semantic.amber)
                    Text("Reflects Scenario Decisions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Semantic.amber)
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
            .background(Color.Semantic.amberTint)
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

    // Intentionally ad-hoc: MetricCard doesn't fit — detailed tax line-item breakdown with multiple
    // rows and dividers. A summary table, not a metric card.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
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

                summaryRow(label: "Federal Tax", value: dataManager.scenarioFederalTax)
                summaryRow(label: "State Tax (\(dataManager.selectedState.abbreviation))", value: dataManager.scenarioStateTax)

                // NIIT and AMT are standard tax components (not penalties).
                // Per color contract, render in default neutral — red is
                // reserved for adverse signals (penalties, deadlines, cliff
                // crossings, scenario decisions that worsen the outcome).
                if dataManager.scenarioNIITAmount > 0 {
                    summaryRow(label: "NIIT (3.8% Surtax)", value: dataManager.scenarioNIITAmount)
                }

                if dataManager.scenarioAMTAmount > 0 {
                    summaryRow(label: "AMT (26%/28%)", value: dataManager.scenarioAMTAmount)
                }

                Divider()

                summaryRow(label: "Total Estimated Tax", value: dataManager.scenarioTotalTax, isBold: true)

                if dataManager.totalWithholding > 0 {
                    if dataManager.totalFederalWithholding > 0 {
                        summaryRow(label: "Federal Withholding Paid", value: dataManager.totalFederalWithholding, prefix: "−")
                    }
                    if dataManager.totalStateWithholding > 0 {
                        summaryRow(label: "State Withholding Paid", value: dataManager.totalStateWithholding, prefix: "−")
                    }
                    summaryRow(label: "Remaining Federal Tax", value: dataManager.scenarioRemainingFederalTax, isBold: true)
                    summaryRow(label: "Remaining State Tax", value: dataManager.scenarioRemainingStateTax, isBold: true)
                }

                Divider()

                let payments = dataManager.scenarioQuarterlyPayments
                let minQ = min(payments.q1, payments.q2, payments.q3, payments.q4)
                let maxQ = max(payments.q1, payments.q2, payments.q3, payments.q4)

                // Candidate for MetricCard swap — range UX deserves its own treatment first.
                // Revisit after Pass 2 snapshot tests cover this screen.
                // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dataManager.safeHarborMethod.label)
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
                            .foregroundStyle(Color.UI.textPrimary)
                    } else {
                        Text("\(minQ.formatted(.currency(code: "USD"))) \u{2013} \(maxQ.formatted(.currency(code: "USD")))")
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.UI.textPrimary)
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
                            .foregroundStyle(Color.UI.textPrimary)
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
                            .foregroundStyle(Color.UI.textPrimary)
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
                                        .foregroundStyle(Color.UI.textPrimary)
                                }
                                if source.stateWithholding > 0 {
                                    Text("State \(source.stateWithholding, format: .currency(code: "USD"))")
                                        .font(.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.UI.textPrimary)
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
                                        .foregroundStyle(Color.UI.textPrimary)
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
                                        .foregroundStyle(Color.UI.textPrimary)
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
                        .foregroundStyle(Color.UI.textPrimary)
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
                        .foregroundStyle(Color.UI.textPrimary)
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
                        .foregroundStyle(Color.UI.textPrimary)
                }
                HStack {
                    Text("Remaining")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(max(0, totalEstimated - totalPaid), format: .currency(code: "USD"))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.UI.textPrimary)
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
                    color: Color.Semantic.amber
                )

                NoteRow(
                    icon: "calendar",
                    text: "These are estimated payments \u{2014} actual tax owed is calculated when filing your return",
                    color: Color.UI.brandTeal
                )

                NoteRow(
                    icon: "dollarsign.circle",
                    text: "Adjust payments if income or Scenario decisions change significantly during the year",
                    color: Color.UI.brandTeal
                )

                NoteRow(
                    icon: "checkmark.shield",
                    text: "Federal and state withholding from income sources is credited against each tax liability separately",
                    color: Color.UI.brandTeal
                )

                NoteRow(
                    icon: "building.2",
                    text: "Local and city income taxes (e.g. NYC, Yonkers) are not included in these estimates",
                    color: .secondary
                )

                // SALT auto-inclusion confirmation
                if dataManager.stateHasIncomeTax && dataManager.autoEstimatedStatePayments > 0 {
                    let stateTotal = dataManager.autoEstimatedStatePayments
                    NoteRow(
                        icon: "gearshape.2.fill",
                        text: "Your estimated state tax payments (\(stateTotal.formatted(.currency(code: "USD").precision(.fractionLength(0))))) are automatically included in your SALT deduction \u{2014} no manual entry needed.",
                        color: Color.UI.brandTeal
                    )
                }

                // State-specific payment schedule warning
                if dataManager.selectedStateConfig.estimatedPaymentSchedule != .federal {
                    let schedule = dataManager.selectedStateConfig.estimatedPaymentSchedule
                    NoteRow(
                        icon: "building.columns.fill",
                        text: "\(dataManager.selectedState.rawValue) uses a \(schedule.label) quarterly schedule for state estimated payments (not equal quarters). Q3 (September) may have no state payment due.",
                        color: Color.Semantic.amber
                    )
                }

                // Form 2210 warning
                if dataManager.requiresForm2210ScheduleAI {
                    NoteRow(
                        icon: "doc.text.fill",
                        text: "Uneven quarterly payments may require filing IRS Form 2210, Schedule AI (annualized income). This may incur additional tax preparation fees.",
                        color: Color.Semantic.amber
                    )
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Safe Harbor Method Card

    // Intentionally ad-hoc: MetricCard doesn't fit — interactive picker control + detailed
    // explanation table. Control card, not metric card.
    // See docs/superpowers/specs/2026-04-30-metriccard-sweep-design.md §3.
    private var safeHarborCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color.UI.brandTeal)
                Text("Safe Harbor Method")
                    .font(.headline)
            }

            Text("Choose which safe harbor method to use for your estimated payment calculations:")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Safe Harbor Method", selection: $dataManager.safeHarborMethod) {
                ForEach(SafeHarborMethod.allCases, id: \.self) { method in
                    Text(method.label).tag(method)
                }
            }
            .pickerStyle(.segmented)

            // Trade-offs
            VStack(alignment: .leading, spacing: 8) {
                safeHarborRow(
                    number: "1",
                    text: "90% of Current Year \u{2014} May result in lower payments if current-year tax is less than prior year. Risk: if income is higher than estimated, you may underpay and owe penalties."
                )
                safeHarborRow(
                    number: "2",
                    text: "100%/110% of Prior Year \u{2014} Guaranteed penalty-free regardless of current-year income. Risk: may overpay if current-year tax is significantly lower; overpayment is refunded but cash is tied up."
                )
            }

            // Prior year inputs (only when 110% method selected)
            if dataManager.safeHarborMethod == .priorYear100_110 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(dataManager.priorPlanYear, format: .number.grouping(.never)) Tax Information")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Enter these values from your \(dataManager.priorPlanYear, format: .number.grouping(.never)) tax returns. The IRS and state evaluate safe harbors independently, so both are needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Federal Tax (1040, Line 24)")
                            .font(.callout)
                        Spacer()
                        TextField("$0", value: $dataManager.priorYearFederalTax, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            #endif
                    }

                    if dataManager.stateHasIncomeTax {
                        HStack {
                            Text("State Tax (state return)")
                                .font(.callout)
                            Spacer()
                            TextField("$0", value: $dataManager.priorYearStateTax, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                                #endif
                        }
                    }

                    HStack {
                        Text("AGI (1040, Line 11)")
                            .font(.callout)
                        Spacer()
                        TextField("$0", value: $dataManager.priorYearAGI, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            #endif
                    }

                    if dataManager.priorYearTotalTax > 0 {
                        let fedRate = dataManager.priorYearFederalSafeHarborRate
                        let stateRate = dataManager.priorYearStateSafeHarborRate
                        let fedLabel = fedRate > 1.0 ? "110%" : "100%"
                        let fedReason = fedRate > 1.0 ? "(AGI exceeded $150,000)" : "(AGI at or below $150,000)"
                        HStack {
                            Text("Federal safe harbor rate:")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("\(fedLabel) \(fedReason)")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        if dataManager.stateHasIncomeTax && stateRate != fedRate {
                            HStack {
                                Text("State safe harbor rate:")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text("\(String(format: "%.0f", stateRate * 100))% (\(dataManager.selectedState.rawValue) rule)")
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }
                        }
                        if dataManager.isStateDisqualifiedFromPriorYear {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.Semantic.amber)
                                    .font(.caption)
                                Text("\(dataManager.selectedState.rawValue) does not allow the prior-year safe harbor at your income level. State estimated payments will use the current-year method (\(String(format: "%.0f", dataManager.stateCurrentYearSafeHarborRate * 100))%).")
                                    .font(.caption)
                                    .foregroundStyle(Color.Semantic.amber)
                            }
                        }

                        HStack {
                            Text("Required annual payment:")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(dataManager.priorYearSafeHarborAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.UI.textPrimary)
                        }

                        if dataManager.priorYearFederalTax > 0 && dataManager.priorYearStateTax > 0 {
                            HStack {
                                Text("Federal:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dataManager.priorYearFederalSafeHarbor.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                                    .font(.caption)
                                Spacer()
                                Text("State:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dataManager.priorYearStateSafeHarbor.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            // Comparison (when prior year data is available)
            if dataManager.priorYearTotalTax > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Comparison")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Text("90% of Current Year:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(dataManager.currentYearSafeHarborAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    HStack {
                        let rateLabel = dataManager.priorYearSafeHarborRate > 1.0 ? "110%" : "100%"
                        Text("\(rateLabel) of \(dataManager.priorPlanYear, format: .number.grouping(.never)) Tax:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(dataManager.priorYearSafeHarborAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            Text("Consult your tax advisor to confirm which method applies to your situation.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Payment Timing Guide

    private var paymentTimingGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            DisclosureGroup(isExpanded: $timingGuideExpanded) {
                timingGuideContent
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.title3)
                        .foregroundStyle(Color.UI.brandTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Understanding Payment Timing")
                            .font(.headline)
                        Text("Why quarterly payments may be uneven and when to pay")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var timingGuideContent: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ─── Why payments are uneven ───
            VStack(alignment: .leading, spacing: 8) {
                Text("Why are my quarterly payments uneven?")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("The IRS expects taxes to be paid as income is earned during the year \u{2014} not just at filing time. This is called \"pay as you go.\"")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("When you do a Roth conversion or take a withdrawal in a specific quarter, the associated tax is allocated to that quarter. This is why your payments may not be split evenly across Q1\u{2013}Q4.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Divider()

            // ─── Quarter due dates ───
            VStack(alignment: .leading, spacing: 8) {
                Text("Quarterly Due Dates")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    quarterDueDateRow("Q1", months: "Jan\u{2013}Mar", due: "April 15")
                    quarterDueDateRow("Q2", months: "Apr\u{2013}May", due: "June 15")
                    quarterDueDateRow("Q3", months: "Jun\u{2013}Aug", due: "September 15")
                    quarterDueDateRow("Q4", months: "Sep\u{2013}Dec", due: "January 15 (next year)")
                }

                Text("A conversion in Q2, for example, generally needs to be covered by the June or September payment \u{2014} not deferred until January.")
                    .font(.caption)
                    .foregroundStyle(Color.Semantic.amber)
                    .padding(.top, 2)
            }

            Divider()

            // ─── Strategies ───
            DisclosureGroup(isExpanded: $strategiesExpanded) {
                VStack(alignment: .leading, spacing: 12) {

                    strategyRow(
                        number: "1",
                        title: "Make timely estimated payments",
                        detail: "The most straightforward approach. If you convert in Q2, consider making an estimated payment by June 15 or September 15 to cover the additional tax."
                    )

                    strategyRow(
                        number: "2",
                        title: "Rely on safe harbor",
                        detail: "If your withholding and estimated payments already meet 100% (or 110%) of last year's tax, you may owe a balance in April but generally would not face penalties."
                    )

                    strategyRow(
                        number: "3",
                        title: "Increase withholding late in the year",
                        detail: "This is a lesser-known but potentially powerful approach. See the tip below."
                    )
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("3 Strategies to Consider")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            // ─── Form 2210 warning (conditional) ───
            if dataManager.requiresForm2210ScheduleAI {
                Divider()

                DisclosureGroup(isExpanded: $form2210Expanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your estimated payments are allocated by quarter based on when income events occur. This is called the annualized income installment method.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text("To justify uneven quarterly payments and avoid underpayment penalties, you may need to file IRS Form 2210, Schedule AI with your tax return.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.circle")
                                .foregroundStyle(Color.Semantic.amber)
                                .font(.caption)
                            Text("Note: This may incur additional tax preparation fees from your accountant or CPA.")
                                .font(.caption)
                                .foregroundStyle(Color.Semantic.amber)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(Color.Semantic.amber)
                        Text("IRS Form 2210 May Be Required")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }

            Divider()

            // ─── Withholding pro tip ───
            DisclosureGroup(isExpanded: $withholdingTipExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The IRS treats tax withholding as if it were paid evenly throughout the entire year \u{2014} regardless of when the withholding actually occurred.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text("This means a distribution taken in December with taxes withheld can retroactively cover underpayments from earlier quarters.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text("For example, if you did a Roth conversion in Q2 but didn't make estimated payments, you could take an IRA distribution in Q4 and elect to have taxes withheld. The IRS would treat that withholding as if it had been paid proportionally across all four quarters.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(Color.UI.brandTeal)
                            .font(.caption)
                        Text("Estimated payments are different \u{2014} they are credited only to the quarter in which they are paid.")
                            .font(.caption)
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("Withholding vs. Estimated Payments")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            Divider()

            // ─── Disclaimer ───
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("This information is educational and should not be considered tax advice. Tax rules vary by situation. Please consult your accountant, CPA, or financial planner before making payment timing decisions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private func quarterDueDateRow(_ quarter: String, months: String, due: String) -> some View {
        HStack {
            Text(quarter)
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 28, alignment: .leading)
            Text(months)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Text("Due \(due)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    private func safeHarborRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.UI.brandTeal))
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func strategyRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.UI.brandTeal))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
                            .foregroundStyle(Color.UI.textSecondary)
                    }
                }

                Spacer()

                Text(federalAmount + stateAmount, format: .currency(code: "USD"))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.UI.textPrimary)
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
                        .foregroundStyle(Color.UI.textPrimary)
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
                        .foregroundStyle(Color.UI.textPrimary)
                }
                .padding(.leading, 8)
            }

            Divider()

            // Payment tracking
            HStack {
                Toggle(isOn: $payment.isPaid) {
                    Text(payment.isPaid ? "Paid" : "Not Paid")
                        .font(.caption)
                        .foregroundStyle(payment.isPaid ? Color.UI.textPrimary : .secondary)
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
