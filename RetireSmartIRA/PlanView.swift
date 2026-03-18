//
//  PlanView.swift
//  RetireSmartIRA
//
//  Multi-year Roth conversion strategy — shows an optimized conversion plan
//  with year-by-year projections, IRA balance charts, and comparison to doing nothing.
//
//  All calculations are local and on-device. No financial advice is given.
//

import SwiftUI
import Charts

struct PlanView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWideLayout: Bool { horizontalSizeClass == .regular }

    @State private var planResult: PlanResult?
    @State private var showAllYears = false
    @State private var showApplyConfirmation = false
    @State private var didApply = false

    var body: some View {
        Group {
            if isWideLayout {
                wideBody
            } else {
                compactBody
            }
        }
        .background(Color(PlatformColor.systemGroupedBackground))
        .onAppear { recompute() }
        .onChange(of: dataManager.totalTraditionalIRABalance) { recompute() }
        .onChange(of: dataManager.totalRothBalance) { recompute() }
        .onChange(of: dataManager.filingStatus) { recompute() }
        .onChange(of: dataManager.primaryGrowthRate) { recompute() }
        .onChange(of: dataManager.birthDate) { recompute() }
        .onChange(of: dataManager.enableSpouse) { recompute() }
    }

    private func recompute() {
        planResult = PlanEngine.generatePlan(from: dataManager)
    }

    // MARK: - Layouts

    private var compactBody: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                strategySummaryCard
                if planResult?.hasTraditionalBalance == true {
                    multiYearTable
                    balanceTrajectoryChart
                    comparisonCards
                    whyThisWorksSection
                    taxForcesSection
                    applyToScenarioSection
                }
                disclaimerFooter
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                LazyVStack(spacing: 24) {
                    strategySummaryCard
                    if planResult?.hasTraditionalBalance == true {
                        multiYearTable
                        applyToScenarioSection
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                LazyVStack(spacing: 24) {
                    if planResult?.hasTraditionalBalance == true {
                        balanceTrajectoryChart
                        comparisonCards
                        whyThisWorksSection
                        taxForcesSection
                    }
                    disclaimerFooter
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Section A: Strategy Summary Card

    private var strategySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.85), .teal.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "lightbulb.max.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Multi-Year Conversion Strategy")
                        .font(.headline)
                    Text("Based on current tax profile and assumptions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let plan = planResult, plan.hasTraditionalBalance {
                if plan.conversionYears > 0 {
                    // Strategy description
                    let avgStr = plan.estimatedAnnualConversion.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                    let totalStr = plan.totalConversions.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                    let taxStr = plan.totalTaxPaid.formatted(.currency(code: "USD").precision(.fractionLength(0)))

                    Text("Convert approximately **\(avgStr)/year** for **\(plan.conversionYears) years** within the **\(plan.targetBracketLabel) bracket**.")
                        .font(.subheadline)

                    // Metrics row
                    HStack(spacing: 0) {
                        metricBox(label: "Total Conversions", value: totalStr, color: .blue)
                        metricBox(label: "Projected Tax Cost", value: taxStr, color: .orange)
                        metricBox(label: "IRMAA", value: plan.avoidsIRMAA ? "Clear" : "Triggered", color: plan.avoidsIRMAA ? .green : .red)
                    }

                    // Family wealth increase (if legacy planning is enabled)
                    if dataManager.enableLegacyPlanning && dataManager.legacyFamilyWealthAdvantage > 0 {
                        let wealthStr = dataManager.legacyFamilyWealthAdvantage.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Projected family wealth increase: \(wealthStr)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // RMDs consume all bracket room
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Based on current projections, RMDs consume available bracket room. No additional conversions modeled.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // No Traditional IRA balance
                HStack(spacing: 8) {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No Traditional IRA balance detected. Roth conversions are not applicable. Add accounts in the Accounts tab.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func metricBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section B: Multi-Year Plan Table

    private var multiYearTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projected Conversion Plan")
                .font(.headline)

            // Header row
            HStack(spacing: 0) {
                tableHeader("Year", width: 50)
                tableHeader("Age", width: 36)
                tableHeader("Conversion", width: nil)
                tableHeader("RMD", width: nil)
                tableHeader("Rate", width: 42)
                tableHeader("Trad Bal", width: nil)
                tableHeader("Roth Bal", width: nil)
                tableHeader("IRMAA", width: 50)
            }
            .padding(.horizontal, 8)

            Divider()

            if let plan = planResult {
                let displayYears = showAllYears ? plan.annualPlan : Array(plan.annualPlan.prefix(8))
                ForEach(displayYears) { year in
                    tableRow(year, isCurrentYear: year.year == dataManager.currentYear)
                }

                if plan.annualPlan.count > 8 && !showAllYears {
                    Button {
                        withAnimation { showAllYears = true }
                    } label: {
                        Text("Show All \(plan.annualPlan.count) Years")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }

                // Notes for years with annotations
                let notedYears = plan.annualPlan.filter { !$0.notes.isEmpty }
                if !notedYears.isEmpty {
                    Divider()
                    ForEach(notedYears) { year in
                        HStack(spacing: 4) {
                            Text("\(year.year):")
                                .font(.caption2)
                                .fontWeight(.semibold)
                            Text(year.notes)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func tableHeader(_ text: String, width: CGFloat?) -> some View {
        if let width {
            Text(text)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: width, alignment: .trailing)
        } else {
            Text(text)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func tableRow(_ year: YearPlan, isCurrentYear: Bool) -> some View {
        HStack(spacing: 0) {
            Text("\(year.year)")
                .frame(width: 50, alignment: .leading)
            Text("\(year.age)")
                .frame(width: 36, alignment: .trailing)
            Text(compactCurrency(year.totalConversion))
                .foregroundStyle(year.totalConversion > 0 ? .green : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(compactCurrency(year.projectedRMD))
                .foregroundStyle(year.projectedRMD > 0 ? .orange : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("\(Int(year.bracketRate * 100))%")
                .frame(width: 42, alignment: .trailing)
            Text(compactCurrency(year.remainingTraditionalBalance))
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(compactCurrency(year.rothBalance))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(year.irmaaStatus)
                .foregroundStyle(year.irmaaStatus == "Clear" ? .green : .red)
                .frame(width: 50, alignment: .trailing)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isCurrentYear ? Color.blue.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Section C: IRA Balance Trajectory Chart

    private var balanceTrajectoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projected IRA Balance Trajectory")
                .font(.headline)

            if let plan = planResult, !plan.annualPlan.isEmpty {
                let firstYear = plan.annualPlan.first!.year
                let lastYear = plan.annualPlan.last!.year
                Chart {
                    // With Plan — Traditional (orange, solid)
                    ForEach(plan.annualPlan) { year in
                        LineMark(
                            x: .value("Year", Double(year.year)),
                            y: .value("Balance", year.remainingTraditionalBalance),
                            series: .value("Series", "Traditional (With Plan)")
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    // With Plan — Roth (green, solid)
                    ForEach(plan.annualPlan) { year in
                        LineMark(
                            x: .value("Year", Double(year.year)),
                            y: .value("Balance", year.rothBalance),
                            series: .value("Series", "Roth (With Plan)")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    // Without Plan — Traditional (orange, dashed)
                    ForEach(plan.noActionPlan) { year in
                        LineMark(
                            x: .value("Year", Double(year.year)),
                            y: .value("Balance", year.remainingTraditionalBalance),
                            series: .value("Series", "Traditional (No Plan)")
                        )
                        .foregroundStyle(.orange.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    }

                    // Without Plan — Roth (green, dashed)
                    ForEach(plan.noActionPlan) { year in
                        LineMark(
                            x: .value("Year", Double(year.year)),
                            y: .value("Balance", year.rothBalance),
                            series: .value("Series", "Roth (No Plan)")
                        )
                        .foregroundStyle(.green.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    }
                }
                .chartXScale(domain: Double(firstYear) ... Double(lastYear))
                .chartXAxis {
                    AxisMarks(values: Array(stride(from: Double(firstYear), through: Double(lastYear), by: 5))) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(chartLabel(v))
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .center)
                .frame(height: 260)

                HStack(spacing: 16) {
                    legendDot(color: .orange, label: "Traditional", dashed: false)
                    legendDot(color: .green, label: "Roth", dashed: false)
                    legendDot(color: .gray, label: "Without Plan", dashed: true)
                }
                .font(.caption2)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func legendDot(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            if dashed {
                Rectangle()
                    .fill(color.opacity(0.5))
                    .frame(width: 12, height: 2)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Section D: Comparison Cards

    private var comparisonCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projected Outcome at Age 85")
                .font(.headline)

            if let plan = planResult {
                let targetAge = 85
                let withPlanYear = plan.annualPlan.first { $0.age >= targetAge } ?? plan.annualPlan.last
                let noActionYear = plan.noActionPlan.first { $0.age >= targetAge } ?? plan.noActionPlan.last

                HStack(spacing: 12) {
                    // Without Plan
                    comparisonCard(
                        title: "Without Plan",
                        rmd: noActionYear?.projectedRMD ?? 0,
                        bracket: noActionYear.map { "\(Int($0.bracketRate * 100))%" } ?? "—",
                        irmaa: noActionYear?.irmaaStatus ?? "—",
                        tradBalance: noActionYear?.remainingTraditionalBalance ?? 0,
                        tint: .orange
                    )

                    // With Plan
                    comparisonCard(
                        title: "With Plan",
                        rmd: withPlanYear?.projectedRMD ?? 0,
                        bracket: withPlanYear.map { "\(Int($0.bracketRate * 100))%" } ?? "—",
                        irmaa: withPlanYear?.irmaaStatus ?? "—",
                        tradBalance: withPlanYear?.remainingTraditionalBalance ?? 0,
                        tint: .green
                    )
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func comparisonCard(title: String, rmd: Double, bracket: String, irmaa: String, tradBalance: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 4) {
                comparisonRow("Projected RMD", value: rmd > 0 ? compactCurrency(rmd) + "/yr" : "None")
                comparisonRow("Federal Bracket", value: bracket)
                comparisonRow("IRMAA", value: irmaa)
                comparisonRow("Trad Balance", value: compactCurrency(tradBalance))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func comparisonRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Section E: Why This Works

    private var whyThisWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why This Strategy Works")
                .font(.headline)

            bulletPoint(
                icon: "chart.line.downtrend.xyaxis",
                color: .blue,
                text: "Reduces future RMD pressure by shrinking the Traditional IRA balance before age \(dataManager.rmdAge)"
            )

            if let plan = planResult {
                bulletPoint(
                    icon: "dollarsign.square",
                    color: .green,
                    text: "Keeps projected income within the current \(plan.targetBracketLabel) federal tax bracket"
                )
            }

            if dataManager.enableLegacyPlanning {
                bulletPoint(
                    icon: "person.2",
                    color: .purple,
                    text: "Reduces projected taxes on heirs under the SECURE Act 10-year rule"
                )
            }

            if dataManager.enableSpouse {
                bulletPoint(
                    icon: "arrow.triangle.branch",
                    color: .orange,
                    text: "Mitigates the widow tax bracket risk if filing status changes to Single"
                )
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func bulletPoint(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.caption)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Section F: Tax Forces

    private var taxForcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Key Tax Forces Affecting Your Plan")
                    .font(.headline)
            }

            forceRow("RMD pressure increases income over time as account balances grow")
            forceRow("IRMAA cliffs increase Medicare costs \u{2014} crossing by $1 triggers the full surcharge")
            if dataManager.enableSpouse {
                forceRow("Widow bracket reduces tax thresholds if your spouse passes first")
            }
            forceRow("SECURE Act compresses inheritance taxes into 10 years for non-spouse heirs")
        }
        .padding()
        .background(Color.orange.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
        )
    }

    private func forceRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(.orange).frame(width: 5, height: 5).padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Section G: Apply to Scenario

    private var applyToScenarioSection: some View {
        VStack(spacing: 12) {
            if let plan = planResult, let firstYear = plan.annualPlan.first, firstYear.totalConversion > 0 {
                Button {
                    showApplyConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Apply Year 1 to Scenario")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .confirmationDialog(
                    "Apply Conversion Plan",
                    isPresented: $showApplyConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Apply \(firstYear.totalConversion.formatted(.currency(code: "USD").precision(.fractionLength(0)))) Conversion") {
                        applyYear1()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will reset your current scenario and set the Year 1 conversion amount. You can then review the full tax impact in the Scenarios tab.")
                }

                if didApply {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Year 1 applied. Switch to the Scenarios tab to see the full tax impact.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private func applyYear1() {
        guard let plan = planResult, let firstYear = plan.annualPlan.first else { return }
        dataManager.resetScenario()
        dataManager.yourRothConversion = firstYear.primaryConversion
        if dataManager.enableSpouse {
            dataManager.spouseRothConversion = firstYear.spouseConversion
        }
        dataManager.saveAllData()
        withAnimation { didApply = true }
    }

    // MARK: - Disclaimer

    private var disclaimerFooter: some View {
        Text("Projections are based on current tax law, an assumed growth rate of \(Int(dataManager.primaryGrowthRate))%, and current income levels. Actual results will vary. This is not financial advice. Consult a qualified tax professional before making decisions.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private func compactCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.1fM", value / 1_000_000))"
        } else if value >= 1_000 {
            return "$\(String(format: "%.0fK", value / 1_000))"
        } else if value > 0 {
            return "$\(Int(value))"
        }
        return "$0"
    }

    private func chartLabel(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.1fM", value / 1_000_000))"
        } else if value >= 1_000 {
            return "$\(String(format: "%.0fK", value / 1_000))"
        }
        return "$\(Int(value))"
    }
}
