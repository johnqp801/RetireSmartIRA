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
    @State private var taxableIncomeExpanded = false
    @State private var totalTaxExpanded = false
    @State private var deductionExpanded = false

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
            LazyVStack(spacing: 24) {
                headerCard
                exportPDFButton
                actionToDoList
                incomeBreakdown
                incomeCompositionChart
                taxPlanningDecisions
                ReduceAGISection()
                legacyStrategySummary
                taxProjection
                taxBracketChart
                stateBracketChart
                irmaaTierChart
                householdMedicareCostSection
                niitPositionChart
                accountBalances
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                LazyVStack(spacing: 24) {
                    headerCard
                    exportPDFButton
                    actionToDoList
                    incomeBreakdown
                    incomeCompositionChart
                    taxPlanningDecisions
                    ReduceAGISection()
                    legacyStrategySummary
                    accountBalances
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                LazyVStack(spacing: 24) {
                    taxProjection
                    taxBracketChart
                    stateBracketChart
                    irmaaTierChart
                    householdMedicareCostSection
                    niitPositionChart
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
            .background(Color.UI.brandTeal.opacity(0.1))
            .foregroundStyle(Color.UI.brandTeal)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isGeneratingPDF)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header row: year + filing status
            HStack {
                Text("\(String(dataManager.currentYear)) Tax Year")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()

                Text(dataManager.filingStatus.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Metrics row: ages + RMD status, each as its own MetricCard
            HStack(spacing: Spacing.sm) {
                MetricCard(
                    label: "Your Age",
                    value: "\(dataManager.currentAge)",
                    category: .informational
                )

                if dataManager.enableSpouse {
                    MetricCard(
                        label: "\(dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName) Age",
                        value: "\(dataManager.spouseCurrentAge)",
                        category: .informational
                    )
                }

                if dataManager.isRMDRequired {
                    MetricCard(
                        label: "RMD Status",
                        value: "Required",
                        category: .informational
                    )
                } else {
                    MetricCard(
                        label: "Years Until RMD",
                        value: "\(dataManager.yearsUntilRMD)",
                        category: .informational
                    )
                }
            }
        }
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
                InlineHint("Add income sources in the Income & Deductions tab")
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
                            .foregroundStyle(Color.UI.textSecondary)
                    }
                    Spacer()
                    Text(inheritedRMD, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.medium)
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
                            .foregroundStyle(remaining <= 1 ? Color.Semantic.red : Color.Semantic.amber)
                        Text("\(name): \(remaining == 0 ? "deadline this year!" : "\(remaining) year\(remaining == 1 ? "" : "s") until 10-year deadline")")
                            .font(.caption)
                            .foregroundStyle(remaining <= 1 ? Color.Semantic.red : Color.Semantic.amber)
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
                        color: Color.UI.brandTeal
                    )
                }
                if dataManager.scenarioTotalExtraWithdrawal > 0 {
                    decisionRow(
                        icon: "arrow.down.circle.fill",
                        label: "Extra Withdrawals",
                        amount: dataManager.scenarioTotalExtraWithdrawal,
                        color: Color.UI.brandTeal
                    )
                }
                if dataManager.scenarioTotalQCD > 0 {
                    decisionRow(
                        icon: "heart.fill",
                        label: "Qualified Charitable Distribution",
                        amount: dataManager.scenarioTotalQCD,
                        color: Color.UI.brandTeal
                    )
                }
                if dataManager.stockDonationEnabled && dataManager.stockCurrentValue > 0 {
                    decisionRow(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "Appreciated Stock Donation",
                        amount: dataManager.stockCurrentValue,
                        color: Color.UI.brandTeal
                    )
                }
                if dataManager.cashDonationAmount > 0 {
                    decisionRow(
                        icon: "banknote.fill",
                        label: "Cash Donation",
                        amount: dataManager.cashDonationAmount,
                        color: Color.UI.brandTeal
                    )
                }

                Divider()

                // Deduction method
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(Color.UI.brandTeal)
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
                        .foregroundStyle(Color.UI.brandTeal)
                }
            } else {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("Visit Scenarios to model Roth conversions, withdrawals, and charitable giving")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Still show deduction even if no active scenario
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(Color.UI.brandTeal)
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
                        .foregroundStyle(Color.UI.brandTeal)
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

    // MARK: - Legacy Strategy Summary

    @ViewBuilder
    private var legacyStrategySummary: some View {
        if dataManager.enableLegacyPlanning && dataManager.hasActiveScenario
            && dataManager.scenarioTotalRothConversion > 0 {
            let taxCost = dataManager.legacyUserCurrentCost
            let familyGain = dataManager.legacyFamilyWealthAdvantage
            let conversionAmount = dataManager.scenarioTotalRothConversion

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("Long-Term Strategy")
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Text("This scenario converts ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(conversionAmount, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(" to Roth.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tax cost this year")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(taxCost, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }

                        Image(systemName: "arrow.right")

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Projected family wealth gain")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(familyGain >= 0
                                ? "+\(familyGain, format: .currency(code: "USD").precision(.fractionLength(0)))"
                                : "-\(abs(familyGain), format: .currency(code: "USD").precision(.fractionLength(0)))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                    }

                    if dataManager.widowHasBracketJump {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.UI.brandTeal)
                            Text("Also avoids a surviving spouse bracket jump from MFJ to Single filing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Based on projected compounding through life expectancy. Heir type: \(dataManager.legacyHeirTypeDescription)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.UI.brandTeal.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Tax Projection

    private var taxProjection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax Projection")
                .font(.headline)

            if dataManager.hasActiveScenario {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scenario Decisions Included")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Semantic.amber)
                    if dataManager.scenarioTotalRothConversion > 0 {
                        scenarioDecisionRow(label: "Roth Conversion", value: dataManager.scenarioTotalRothConversion)
                    }
                    if dataManager.scenarioTotalExtraWithdrawal > 0 {
                        scenarioDecisionRow(label: "Extra Withdrawals", value: dataManager.scenarioTotalExtraWithdrawal)
                    }
                    if dataManager.scenarioTotalQCD > 0 {
                        scenarioDecisionRow(label: "QCD", value: -dataManager.scenarioTotalQCD)
                    }
                    if dataManager.stockDonationEnabled && dataManager.stockCurrentValue > 0 {
                        scenarioDecisionRow(label: "Stock Donation", value: -dataManager.stockCurrentValue)
                    }
                    if dataManager.cashDonationAmount > 0 {
                        scenarioDecisionRow(label: "Cash Donation", value: -dataManager.cashDonationAmount)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Semantic.amberTint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Group {
                DisclosureGroup(isExpanded: $taxableIncomeExpanded) {
                    taxableIncomeBreakdown
                } label: {
                    taxRow(label: "Taxable Income", value: dataManager.scenarioTaxableIncome, isBold: true)
                }

                Divider()

                // Standard tax amounts render in the default neutral color.
                // Red is reserved for adverse signals (penalties, deadlines,
                // cliff crossings, unfavorable scenario deltas) — see
                // docs/beta-feedback/2026-04-24-color-system-research.md.
                taxRow(label: "Federal Tax", value: dataManager.scenarioFederalTax)
                taxRow(label: "State Tax (\(dataManager.selectedState.abbreviation))", value: dataManager.scenarioStateTax)

                if dataManager.scenarioNIITAmount > 0 {
                    taxRow(label: "NIIT (3.8% Surtax)", value: dataManager.scenarioNIITAmount)
                }

                if dataManager.scenarioAMTAmount > 0 {
                    taxRow(label: "AMT (26%/28%)", value: dataManager.scenarioAMTAmount)
                }

                DisclosureGroup(isExpanded: $totalTaxExpanded) {
                    totalTaxBreakdown
                } label: {
                    taxRow(label: "Total Tax", value: dataManager.scenarioTotalTax, isBold: true)
                }

                // NIIT safe zone warning (has investment income but below threshold)
                if dataManager.scenarioNetInvestmentIncome > 0 && dataManager.scenarioNIITAmount == 0 {
                    let niitDistance = dataManager.scenarioNIIT.distanceToThreshold
                    if niitDistance > 0 && niitDistance < 10_000 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.Semantic.amber)
                                .font(.caption)
                            Text("\(niitDistance, format: .currency(code: "USD")) below NIIT threshold")
                                .font(.caption)
                                .foregroundStyle(Color.Semantic.amber)
                        }
                    }
                }

                // Local tax note
                InlineHint("State tax only \u{2014} local/city taxes (e.g. NYC) are not included.")
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
                            .foregroundStyle(Color.UI.brandTeal)
                        Text("IRMAA: Standard (no surcharge)")
                            .font(.subheadline)
                            .foregroundStyle(Color.UI.brandTeal)
                            .fontWeight(.semibold)
                    }

                    if let distanceToNext = irmaa.distanceToNextTier {
                        HStack(spacing: 6) {
                            // Status indicator (threshold-based icon flip) — distinct from InfoButton/InlineHint vocabulary.
                            // See docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md §4.
                            Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(distanceToNext < 10_000 ? Color.Semantic.amber : Color.UI.brandTeal)
                                .font(.caption)
                            Text("\(distanceToNext, format: .currency(code: "USD")) below first IRMAA cliff")
                                .font(.caption)
                                .foregroundStyle(distanceToNext < 10_000 ? Color.Semantic.amber : .secondary)
                        }
                    }
                } else {
                    // Tier 1-5: Surcharge + cliff distances
                    taxRow(label: "IRMAA Surcharge (per person)", value: irmaa.annualSurchargePerPerson)

                    if memberCount > 1 {
                        taxRow(label: "IRMAA Household (\(memberCount) on Medicare)", value: dataManager.scenarioIRMAATotalSurcharge, isBold: true)
                    }

                    // Distance to next tier
                    if let distanceToNext = irmaa.distanceToNextTier, distanceToNext > 0 {
                        HStack(spacing: 6) {
                            // Status indicator (threshold-based icon flip) — distinct from InfoButton/InlineHint vocabulary.
                            // See docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md §4.
                            Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(distanceToNext < 10_000 ? Color.Semantic.amber : Color.UI.brandTeal)
                                .font(.caption)
                            Text("\(distanceToNext, format: .currency(code: "USD")) until next IRMAA tier")
                                .font(.caption)
                                .foregroundStyle(distanceToNext < 10_000 ? Color.Semantic.amber : .secondary)
                        }
                    }

                    // Actionable: drop a tier
                    if let distanceToPrev = irmaa.distanceToPreviousTier {
                        let savingsPerPerson = irmaa.annualSurchargePerPerson - dataManager.scenarioIRMAAPreviousTierAnnualSurcharge
                        let householdSavings = savingsPerPerson * Double(memberCount)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.UI.brandTeal)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reduce income by \(distanceToPrev + 1, format: .currency(code: "USD")) to drop a tier")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Saves \(householdSavings, format: .currency(code: "USD"))/year\(memberCount > 1 ? " household" : "")")
                                    .font(.caption2)
                                    .foregroundStyle(Color.UI.brandTeal)
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

                if dataManager.taxExemptInterestIRMAAImpact > 0 {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.Semantic.amber)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tax-exempt interest is increasing your Medicare premiums.")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("Your \(dataManager.taxExemptInterestTotal, format: .currency(code: "USD")) in tax-free interest (muni bonds, tax-free money markets) is not federally taxed, but the IRS includes it in the MAGI used for IRMAA. This adds \(dataManager.taxExemptInterestIRMAAImpact, format: .currency(code: "USD"))/year to your household Medicare surcharges.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if dataManager.totalWithholding > 0 {
                Divider()
                if dataManager.totalFederalWithholding > 0 {
                    taxRow(label: "Federal Withholding Paid", value: dataManager.totalFederalWithholding)
                }
                if dataManager.totalStateWithholding > 0 {
                    taxRow(label: "State Withholding Paid", value: dataManager.totalStateWithholding)
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
                    taxRow(label: "Per-Quarter Payment", value: payments.q1, isBold: true, color: Color.Semantic.amber)
                } else {
                    HStack {
                        Text("Quarterly Range")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(minQ.formatted(.currency(code: "USD"))) \u{2013} \(maxQ.formatted(.currency(code: "USD")))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.Semantic.amber)
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

    private func scenarioDecisionRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value < 0 ? "−\(abs(value).formatted(.currency(code: "USD")))" : "+\(value.formatted(.currency(code: "USD")))")
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Taxable Income Breakdown

    private var taxableIncomeBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ─── Income Sources ───
            breakdownHeader("Income Sources")

            // List each ordinary income source by name
            ForEach(dataManager.incomeSources.filter({
                $0.type != .socialSecurity && $0.type != .capitalGainsLong
                && $0.type != .qualifiedDividends && $0.type != .taxExemptInterest
                && $0.annualAmount > 0
            })) { source in
                breakdownRow(source.name, value: source.annualAmount)
            }

            // Taxable Social Security
            if dataManager.scenarioTaxableSocialSecurity > 0 {
                breakdownRow(
                    "Taxable Social Security (\(dataManager.socialSecurityTaxablePercent)%)",
                    value: dataManager.scenarioTaxableSocialSecurity
                )
            }

            // Qualified Dividends
            if dataManager.qualifiedDividendsTotal > 0 {
                breakdownRow("Qualified Dividends", value: dataManager.qualifiedDividendsTotal)
            }

            // Long-term Capital Gains
            if dataManager.longTermCapGainsTotal > 0 {
                breakdownRow("Long-term Capital Gains", value: dataManager.longTermCapGainsTotal)
            }

            breakdownSubtotal("Base Income", value: dataManager.scenarioBaseIncome)

            // ─── RMDs & Scenario Decisions ───
            if dataManager.scenarioAdjustedRMD > 0 || dataManager.hasActiveScenario {
                // RMDs are mandatory — show separately from scenario decisions
                if dataManager.scenarioAdjustedRMD > 0 {
                    breakdownRow("Taxable RMDs (after QCD offset)", value: dataManager.scenarioAdjustedRMD)
                }

                // Scenario decisions are user choices
                if dataManager.hasActiveScenario {
                    breakdownHeader("Scenario Decisions")

                    if dataManager.scenarioTotalRothConversion > 0 {
                        breakdownRow("Roth Conversions", value: dataManager.scenarioTotalRothConversion)
                    }

                    if dataManager.scenarioTotalExtraWithdrawal > 0 {
                        breakdownRow("Extra Withdrawals", value: dataManager.scenarioTotalExtraWithdrawal)
                    }

                    if dataManager.scenarioStockGainAvoided > 0 {
                        breakdownRow("Stock Gain Avoided", value: -dataManager.scenarioStockGainAvoided)
                    }
                }

                breakdownSubtotal("Gross Income", value: dataManager.scenarioGrossIncome)
            }

            // ─── Deduction ───
            breakdownHeader("Deduction")

            if dataManager.scenarioEffectiveItemize {
                DisclosureGroup(isExpanded: $deductionExpanded) {
                    deductionBreakdownContent
                } label: {
                    breakdownRow("Itemized Deductions", value: -dataManager.effectiveDeductionAmount)
                }
            } else {
                DisclosureGroup(isExpanded: $deductionExpanded) {
                    standardDeductionBreakdownContent
                } label: {
                    breakdownRow("Standard Deduction", value: -dataManager.effectiveDeductionAmount)
                }
            }

            // Final total
            Divider()
            HStack {
                Text("Taxable Income")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(dataManager.scenarioTaxableIncome, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Total Tax Breakdown

    private var totalTaxBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            let fedBreakdown = dataManager.scenarioFederalTaxBreakdown

            // ─── Federal Ordinary Income Tax ───
            breakdownHeader("Federal Tax — Ordinary Income")

            ForEach(fedBreakdown.ordinaryBrackets) { line in
                breakdownRow(
                    "\(formatCurrency(line.taxableInBracket)) at \(formatPercent(line.rate))",
                    value: line.taxFromBracket
                )
            }

            breakdownSubtotal("Ordinary Income Tax", value: fedBreakdown.ordinaryTax)

            // ─── Federal Capital Gains Tax ───
            if fedBreakdown.preferentialIncome > 0 {
                breakdownHeader("Federal Tax — Capital Gains & Qualified Dividends")

                ForEach(fedBreakdown.capGainsBrackets) { line in
                    if line.rate == 0 {
                        breakdownRow(
                            "\(formatCurrency(line.taxableInBracket)) at 0% (tax-free)",
                            value: 0
                        )
                    } else {
                        breakdownRow(
                            "\(formatCurrency(line.taxableInBracket)) at \(formatPercent(line.rate))",
                            value: line.taxFromBracket
                        )
                    }
                }

                breakdownSubtotal("Capital Gains Tax", value: fedBreakdown.capGainsTax)
            }

            Divider()
            HStack {
                Text("Federal Tax")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(fedBreakdown.totalFederalTax, format: .currency(code: "USD"))
                    .font(.caption)
                    .fontWeight(.bold)
            }

            // ─── State Tax ───
            let stateBreakdown = dataManager.scenarioStateTaxBreakdown

            breakdownHeader("State Tax (\(dataManager.selectedState.abbreviation))")

            if !stateBreakdown.bracketBreakdown.isEmpty {
                ForEach(stateBreakdown.bracketBreakdown) { line in
                    breakdownRow(
                        "\(formatCurrency(line.taxableInBracket)) at \(String(format: "%.1f%%", line.rate * 100))",
                        value: line.taxFromBracket
                    )
                }
            } else if let flatRate = stateBreakdown.flatRate {
                breakdownRow(
                    "\(formatCurrency(stateBreakdown.adjustedTaxableIncome)) at \(String(format: "%.2f%%", flatRate * 100)) flat",
                    value: stateBreakdown.totalStateTax
                )
            } else {
                breakdownRow("No state income tax", value: 0)
            }

            // Exemptions
            if stateBreakdown.totalExempted > 0 {
                breakdownRow("Retirement Income Exempt", value: -stateBreakdown.totalExempted)
            }

            // CA exemption credits
            if dataManager.selectedState == .california {
                let credits = TaxCalculationEngine.californiaExemptionCredits(
                    filingStatus: dataManager.filingStatus,
                    agi: stateBreakdown.adjustedTaxableIncome,
                    currentAge: dataManager.currentAge,
                    enableSpouse: dataManager.enableSpouse,
                    spouseBirthYear: dataManager.spouseBirthYear,
                    currentYear: dataManager.currentYear
                )
                if credits > 0 {
                    breakdownRow("Exemption Credits", value: -credits)
                }
            }

            Divider()
            HStack {
                Text("State Tax (\(dataManager.selectedState.abbreviation))")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(stateBreakdown.totalStateTax, format: .currency(code: "USD"))
                    .font(.caption)
                    .fontWeight(.bold)
            }

            // ─── NIIT ───
            if dataManager.scenarioNIITAmount > 0 {
                let niit = dataManager.scenarioNIIT
                breakdownHeader("NIIT (3.8% Surtax)")

                breakdownRow("Net Investment Income", value: niit.netInvestmentIncome)
                breakdownRow("MAGI Excess over \(formatCurrency(niit.threshold))", value: niit.magiExcess)
                breakdownRow(
                    "3.8% × \(formatCurrency(niit.taxableNII))",
                    value: niit.annualNIITax
                )
            }

            // ─── AMT ───
            if dataManager.scenarioAMTAmount > 0 {
                breakdownHeader("AMT (Alternative Minimum Tax)")
                breakdownRow("AMT exceeds regular tax by", value: dataManager.scenarioAMTAmount)
            }

            // ─── Grand Total ───
            Divider()
            HStack {
                Text("Total Tax")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(dataManager.scenarioTotalTax, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
        }
        .padding(.top, 4)
    }

    private func formatCurrency(_ amount: Double) -> String {
        amount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private func formatPercent(_ rate: Double) -> String {
        "\(Int(rate * 100))%"
    }

    private func breakdownHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 6)
    }

    private func breakdownRow(_ label: String, value: Double, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value, format: .currency(code: "USD"))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color ?? .primary)
        }
    }

    private func breakdownSubtotal(_ label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Divider()
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(value, format: .currency(code: "USD"))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Deduction Breakdown

    /// Itemized deduction breakdown: SALT (with cap), medical (with AGI floor), charitable, other items.
    private var deductionBreakdownContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // SALT section
            if dataManager.totalSALTBeforeCap > 0 {
                breakdownDetail("SALT (before cap)")
                if dataManager.propertyTaxAmount > 0 {
                    breakdownDetailRow("Property Tax", value: dataManager.propertyTaxAmount)
                }
                if dataManager.totalStateWithholding > 0 {
                    breakdownDetailRow("State Withholding", value: dataManager.totalStateWithholding)
                }
                if dataManager.priorYearSALTDeductible > 0 {
                    breakdownDetailRow("Prior Year State Balance", value: dataManager.priorYearSALTDeductible)
                }
                if dataManager.additionalSALTAmount > 0 {
                    breakdownDetailRow("Additional SALT", value: dataManager.additionalSALTAmount)
                }
                breakdownDetailRow("SALT Total (pre-cap)", value: dataManager.totalSALTBeforeCap)
                if dataManager.totalSALTBeforeCap > dataManager.saltCap {
                    let capStr = dataManager.saltCap.formatted(.currency(code: "USD"))
                    breakdownDetailRow("Federal Cap (\(capStr))",
                                       value: -(dataManager.totalSALTBeforeCap - dataManager.saltAfterCap), color: Color.Semantic.red)
                }
                breakdownDetailRow("SALT Deducted", value: dataManager.saltAfterCap, isBold: true)
            }

            // Medical section
            if dataManager.totalMedicalExpenses > 0 {
                breakdownDetail("Medical Expenses")
                breakdownDetailRow("Total Medical", value: dataManager.totalMedicalExpenses)
                breakdownDetailRow("7.5% AGI Floor", value: -dataManager.medicalAGIFloor, color: Color.Semantic.red)
                breakdownDetailRow("Deductible Medical", value: dataManager.deductibleMedicalExpenses, isBold: true)
            }

            // Other itemized (mortgage interest, etc.)
            ForEach(dataManager.deductionItems.filter({
                $0.type != .propertyTax && $0.type != .saltTax && $0.type != .medicalExpenses
                && $0.annualAmount > 0
            })) { item in
                breakdownDetailRow(item.name, value: item.annualAmount)
            }

            // Charitable from scenarios
            if dataManager.scenarioCharitableDeductions > 0 {
                breakdownDetail("Charitable (from Scenarios)")
                if dataManager.stockDonationEnabled && dataManager.stockCurrentValue > 0 {
                    let stockValue = dataManager.scenarioStockIsLongTerm ? dataManager.stockCurrentValue : dataManager.stockPurchasePrice
                    breakdownDetailRow("Donated Stock", value: stockValue)
                }
                if dataManager.cashDonationAmount > 0 {
                    breakdownDetailRow("Cash Donations", value: dataManager.cashDonationAmount)
                }
            }

            Divider()
            breakdownDetailRow("Total Itemized", value: dataManager.totalItemizedDeductions, isBold: true)

            // Show standard deduction comparison
            if dataManager.totalItemizedDeductions > dataManager.standardDeductionAmount {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                        .font(.caption2)
                    Text("Itemizing saves \(dataManager.totalItemizedDeductions - dataManager.standardDeductionAmount, format: .currency(code: "USD")) vs standard deduction")
                        .font(.caption2)
                        .foregroundStyle(Color.UI.brandTeal)
                }
                .padding(.top, 2)
            }
        }
        .padding(.leading, 8)
        .padding(.top, 4)
    }

    /// Standard deduction breakdown: base amount + age 65+ additions + OBBBA senior bonus.
    private var standardDeductionBreakdownContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            breakdownDetailRow("Standard Deduction", value: dataManager.standardDeductionAmount)

            // Show what itemized would be for comparison
            if !dataManager.deductionItems.isEmpty || dataManager.scenarioCharitableDeductions > 0 {
                breakdownDetailRow("Your Itemized Total", value: dataManager.totalItemizedDeductions)

                if dataManager.standardDeductionAmount >= dataManager.totalItemizedDeductions {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.UI.brandTeal)
                            .font(.caption2)
                        Text("Standard deduction saves \(dataManager.standardDeductionAmount - dataManager.totalItemizedDeductions, format: .currency(code: "USD")) vs itemizing")
                            .font(.caption2)
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.top, 4)
    }

    private func breakdownDetail(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func breakdownDetailRow(_ label: String, value: Double, isBold: Bool = false, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value, format: .currency(code: "USD"))
                .font(.caption2)
                .fontWeight(isBold ? .semibold : .regular)
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

    /// Color mapping for income categories in pie/donut charts.
    /// Spreads income types across the full Chart palette (heroTeal +
    /// 6 tealRamps + 5 grays + sand callout = 13 distinct color slots).
    /// "Kinship" pairs (Dividends/Qualified, Interest/Tax-Exempt,
    /// RMD/Inherited) sit in adjacent palette slots so related categories
    /// read as related-but-distinct in the chart.
    ///
    /// Cap Gains LT keeps the warm sand callout (preferred-rate distinction).
    /// Cap Gains ST joins the gray family because ST gains are taxed as
    /// ordinary income, conceptually closer to RMD/Roth/Employment.
    private func incomeColor(for category: String) -> Color {
        switch category {
        // Hero — the largest "primary" income for most retirees
        case "Social Security":                                  return Color.Chart.heroTeal

        // Teal ramp family: pension/dividends/interest (recurring yield streams)
        case "Pension":                                          return Color.Chart.tealRamp1
        case "Dividends":                                        return Color.Chart.tealRamp2
        case "Qualified Dividends":                              return Color.Chart.tealRamp3
        case "Interest":                                         return Color.Chart.tealRamp4
        case "Tax-Exempt Interest":                              return Color.Chart.tealRamp5
        case "State Tax Refund":                                 return Color.Chart.tealRamp6

        // Sand callout: long-term cap gains (preferred-rate distinction)
        case "Capital Gains (Long-term)":                        return Color.Chart.callout

        // Gray family: distribution events + ordinary-income-rate items
        case "RMD":                                              return Color.Chart.gray1
        case "Inherited IRA RMD":                                return Color.Chart.gray2
        case "Capital Gains (Short-term)":                       return Color.Chart.gray3
        case "Roth Conversion":                                  return Color.Chart.gray4
        case "Employment/Other Income":                          return Color.Chart.gray5

        // Anything else — shared muted gray fallback
        default:                                                 return Color.Chart.gray5
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
                                    colors: [Color.Chart.heroTeal, Color.Chart.tealRamp2],
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
                            colors: [Color.Chart.heroTeal.opacity(0.35), Color.Chart.tealRamp2.opacity(0.35)],
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
                Color.Chart.tealRamp1,  // 10%
                Color.Chart.tealRamp2,  // 12%
                Color.Chart.tealRamp3,  // 22%
                Color.Chart.tealRamp4,  // 24%
                Color.Chart.tealRamp5,  // 32%
                Color.Chart.tealRamp6,  // 35%
                Color.Chart.callout,    // 37%
            ]

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.Chart.tealRamp1, Color.Chart.tealRamp6],
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

                }
                .frame(height: topPad + barHeight + 6)

                // Bracket legend below bar
                let legendSegments = visibleSegments
                HStack(spacing: 0) {
                    ForEach(Array(legendSegments.enumerated()), id: \.element.id) { index, segment in
                        let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                        let isLast = index == legendSegments.count - 1
                        let color = bracketColors[min(globalIdx, bracketColors.count - 1)]
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(segment.label)
                                    .font(.system(size: 10, weight: segment.isCurrent ? .bold : .medium))
                                    .foregroundStyle(color)
                                Text("\(chartYAxisLabel(segment.rangeStart))\(isLast && segment.rate >= 0.37 ? "+" : "–\(chartYAxisLabel(segment.rangeEnd))")")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)

                // Room remaining callout
                if bracketInfo.roomRemaining > 0 {
                    let nextRate = nextBracketRate(after: bracketInfo.currentRate)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(Color.UI.brandTeal)
                            .font(.caption)
                        Text("**\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))** room before the \(nextRate)% bracket")
                            .font(.caption)
                    }
                } else if bracketInfo.currentRate >= 0.37 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.Semantic.amber)
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
                            colors: [Color.Chart.tealRamp1.opacity(0.3), Color.Chart.tealRamp6.opacity(0.3)],
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
                label: i == 0 ? "No Surcharge" : "Tier \(i)",
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
                Color.Chart.tealRamp1,  // Standard — no surcharge
                Color.Chart.tealRamp2,  // Tier 1
                Color.Chart.tealRamp3,  // Tier 2
                Color.Chart.tealRamp4,  // Tier 3
                Color.Chart.tealRamp5,  // Tier 4
                Color.Chart.tealRamp6,  // Tier 5
            ]

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.Chart.tealRamp1, Color.Chart.tealRamp6],
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
                        Text("Based on \(dataManager.filingStatus.rawValue) MAGI · Affects \(String(dataManager.currentYear + 2)) premiums")
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

                }
                .frame(height: irmaaBarHeight + 30 + 6)

                // Tier legend below bar
                HStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        let isLast = index == segments.count - 1
                        let color = tierColors[min(index, tierColors.count - 1)]
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(segment.label)
                                    .font(.system(size: 10, weight: segment.isCurrent ? .bold : .medium))
                                    .foregroundStyle(color)
                                if segment.tier == 0 {
                                    Text("< \(chartYAxisLabel(segments.count > 1 ? segments[1].rangeStart : 0))")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(chartYAxisLabel(segment.rangeStart))\(isLast ? "+" : "–\(chartYAxisLabel(segment.rangeEnd))")")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)

                // Callouts
                VStack(alignment: .leading, spacing: 6) {
                    if irmaa.tier == 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.UI.brandTeal)
                                .font(.caption)
                            Text("No IRMAA surcharge")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.UI.brandTeal)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.Semantic.amber)
                                .font(.caption)
                            Text("Tier \(irmaa.tier): \(irmaa.annualSurchargePerPerson, format: .currency(code: "USD").precision(.fractionLength(0)))/yr per person\(memberCount > 1 ? " (\(dataManager.scenarioIRMAATotalSurcharge, format: .currency(code: "USD").precision(.fractionLength(0))) household)" : "")")
                                .font(.caption)
                        }
                    }

                    if let distanceToNext = irmaa.distanceToNextTier, distanceToNext > 0 {
                        HStack(spacing: 6) {
                            // Status indicator (threshold-based icon flip) — distinct from InfoButton/InlineHint vocabulary.
                            // See docs/superpowers/specs/2026-05-01-inline-hint-vocabulary-design.md §4.
                            Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                                .foregroundStyle(distanceToNext < 10_000 ? Color.Semantic.amber : Color.UI.brandTeal)
                                .font(.caption)
                            Text("\(distanceToNext, format: .currency(code: "USD").precision(.fractionLength(0))) below next IRMAA cliff")
                                .font(.caption)
                                .foregroundStyle(distanceToNext < 10_000 ? Color.Semantic.amber : .secondary)
                        }
                    }

                    if irmaa.tier > 0, let distanceToPrev = irmaa.distanceToPreviousTier {
                        let savingsPerPerson = irmaa.annualSurchargePerPerson - dataManager.scenarioIRMAAPreviousTierAnnualSurcharge
                        let householdSavings = savingsPerPerson * Double(memberCount)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.UI.brandTeal)
                                .font(.caption)
                            Text("Reduce by \(distanceToPrev + 1, format: .currency(code: "USD").precision(.fractionLength(0))) to save \(householdSavings, format: .currency(code: "USD").precision(.fractionLength(0)))/yr")
                                .font(.caption)
                                .foregroundStyle(Color.UI.brandTeal)
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
                            colors: [Color.Chart.tealRamp1.opacity(0.3), Color.Chart.tealRamp6.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    // MARK: - Household Medicare Cost Section

    @ViewBuilder
    private var householdMedicareCostSection: some View {
        if dataManager.householdMedicareCostAnnual > 0
           || (dataManager.scenario.yourMedicarePlanType == .preMedicare
               && dataManager.currentAge >= 63 && dataManager.currentAge <= 64) {
            VStack(alignment: .leading, spacing: 8) {
                // Pre-Medicare 63-64 projection band
                if dataManager.scenario.yourMedicarePlanType == .preMedicare
                   && dataManager.currentAge >= 63 && dataManager.currentAge <= 64 {
                    let preMedicareIrmaa = TaxCalculationEngine.calculateIRMAA(
                        magi: dataManager.irmaaMAGIWrapped,
                        filingStatus: dataManager.filingStatus
                    )
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundStyle(Color.Semantic.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Decisions today affect Medicare premiums starting at age 65")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Current scenario projects to IRMAA tier \(preMedicareIrmaa.tier).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.Semantic.amberTint)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Medicare cost details (only shown when actively on Medicare)
                if dataManager.householdMedicareCostAnnual > 0 {
                    Text("Projected Medicare cost (\(dataManager.medicarePremiumProjectionYear))")
                        .font(.headline)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Medicare IRMAA premiums are based on income from 2 years prior. Decisions you make today affect your premiums in \(dataManager.medicarePremiumProjectionYear).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    medicareCostRow(label: "You", breakdown: dataManager.primaryMedicareCost)
                    if dataManager.enableSpouse {
                        medicareCostRow(label: "Spouse", breakdown: dataManager.spouseMedicareCost)
                    }

                    Divider()
                    HStack {
                        Text("Total annual")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(dataManager.householdMedicareCostAnnual, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
            }
            .padding()
            .background(Color.UI.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func medicareCostRow(label: String, breakdown: MedicareCostBreakdown) -> some View {
        if breakdown.planType == .preMedicare {
            HStack {
                Text(label)
                Spacer()
                Text("Pre-Medicare")
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(label) (\(breakdown.planType.rawValue))")
                        .font(.subheadline)
                    Spacer()
                    Text(breakdown.annualTotal, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                if breakdown.irmaaSurcharge > 0 {
                    HStack {
                        Text("  ↳ IRMAA surcharge (annual)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(breakdown.irmaaSurcharge * 12, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Chart 4: State Tax Bracket Position

    @ViewBuilder
    private var stateBracketChart: some View {
        let config = dataManager.selectedStateConfig
        switch config.taxSystem {
        case .progressive(let single, let married):
            let brackets = dataManager.filingStatus == .single ? single : married
            let income = dataManager.scenarioTaxableIncome
            if income > 0 && brackets.count > 1 {
                let bracketInfo = dataManager.stateBracketInfo(income: income, filingStatus: dataManager.filingStatus)

                // Build segments
                let segments: [BracketSegment] = brackets.enumerated().map { i, bracket in
                    let start = bracket.threshold
                    let end: Double = i + 1 < brackets.count ? brackets[i + 1].threshold : max(start + 50_000, income * 1.2)
                    let isCurrent = income > start && (i + 1 >= brackets.count || income <= brackets[i + 1].threshold)
                    return BracketSegment(
                        rate: bracket.rate,
                        label: String(format: "%.1f%%", bracket.rate * 100),
                        rangeStart: start,
                        rangeEnd: end,
                        isCurrent: isCurrent
                    )
                }

                // Map state brackets to Chart.tealRamp palette (up to 6 segments)
                let chartRamp: [Color] = [
                    Color.Chart.tealRamp1, Color.Chart.tealRamp2, Color.Chart.tealRamp3,
                    Color.Chart.tealRamp4, Color.Chart.tealRamp5, Color.Chart.tealRamp6
                ]
                let stateColors: [Color] = segments.enumerated().map { i, _ in
                    chartRamp[min(i, chartRamp.count - 1)]
                }

                let currentIdx = segments.firstIndex(where: { $0.isCurrent }) ?? 0
                let showThrough = min(currentIdx + 1, segments.count - 1)
                let visibleSegments = Array(segments.prefix(showThrough + 1))
                let chartMax = visibleSegments.last?.rangeEnd ?? 1
                let barHeight: CGFloat = 36
                let topPad: CGFloat = 24

                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.Chart.tealRamp1, Color.Chart.tealRamp5],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Image(systemName: "building.columns.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(dataManager.selectedState.rawValue) Tax Bracket Position")
                                .font(.headline)
                            Text(dataManager.filingStatus.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    // Bar chart
                    GeometryReader { geo in
                        let w = geo.size.width

                        ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                            let color = stateColors[min(index, stateColors.count - 1)]
                            let x = w * segment.rangeStart / chartMax
                            let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax

                            if index <= currentIdx {
                                Rectangle()
                                    .fill(color)
                                    .frame(width: segW, height: barHeight)
                                    .offset(x: x, y: topPad)
                            } else {
                                Rectangle()
                                    .fill(color.opacity(0.22))
                                    .frame(width: segW, height: barHeight)
                                    .offset(x: x, y: topPad)
                            }
                        }

                        // Bracket boundary lines
                        ForEach(Array(visibleSegments.dropFirst().enumerated()), id: \.element.id) { _, segment in
                            let bx = w * segment.rangeStart / chartMax
                            Rectangle()
                                .fill(Color.primary.opacity(0.2))
                                .frame(width: 1, height: barHeight)
                                .offset(x: bx - 0.5, y: topPad)
                        }

                        // Income marker (dashed)
                        let incomeX = w * income / chartMax
                        Path { path in
                            path.move(to: CGPoint(x: incomeX, y: topPad - 5))
                            path.addLine(to: CGPoint(x: incomeX, y: topPad + barHeight + 5))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .foregroundStyle(.primary)

                        // Income label
                        Text(chartYAxisLabel(income))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .position(x: incomeX, y: 10)

                        // Border
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            .frame(width: w, height: barHeight)
                            .offset(y: topPad)
                    }
                    .frame(height: topPad + barHeight + 6)

                    // Legend
                    HStack(spacing: 0) {
                        ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                            let isLast = index == visibleSegments.count - 1
                            let color = stateColors[min(index, stateColors.count - 1)]
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(segment.label)
                                        .font(.system(size: 10, weight: segment.isCurrent ? .bold : .medium))
                                        .foregroundStyle(color)
                                    Text("\(chartYAxisLabel(segment.rangeStart))\(isLast ? "+" : "–\(chartYAxisLabel(segment.rangeEnd))")")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 4)

                    // Room remaining
                    if bracketInfo.roomRemaining > 0 && bracketInfo.roomRemaining < .infinity {
                        let nextRate = nextStateRate(after: bracketInfo.currentRate, brackets: brackets)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(Color.UI.brandTeal)
                                .font(.caption)
                            Text("**\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))** room before the \(String(format: "%.1f", nextRate))% bracket")
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
                                colors: [Color.Chart.tealRamp1.opacity(0.3), Color.Chart.tealRamp5.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            }
        default:
            EmptyView()
        }
    }

    /// Returns the next state bracket rate as a percentage string
    private func nextStateRate(after currentRate: Double, brackets: [TaxBracket]) -> Double {
        for i in brackets.indices {
            if abs(brackets[i].rate - currentRate) < 0.001, i + 1 < brackets.count {
                return brackets[i + 1].rate * 100
            }
        }
        return currentRate * 100
    }

    // MARK: - Chart 5: NIIT Position

    @ViewBuilder
    private var niitPositionChart: some View {
        let niit = dataManager.scenarioNIIT
        let nii = dataManager.scenarioNetInvestmentIncome
        if nii > 0 {
            let magi = niit.magi
            let threshold = niit.threshold
            let isAbove = magi > threshold
            let chartMax = max(threshold * 1.5, magi * 1.2)
            let barHeight: CGFloat = 36
            let topPad: CGFloat = 24

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.Chart.tealRamp1, Color.Chart.tealRamp6],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Net Investment Income Tax")
                            .font(.headline)
                        Text("3.8% surtax · \(dataManager.filingStatus.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Two-zone bar: No NIIT (green) | 3.8% NIIT (red)
                GeometryReader { geo in
                    let w = geo.size.width
                    let thresholdX = w * threshold / chartMax
                    let niitZoneWidth = w - thresholdX

                    // No-NIIT zone
                    UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 0)
                        .fill(Color.Chart.tealRamp1)
                        .frame(width: thresholdX, height: barHeight)
                        .offset(y: topPad)

                    // NIIT zone
                    UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 5, topTrailingRadius: 5)
                        .fill(Color.Chart.tealRamp6)
                        .frame(width: niitZoneWidth, height: barHeight)
                        .offset(x: thresholdX, y: topPad)

                    // Threshold boundary
                    Rectangle()
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 1.5, height: barHeight)
                        .offset(x: thresholdX - 0.75, y: topPad)

                    // MAGI marker
                    let magiX = w * magi / chartMax
                    Path { path in
                        path.move(to: CGPoint(x: magiX, y: topPad - 5))
                        path.addLine(to: CGPoint(x: magiX, y: topPad + barHeight + 5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [5, 3]))
                    .foregroundStyle(.primary)

                    // MAGI label
                    Text(chartYAxisLabel(magi))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .position(x: magiX, y: 10)

                    // Border
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        .frame(width: w, height: barHeight)
                        .offset(y: topPad)
                }
                .frame(height: topPad + barHeight + 6)

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.Chart.tealRamp1)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("No NIIT")
                                .font(.system(size: 10, weight: !isAbove ? .bold : .medium))
                                .foregroundStyle(Color.Chart.tealRamp1)
                            Text("< \(chartYAxisLabel(threshold))")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.Chart.tealRamp6)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("3.8% NIIT")
                                .font(.system(size: 10, weight: isAbove ? .bold : .medium))
                                .foregroundStyle(Color.Chart.tealRamp6)
                            Text("\(chartYAxisLabel(threshold))+")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Callouts
                VStack(alignment: .leading, spacing: 6) {
                    if isAbove {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.Semantic.amber)
                                .font(.caption)
                            Text("NIIT: \(niit.annualNIITax, format: .currency(code: "USD").precision(.fractionLength(0)))/yr on \(niit.taxableNII, format: .currency(code: "USD").precision(.fractionLength(0))) of investment income")
                                .font(.caption)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.UI.brandTeal)
                                .font(.caption)
                            Text("No NIIT — MAGI is below the \(chartYAxisLabel(threshold)) threshold")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.UI.brandTeal)
                        }
                    }

                    if niit.distanceToThreshold > 0 && niit.distanceToThreshold < 50_000 {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.Semantic.amber)
                                .font(.caption)
                            Text("\(niit.distanceToThreshold, format: .currency(code: "USD").precision(.fractionLength(0))) below NIIT threshold")
                                .font(.caption)
                                .foregroundStyle(Color.Semantic.amber)
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
                            colors: [Color.Chart.tealRamp1.opacity(0.3), Color.Chart.tealRamp6.opacity(0.3)],
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
                        .foregroundStyle(Color.UI.brandTeal)
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

    private func actionItemRow(_ item: ActionItem) -> some View {
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
                    .foregroundStyle(isCompleted ? Color.UI.brandTeal : .secondary)
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

    private func categoryColor(_ category: ActionCategory) -> Color {
        switch category {
        case .rmd:            return Color.Semantic.amber    // RMD deadline = action required
        case .rothConversion: return Color.UI.brandTeal      // Forward planning action
        case .qcd:            return Color.UI.brandTeal      // Forward planning action
        case .withdrawal:     return Color.UI.brandTeal      // Forward planning action
        case .estimatedTax:   return Color.Semantic.amber    // Quarterly deadline = action required
        case .charitable:     return Color.UI.brandTeal      // Forward planning action
        }
    }

    // MARK: - Account Balances

    private var accountBalances: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Balances")
                .font(.headline)

            HStack(alignment: .top, spacing: 16) {
                balanceColumn(title: "Traditional IRA/\n401(k)", amount: dataManager.totalTraditionalIRABalance, color: Color.UI.textPrimary)
                Divider()
                balanceColumn(title: "Roth IRA/401(k)", amount: dataManager.totalRothBalance, color: Color.UI.textPrimary)
                if dataManager.hasInheritedAccounts {
                    Divider()
                    balanceColumn(title: "Inherited IRA", amount: dataManager.totalInheritedBalance, color: Color.UI.textPrimary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

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

    private func balanceColumn(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 34, alignment: .top)
            Text(amount, format: .currency(code: "USD"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .minimumScaleFactor(0.5)
                .lineLimit(1)
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
                        .fill(Color.Chart.tealRamp2)
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
                        .fill(Color.Chart.tealRamp5)
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

// MARK: - 1.9 Reduce AGI Section

private struct ReduceAGISection: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reduce AGI")
                    .font(.headline)
                Spacer()
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Color.UI.brandTeal)
            }

            // Pre-Medicare 63-64 projection band (always-visible per spec decision 15)
            if dataManager.scenario.yourMedicarePlanType == .preMedicare
               && dataManager.currentAge >= 63 && dataManager.currentAge <= 64 {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(Color.Semantic.amber)
                    Text("Decisions today affect your IRMAA when Medicare starts at age 65 (\(dataManager.medicarePremiumProjectionYear)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.Semantic.amberTint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Current AGI + marginal sensitivity
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Current AGI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(dataManager.federalAGI.value, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Text("Marginal AGI sensitivity: every $1 reduction saves ~$\(format2(dataManager.marginalAGISavingsPerDollar)) this year.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // "Why AGI matters" bullets
            VStack(alignment: .leading, spacing: 6) {
                Text("Why AGI matters for you:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                let irmaa = dataManager.scenarioIRMAA
                if let distanceToNext = irmaa.distanceToNextTier, distanceToNext > 0 {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        (Text("IRMAA in \(dataManager.medicarePremiumProjectionYear) — currently in tier \(irmaa.tier), ")
                            + Text(distanceToNext, format: .currency(code: "USD"))
                            + Text(" to next tier"))
                            .font(.caption)
                    }
                }

                if let aca = dataManager.acaSubsidyResult {
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                        if aca.isOverCliff {
                            Text("ACA subsidy — already over the 400% FPL cliff (subsidy $0 this year)")
                                .font(.caption)
                                .foregroundStyle(Color.Semantic.amber)
                        } else if let toCliff = aca.dollarsToCliff {
                            (Text("ACA subsidy — currently \(Int(aca.fplPercent))% FPL, ")
                                + Text(toCliff, format: .currency(code: "USD"))
                                + Text(" to cliff"))
                                .font(.caption)
                        }
                    }
                }
            }

            // AGI-reducing decisions list
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Your AGI-reducing decisions:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                decisionRow(label: "Pre-tax 401(k) (you)", amount: dataManager.scenario.yourTraditional401kContribution)
                if dataManager.enableSpouse {
                    decisionRow(label: "Pre-tax 401(k) (spouse)", amount: dataManager.scenario.spouseTraditional401kContribution)
                }
                decisionRow(label: "Traditional IRA (you)", amount: dataManager.scenario.yourTraditionalIRAContribution)
                if dataManager.enableSpouse {
                    decisionRow(label: "Traditional IRA (spouse)", amount: dataManager.scenario.spouseTraditionalIRAContribution)
                }
                decisionRow(label: "HSA (combined)", amount: dataManager.scenario.scenarioTotalHSA)
                decisionRow(label: "QCD (existing)", amount: dataManager.scenario.scenarioTotalQCD)
                decisionRow(label: "Charitable cash (existing)", amount: dataManager.scenario.cashDonationAmount)

                Divider()
                decisionRow(
                    label: "Total above-the-line",
                    amount: dataManager.totalAboveTheLineDeductions,
                    bold: true
                )
                decisionRow(
                    label: "AGI without reductions",
                    amount: dataManager.scenarioGrossIncome,
                    bold: false
                )
                decisionRow(
                    label: "AGI with reductions",
                    amount: dataManager.federalAGI.value,
                    bold: true
                )
                let estimatedSavings = dataManager.totalAboveTheLineDeductions * dataManager.marginalAGISavingsPerDollar
                decisionRow(
                    label: "Tax savings (federal+state)",
                    amount: estimatedSavings,
                    bold: false,
                    tint: Color.Semantic.green
                )
            }

            Divider()
            CostSpikeThisYearChart()

            CostSpikeIrmaaChart()
        }
        .padding()
        .background(Color.UI.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func decisionRow(label: String, amount: Double, bold: Bool = false, tint: Color = Color.UI.textPrimary) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(amount, format: .currency(code: "USD"))
                .font(.caption)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(tint)
        }
    }

    private func format2(_ d: Double) -> String {
        String(format: "%.2f", d)
    }
}

// MARK: - 1.9 Cost-Spike Chart (Top Panel)

private struct CostSpikeThisYearChart: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cost This Year")
                .font(.subheadline)
                .fontWeight(.medium)

            let currentAGI = dataManager.federalAGI.value
            let xMin = max(0, currentAGI - 20_000)
            let xMax = currentAGI + 80_000
            let stepSize = 2_500.0
            let samples = stride(from: xMin, through: xMax, by: stepSize).map { agi -> (Double, Double) in
                let cost = dataManager.estimatedThisYearCostAtAGI(agi)
                return (agi, cost)
            }

            Chart {
                ForEach(samples, id: \.0) { sample in
                    LineMark(
                        x: .value("AGI", sample.0),
                        y: .value("Cost", sample.1)
                    )
                    .foregroundStyle(Color.UI.brandTeal)
                }
                RuleMark(x: .value("Current AGI", currentAGI))
                    .foregroundStyle(Color.Semantic.amber)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Current")
                            .font(.caption2)
                            .foregroundStyle(Color.Semantic.amber)
                    }
            }
            .frame(height: 150)
            .chartXAxisLabel("AGI")
            .chartYAxisLabel("Annual cost")
        }
    }
}

// MARK: - 1.9 Cost-Spike Chart (Bottom Panel — IRMAA)

private struct CostSpikeIrmaaChart: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cost in \(dataManager.medicarePremiumProjectionYear) (Medicare IRMAA)")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Based on this year's MAGI per the 2-year lookback")
                .font(.caption2)
                .foregroundStyle(.secondary)

            let currentMAGI = dataManager.irmaaMAGIWrapped.value
            let xMin = max(0, currentMAGI - 20_000)
            let xMax = currentMAGI + 80_000
            let stepSize = 2_500.0
            let samples = stride(from: xMin, through: xMax, by: stepSize).map { magi -> (Double, Double) in
                let irmaa = TaxCalculationEngine.calculateIRMAA(
                    magi: IRMAAMAGI(value: magi),
                    filingStatus: dataManager.filingStatus
                )
                let medicareCount = max(1, dataManager.medicareMemberCount)
                return (magi, irmaa.annualSurchargePerPerson * Double(medicareCount))
            }

            Chart {
                ForEach(samples, id: \.0) { sample in
                    LineMark(
                        x: .value("MAGI", sample.0),
                        y: .value("Annual IRMAA cost", sample.1)
                    )
                    .foregroundStyle(Color.UI.brandTeal)
                }
                RuleMark(x: .value("Current MAGI", currentMAGI))
                    .foregroundStyle(Color.Semantic.amber)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Current")
                            .font(.caption2)
                            .foregroundStyle(Color.Semantic.amber)
                    }
            }
            .frame(height: 150)
            .chartXAxisLabel("MAGI")
            .chartYAxisLabel("Annual IRMAA cost")
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataManager())
}
