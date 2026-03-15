//
//  DashboardView.swift
//  RetireSmartIRA
//
//  Tax Summary: income breakdown, live tax projection, action to-do list
//

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var isGeneratingPDF = false

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
                headerCard
                exportPDFButton
                incomeBreakdown
                incomeCompositionChart
                taxPlanningDecisions
                taxProjection
                taxBracketChart
                irmaaTierChart
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
                    exportPDFButton
                    incomeBreakdown
                    incomeCompositionChart
                    taxPlanningDecisions
                    accountBalances
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(spacing: 24) {
                    taxProjection
                    taxBracketChart
                    irmaaTierChart
                    actionToDoList
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Export PDF Button

    private var exportPDFButton: some View {
        Button {
            isGeneratingPDF = true
            let snapshot = PDFExportData(from: dataManager)
            Task {
                let data = await PDFExportService.generatePDF(from: snapshot)
                pdfData = data
                isGeneratingPDF = false
                #if canImport(UIKit)
                showShareSheet = true
                #elseif canImport(AppKit)
                let name = dataManager.userName.isEmpty ? "" : "_\(dataManager.userName)"
                MacPDFExporter.save(pdfData: data, fileName: "TaxSummary\(name)_\(dataManager.currentYear).pdf")
                #endif
            }
        } label: {
            HStack(spacing: 8) {
                if isGeneratingPDF {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating PDF...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.body)
                    Text("Export PDF for CPA")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.1))
            .foregroundStyle(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isGeneratingPDF)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(String(dataManager.currentYear)) Tax Year")
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
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        #if canImport(UIKit)
        .sheet(isPresented: $showShareSheet) {
            if let pdfData {
                let name = dataManager.userName.isEmpty ? "" : "_\(dataManager.userName)"
                ShareSheet(pdfData: pdfData, fileName: "TaxSummary\(name)_\(dataManager.currentYear).pdf")
            }
        }
        #endif
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

            // Inherited IRA RMDs
            let inheritedRMD = dataManager.inheritedIRARMDTotal
            if inheritedRMD > 0 {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inherited IRA RMD")
                            .font(.subheadline)
                        Text("Not eligible for QCD")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(inheritedRMD, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }

            // Inherited IRA deadline warnings
            let urgentAccounts = dataManager.inheritedAccounts.compactMap { account -> (String, Int)? in
                let result = dataManager.calculateInheritedIRARMD(account: account, forYear: dataManager.currentYear)
                guard result.mustEmptyByYear != nil, let remaining = result.yearsRemaining, remaining <= 2 else { return nil }
                return (account.name, remaining)
            }
            if !urgentAccounts.isEmpty {
                ForEach(urgentAccounts, id: \.0) { name, remaining in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(remaining <= 1 ? .red : .orange)
                        Text("\(name): \(remaining == 0 ? "deadline this year!" : "\(remaining) year\(remaining == 1 ? "" : "s") until 10-year deadline")")
                            .font(.caption)
                            .foregroundStyle(remaining <= 1 ? .red : .orange)
                    }
                }
            }

            // Total baseline income
            let totalBaseline = dataManager.totalAnnualIncome() + combinedRMD + inheritedRMD
            if totalBaseline > 0 {
                Divider()
                ViewThatFits {
                    HStack {
                        Text("Total Baseline Income")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(totalBaseline, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Baseline Income")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(totalBaseline, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Tax Planning Decisions

    @ViewBuilder
    private var taxPlanningDecisions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scenario Decisions")
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
                    Text("Visit Scenarios to model Roth conversions, withdrawals, and charitable giving")
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
        .background(Color(PlatformColor.systemBackground))
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
                Text("Includes Scenario decisions")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Group {
                taxRow(label: "Taxable Income", value: dataManager.scenarioTaxableIncome)

                Divider()

                taxRow(label: "Federal Tax", value: dataManager.scenarioFederalTax, color: .red)
                taxRow(label: "State Tax (\(dataManager.selectedState.abbreviation))", value: dataManager.scenarioStateTax, color: .red)

                if dataManager.scenarioNIITAmount > 0 {
                    taxRow(label: "NIIT (3.8% Surtax)", value: dataManager.scenarioNIITAmount, color: .red)
                }

                if dataManager.scenarioAMTAmount > 0 {
                    taxRow(label: "AMT (26%/28%)", value: dataManager.scenarioAMTAmount, color: .red)
                }

                taxRow(label: "Total Tax", value: dataManager.scenarioTotalTax, isBold: true, color: .red)

                // NIIT safe zone warning (has investment income but below threshold)
                if dataManager.scenarioNetInvestmentIncome > 0 && dataManager.scenarioNIITAmount == 0 {
                    let niitDistance = dataManager.scenarioNIIT.distanceToThreshold
                    if niitDistance > 0 && niitDistance < 10_000 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("\(niitDistance, format: .currency(code: "USD")) below NIIT threshold")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Local tax note
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text("State tax only \u{2014} local/city taxes (e.g. NYC) are not included.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // IRMAA surcharge (separate from income tax — Medicare premium surcharge)
            if dataManager.medicareMemberCount > 0 {
                let irmaa = dataManager.scenarioIRMAA
                let memberCount = dataManager.medicareMemberCount

                Divider()

                if irmaa.tier == 0 {
                    // Tier 0: Safe zone indicator
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("IRMAA: Standard (no surcharge)")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .fontWeight(.semibold)
                    }

                    if let distanceToNext = irmaa.distanceToNextTier {
                        HStack(spacing: 6) {
                            Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(distanceToNext < 10_000 ? .orange : .blue)
                                .font(.caption)
                            Text("\(distanceToNext, format: .currency(code: "USD")) below first IRMAA cliff")
                                .font(.caption)
                                .foregroundStyle(distanceToNext < 10_000 ? .orange : .secondary)
                        }
                    }
                } else {
                    // Tier 1-5: Surcharge + cliff distances
                    taxRow(label: "IRMAA Surcharge (per person)", value: irmaa.annualSurchargePerPerson, color: .pink)

                    if memberCount > 1 {
                        taxRow(label: "IRMAA Household (\(memberCount) on Medicare)", value: dataManager.scenarioIRMAATotalSurcharge, isBold: true, color: .pink)
                    }

                    // Distance to next tier
                    if let distanceToNext = irmaa.distanceToNextTier, distanceToNext > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(distanceToNext < 10_000 ? .orange : .blue)
                                .font(.caption)
                            Text("\(distanceToNext, format: .currency(code: "USD")) until next IRMAA tier")
                                .font(.caption)
                                .foregroundStyle(distanceToNext < 10_000 ? .orange : .secondary)
                        }
                    }

                    // Actionable: drop a tier
                    if let distanceToPrev = irmaa.distanceToPreviousTier {
                        let savingsPerPerson = irmaa.annualSurchargePerPerson - dataManager.scenarioIRMAAPreviousTierAnnualSurcharge
                        let householdSavings = savingsPerPerson * Double(memberCount)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reduce income by \(distanceToPrev + 1, format: .currency(code: "USD")) to drop a tier")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Saves \(householdSavings, format: .currency(code: "USD"))/year\(memberCount > 1 ? " household" : "")")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("IRMAA is not a current-year tax.")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Your \(String(dataManager.currentYear)) income determines Medicare premiums in \(String(dataManager.currentYear + 2)). Surcharges are deducted monthly from Social Security or billed quarterly by CMS.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if dataManager.totalWithholding > 0 {
                Divider()
                if dataManager.totalFederalWithholding > 0 {
                    taxRow(label: "Federal Withholding Paid", value: dataManager.totalFederalWithholding, color: .green)
                }
                if dataManager.totalStateWithholding > 0 {
                    taxRow(label: "State Withholding Paid", value: dataManager.totalStateWithholding, color: .green)
                }
                taxRow(label: "Remaining Federal Tax", value: dataManager.scenarioRemainingFederalTax, isBold: true)
                taxRow(label: "Remaining State Tax", value: dataManager.scenarioRemainingStateTax, isBold: true)
            }

            if dataManager.scenarioQuarterlyPayment > 0 {
                Divider()
                let payments = dataManager.scenarioQuarterlyPayments
                let minQ = min(payments.q1, payments.q2, payments.q3, payments.q4)
                let maxQ = max(payments.q1, payments.q2, payments.q3, payments.q4)
                if minQ == maxQ {
                    taxRow(label: "Per-Quarter Payment", value: payments.q1, isBold: true, color: .orange)
                } else {
                    HStack {
                        Text("Quarterly Range")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(minQ.formatted(.currency(code: "USD"))) \u{2013} \(maxQ.formatted(.currency(code: "USD")))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                }

                // Federal/State breakdown
                if payments.federalTotal > 0 {
                    HStack {
                        Text("Federal Est. Payments")
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
                        Text("State Est. Payments")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(payments.stateTotal, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }

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
        .background(Color(PlatformColor.systemBackground))
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

    // MARK: - Y-Axis Label Helper

    private func chartYAxisLabel(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$\(String(format: "%.1f", amount / 1_000_000))M"
        } else if amount >= 1000 {
            return "$\(Int(amount / 1000))K"
        } else {
            return "$\(Int(amount))"
        }
    }

    // MARK: - Chart 1: Income Composition Donut

    private struct IncomeSlice: Identifiable {
        let id = UUID()
        let category: String
        let amount: Double
        let color: Color
    }

    private var incomeChartData: [IncomeSlice] {
        var slices: [String: Double] = [:]

        // Group income sources by type
        for source in dataManager.incomeSources {
            let key = source.type.rawValue
            slices[key, default: 0] += source.annualAmount
        }

        // Add RMDs if not already in income sources
        let combinedRMD = dataManager.calculateCombinedRMD()
        if combinedRMD > 0 {
            slices["RMD", default: 0] += combinedRMD
        }
        let inheritedRMD = dataManager.inheritedIRARMDTotal
        if inheritedRMD > 0 {
            slices["Inherited IRA RMD", default: 0] += inheritedRMD
        }

        // Map to colored slices, filtering out zero/negative
        return slices.filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { IncomeSlice(category: $0.key, amount: $0.value, color: incomeColor(for: $0.key)) }
    }

    private func incomeColor(for category: String) -> Color {
        switch category {
        case "Social Security": return Color(red: 0.18, green: 0.45, blue: 0.95)       // Royal blue
        case "Pension": return Color(red: 0.05, green: 0.72, blue: 0.40)               // Emerald
        case "RMD": return Color(red: 0.58, green: 0.22, blue: 0.90)                   // Rich violet
        case "Inherited IRA RMD": return Color(red: 1.0, green: 0.55, blue: 0.08)      // Vivid orange
        case "Dividends", "Qualified Dividends": return Color(red: 0.0, green: 0.75, blue: 0.70) // Bright teal
        case "Interest": return Color(red: 0.15, green: 0.65, blue: 0.95)              // Sky blue
        case "Capital Gains (Long-term)", "Capital Gains (Short-term)": return Color(red: 0.92, green: 0.25, blue: 0.55) // Hot pink
        case "Roth Conversion": return Color(red: 0.85, green: 0.15, blue: 0.40)       // Ruby
        case "Employment/Other Income": return Color(red: 0.35, green: 0.25, blue: 0.85) // Deep indigo
        case "State Tax Refund": return Color(red: 0.0, green: 0.82, blue: 0.55)       // Bright mint
        default: return Color(red: 0.55, green: 0.55, blue: 0.62)
        }
    }

    @ViewBuilder
    private var incomeCompositionChart: some View {
        let data = incomeChartData
        if !data.isEmpty {
            let total = data.reduce(0) { $0 + $1.amount }

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.18, green: 0.45, blue: 0.95), Color(red: 0.0, green: 0.75, blue: 0.70)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.pie.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Income Composition")
                            .font(.headline)
                        Text("\(data.count) source\(data.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Donut chart
                Chart(data) { slice in
                    SectorMark(
                        angle: .value("Amount", slice.amount),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 2) {
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(total, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }

                // Custom legend
                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(data) { slice in
                        HStack(spacing: 6) {
                            Circle().fill(slice.color).frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(slice.category)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Text(slice.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.18, green: 0.45, blue: 0.95).opacity(0.35), Color(red: 0.0, green: 0.75, blue: 0.70).opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        }
    }

    // MARK: - Chart 2: Federal Tax Bracket Position

    private struct BracketSegment: Identifiable {
        let id = UUID()
        let rate: Double
        let label: String
        let rangeStart: Double
        let rangeEnd: Double
        let isCurrent: Bool
    }

    private var bracketChartSegments: [BracketSegment] {
        let brackets = dataManager.filingStatus == .single
            ? dataManager.currentTaxBrackets.federalSingle
            : dataManager.currentTaxBrackets.federalMarried
        let income = dataManager.scenarioTaxableIncome

        var segments: [BracketSegment] = []
        for i in brackets.indices {
            let start = brackets[i].threshold
            let end: Double
            if i + 1 < brackets.count {
                end = brackets[i + 1].threshold
            } else {
                // Top bracket: extend to income + 20% or at least threshold + 50K
                end = max(start + 50_000, income * 1.2)
            }
            let rate = brackets[i].rate
            let isCurrent = income > start && (i + 1 >= brackets.count || income <= brackets[i + 1].threshold)
            segments.append(BracketSegment(
                rate: rate,
                label: "\(Int(rate * 100))%",
                rangeStart: start,
                rangeEnd: end,
                isCurrent: isCurrent
            ))
        }
        return segments
    }

    @ViewBuilder
    private var taxBracketChart: some View {
        let income = dataManager.scenarioTaxableIncome
        if income > 0 {
            let segments = bracketChartSegments
            let bracketInfo = dataManager.federalBracketInfo(income: income, filingStatus: dataManager.filingStatus)
            let bracketColors: [Color] = [
                Color(red: 0.05, green: 0.78, blue: 0.35),   // 10% — emerald green
                Color(red: 0.0, green: 0.72, blue: 0.68),    // 12% — teal
                Color(red: 0.98, green: 0.78, blue: 0.0),    // 22% — bright gold
                Color(red: 1.0, green: 0.50, blue: 0.0),     // 24% — vivid orange
                Color(red: 0.92, green: 0.22, blue: 0.50),   // 32% — hot pink
                Color(red: 0.58, green: 0.22, blue: 0.88),   // 35% — vivid purple
                Color(red: 0.18, green: 0.30, blue: 0.85),   // 37% — deep blue
            ]

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.85), .red.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Federal Tax Bracket Position")
                            .font(.headline)
                        Text(dataManager.filingStatus.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Show brackets up through current + one beyond
                let currentIdx = segments.firstIndex(where: { $0.isCurrent }) ?? 0
                let showThrough = min(currentIdx + 1, segments.count - 1)
                let visibleSegments = Array(segments.prefix(showThrough + 1))
                let chartMax = visibleSegments.last?.rangeEnd ?? 1
                let barHeight: CGFloat = 36

                // Pure SwiftUI bar + labels (single GeometryReader = perfect alignment)
                let topPad: CGFloat = 24  // space above bar for income label
                GeometryReader { geo in
                    let w = geo.size.width

                    // 1. Draw all bracket bars
                    // - Brackets at or below current: solid color (full width)
                    // - Next bracket beyond current: very faint preview
                    ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                        let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                        let color = bracketColors[min(globalIdx, bracketColors.count - 1)]
                        let x = w * segment.rangeStart / chartMax
                        let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax

                        if globalIdx <= currentIdx {
                            // Current bracket and all below: solid color, full width
                            Rectangle()
                                .fill(color)
                                .frame(width: segW, height: barHeight)
                                .offset(x: x, y: topPad)
                        } else {
                            // Next bracket beyond current: faint preview
                            Rectangle()
                                .fill(color.opacity(0.22))
                                .frame(width: segW, height: barHeight)
                                .offset(x: x, y: topPad)
                        }
                    }

                    // 3. Rounded corners on first and last segments
                    // Left cap
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.clear)
                        .frame(width: w, height: barHeight)
                        .offset(y: topPad)
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    // 4. Vertical separator lines at each bracket boundary
                    ForEach(Array(visibleSegments.dropFirst().enumerated()), id: \.element.id) { _, segment in
                        let bx = w * segment.rangeStart / chartMax
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 1, height: barHeight)
                            .offset(x: bx - 0.5, y: topPad)
                    }

                    // 5. Income marker line (dashed)
                    let incomeX = w * income / chartMax
                    Path { path in
                        path.move(to: CGPoint(x: incomeX, y: topPad - CGFloat(5)))
                        path.addLine(to: CGPoint(x: incomeX, y: topPad + barHeight + CGFloat(5)))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .foregroundStyle(.primary)

                    // 6. Income label above bar
                    Text(chartYAxisLabel(income))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .position(x: incomeX, y: 10)

                    // 7. Outer rounded border
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        .frame(width: w, height: barHeight)
                        .offset(y: topPad)

                    // 8. Rate + range labels below bar (centered under full bracket width)
                    ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                        let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                        let isLast = index == visibleSegments.count - 1
                        let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax
                        let segX = w * segment.rangeStart / chartMax
                        let centerX = segX + segW / 2

                        VStack(spacing: 1) {
                            Text(segment.label)
                                .font(.system(size: segW > 55 ? 11 : 9, weight: segment.isCurrent ? .bold : .semibold))
                                .foregroundStyle(bracketColors[min(globalIdx, bracketColors.count - 1)])
                            Text("\(chartYAxisLabel(segment.rangeStart))\(isLast && segment.rate >= 0.37 ? "+" : " – \(chartYAxisLabel(segment.rangeEnd))")")
                                .font(.system(size: segW > 55 ? 9 : 7))
                                .foregroundStyle(.secondary)
                        }
                        .position(x: centerX, y: topPad + barHeight + 18)
                    }
                }
                .frame(height: topPad + barHeight + 36)

                // Room remaining callout
                if bracketInfo.roomRemaining > 0 {
                    let nextRate = nextBracketRate(after: bracketInfo.currentRate)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("**\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))** room before the \(nextRate)% bracket")
                            .font(.caption)
                    }
                } else if bracketInfo.currentRate >= 0.37 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("In the top **37%** federal bracket")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    /// Returns the next bracket rate as an integer percentage (e.g., 24 for the 24% bracket)
    private func nextBracketRate(after currentRate: Double) -> Int {
        let brackets = dataManager.filingStatus == .single
            ? dataManager.currentTaxBrackets.federalSingle
            : dataManager.currentTaxBrackets.federalMarried
        for i in brackets.indices {
            if abs(brackets[i].rate - currentRate) < 0.001, i + 1 < brackets.count {
                return Int(brackets[i + 1].rate * 100)
            }
        }
        return Int(currentRate * 100)
    }

    // MARK: - Chart 3: IRMAA Tier Position

    private struct IRMAATierSegment: Identifiable {
        let id = UUID()
        let tier: Int
        let label: String
        let rangeStart: Double
        let rangeEnd: Double
        let surchargePerPerson: Double
        let isCurrent: Bool
    }

    private var irmaaTierSegments: [IRMAATierSegment] {
        let tiers = DataManager.irmaa2026Tiers
        let isMFJ = dataManager.filingStatus == .marriedFilingJointly
        let magi = dataManager.scenarioIRMAA.magi
        let currentTier = dataManager.scenarioIRMAA.tier
        let standardB = DataManager.irmaaStandardPartB

        var segments: [IRMAATierSegment] = []
        for i in tiers.indices {
            let threshold = isMFJ ? tiers[i].mfjThreshold : tiers[i].singleThreshold
            let nextThreshold: Double
            if i + 1 < tiers.count {
                nextThreshold = isMFJ ? tiers[i + 1].mfjThreshold : tiers[i + 1].singleThreshold
            } else {
                nextThreshold = max(threshold + 300_000, magi * 1.2)
            }

            let surchargeB = tiers[i].partBMonthly - standardB
            let surchargeD = tiers[i].partDMonthly
            let annualSurcharge = (surchargeB + surchargeD) * 12

            segments.append(IRMAATierSegment(
                tier: i,
                label: i == 0 ? "$0/yr" : "+\(chartYAxisLabel(max(0, annualSurcharge)))/yr",
                rangeStart: threshold,
                rangeEnd: nextThreshold,
                surchargePerPerson: max(0, annualSurcharge),
                isCurrent: currentTier == i
            ))
        }
        return segments
    }

    @ViewBuilder
    private var irmaaTierChart: some View {
        if dataManager.medicareMemberCount > 0 {
            let irmaa = dataManager.scenarioIRMAA
            let magi = irmaa.magi
            let segments = irmaaTierSegments
            let memberCount = dataManager.medicareMemberCount
            let tierColors: [Color] = [
                Color(red: 0.05, green: 0.78, blue: 0.35),   // Standard — emerald green
                Color(red: 0.98, green: 0.78, blue: 0.0),    // Tier 1 — bright gold
                Color(red: 1.0, green: 0.50, blue: 0.0),     // Tier 2 — vivid orange
                Color(red: 0.92, green: 0.22, blue: 0.50),   // Tier 3 — hot pink
                Color(red: 0.58, green: 0.22, blue: 0.88),   // Tier 4 — vivid purple
                Color(red: 0.18, green: 0.30, blue: 0.85),   // Tier 5 — deep blue
            ]

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.85), .red.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "heart.text.square.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("IRMAA Medicare Surcharge")
                            .font(.headline)
                        Text("Based on \(dataManager.filingStatus.rawValue) MAGI · Affects \(dataManager.currentYear + 2) premiums")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Pure SwiftUI bar + labels (single GeometryReader = perfect alignment)
                let irmaaChartMax = segments.last?.rangeEnd ?? 1
                let irmaaBarHeight: CGFloat = 36

                GeometryReader { geo in
                    let w = geo.size.width

                    // Colored tier bars
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        let color = tierColors[min(index, tierColors.count - 1)]
                        let x = w * segment.rangeStart / irmaaChartMax
                        let segW = w * (segment.rangeEnd - segment.rangeStart) / irmaaChartMax
                        let isFirst = index == 0
                        let isLastSeg = index == segments.count - 1

                        if isFirst {
                            UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 0)
                                .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                                .frame(width: segW, height: irmaaBarHeight)
                                .offset(x: x, y: 30)
                        } else if isLastSeg {
                            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 5, topTrailingRadius: 5)
                                .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                                .frame(width: segW, height: irmaaBarHeight)
                                .offset(x: x, y: 30)
                        } else {
                            Rectangle()
                                .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                                .frame(width: segW, height: irmaaBarHeight)
                                .offset(x: x, y: 30)
                        }
                    }

                    // MAGI marker line (solid)
                    let magiX = w * magi / irmaaChartMax
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2.5, height: irmaaBarHeight + 10)
                        .offset(x: magiX - 1.25, y: 25)

                    // MAGI label above bar
                    VStack(spacing: 1) {
                        Text("Your MAGI")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(chartYAxisLabel(magi))
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .position(x: magiX, y: 13)

                    // Surcharge + range labels below bar
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        let isLast = index == segments.count - 1
                        let segW = w * (segment.rangeEnd - segment.rangeStart) / irmaaChartMax
                        let segX = w * segment.rangeStart / irmaaChartMax
                        let centerX = segX + segW / 2

                        VStack(spacing: 1) {
                            Text(segment.label)
                                .font(.system(size: segW > 50 ? 9 : 7, weight: segment.isCurrent ? .bold : .semibold))
                                .foregroundStyle(tierColors[min(index, tierColors.count - 1)])
                            if segment.tier == 0 {
                                Text("< \(chartYAxisLabel(segments.count > 1 ? segments[1].rangeStart : 0))")
                                    .font(.system(size: segW > 50 ? 8 : 7))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(chartYAxisLabel(segment.rangeStart))\(isLast ? "+" : "–\(chartYAxisLabel(segment.rangeEnd))")")
                                    .font(.system(size: segW > 50 ? 8 : 7))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .position(x: centerX, y: irmaaBarHeight + 30 + 18)
                    }
                }
                .frame(height: irmaaBarHeight + 30 + 36)

                // Callouts
                VStack(alignment: .leading, spacing: 6) {
                    if irmaa.tier == 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("No IRMAA surcharge")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Tier \(irmaa.tier): \(irmaa.annualSurchargePerPerson, format: .currency(code: "USD").precision(.fractionLength(0)))/yr per person\(memberCount > 1 ? " (\(dataManager.scenarioIRMAATotalSurcharge, format: .currency(code: "USD").precision(.fractionLength(0))) household)" : "")")
                                .font(.caption)
                        }
                    }

                    if let distanceToNext = irmaa.distanceToNextTier, distanceToNext > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(distanceToNext < 10_000 ? .orange : .blue)
                                .font(.caption)
                            Text("\(distanceToNext, format: .currency(code: "USD").precision(.fractionLength(0))) below next IRMAA cliff")
                                .font(.caption)
                                .foregroundStyle(distanceToNext < 10_000 ? .orange : .secondary)
                        }
                    }

                    if irmaa.tier > 0, let distanceToPrev = irmaa.distanceToPreviousTier {
                        let savingsPerPerson = irmaa.annualSurchargePerPerson - dataManager.scenarioIRMAAPreviousTierAnnualSurcharge
                        let householdSavings = savingsPerPerson * Double(memberCount)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Reduce by \(distanceToPrev + 1, format: .currency(code: "USD").precision(.fractionLength(0))) to save \(householdSavings, format: .currency(code: "USD").precision(.fractionLength(0)))/yr")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
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
                    Text("No action items yet. Add income sources and explore Scenarios to generate your to-do list.")
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
        .background(Color(PlatformColor.systemBackground))
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

                if dataManager.hasInheritedAccounts {
                    BalanceCard(
                        title: "Inherited IRA",
                        amount: dataManager.totalInheritedBalance,
                        color: .orange
                    )
                }
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
        .background(Color(PlatformColor.systemBackground))
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
        .background(Color(PlatformColor.systemBackground))
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
        .background(Color(PlatformColor.secondarySystemBackground))
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
