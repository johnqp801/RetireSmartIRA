//
//  RMDCalculatorView.swift
//  RetireSmartIRA
//
//  Calculate Required Minimum Distributions
//

import SwiftUI
import Charts

struct RMDCalculatorView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var projectionYears = 10
    @State private var showGuide: Bool = false
    @State private var showAboutRMDs: Bool = false

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
        .onChange(of: dataManager.primaryGrowthRate) { dataManager.saveAllData() }
        .onChange(of: dataManager.spouseGrowthRate) { dataManager.saveAllData() }
    }

    // MARK: - Layout Variants

    private var compactBody: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                statusCard
                guideCard
                currentYearRMD
                inheritedIRASection
                accountBreakdown
                rmdProjectionChart
                projectionsSection
                inheritedIRAProjectionsSection
                aboutRMDs
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                LazyVStack(spacing: 24) {
                    statusCard
                    guideCard
                    currentYearRMD
                    inheritedIRASection
                    accountBreakdown
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                LazyVStack(spacing: 24) {
                    rmdProjectionChart
                    projectionsSection
                    inheritedIRAProjectionsSection
                    aboutRMDs
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Status Card

    private var hasInheritedRMDs: Bool {
        dataManager.inheritedIRARMDTotal > 0
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("RMD Status")
                        .font(.headline)

                    if dataManager.isRMDRequired {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("RMDs Required")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    } else if hasInheritedRMDs {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Inherited IRA RMDs Required")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Not Yet Required")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("RMD Age")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(dataManager.rmdAge)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
            }

            Divider()

            if dataManager.isRMDRequired {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Important Deadlines")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.orange)
                        Text("Annual deadline: December 31")
                            .font(.callout)
                    }

                    if dataManager.currentAge == dataManager.rmdAge {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                            Text("First RMD can be delayed until April 1 \(dataManager.currentYear + 1)")
                                .font(.callout)
                        }

                        Text("\u{26A0}\u{FE0F} Warning: Delaying means taking 2 RMDs in one year")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.leading, 24)
                    }
                }
            } else if hasInheritedRMDs {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.orange)
                        Text("Inherited IRA: \(dataManager.inheritedIRARMDTotal, format: .currency(code: "USD")) due by December 31")
                            .font(.callout)
                    }
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.green)
                        Text("Own IRA RMDs start in \(dataManager.yearsUntilRMD) years (age \(dataManager.rmdAge))")
                            .font(.callout)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.green)
                    Text("RMDs start in \(dataManager.yearsUntilRMD) years")
                        .font(.callout)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - How to Use Guide

    private var guideCard: some View {
        DisclosureGroup(isExpanded: $showGuide) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Current Year RMD", systemImage: "dollarsign.circle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Shows your required withdrawal for this year based on actual account balances. This is the amount you must take by December 31.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("RMD Projections", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Models how your balances and required withdrawals change over time. Use the growth rate sliders to compare scenarios:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("0\u{2013}3%")
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                            Text("Conservative \u{2014} bonds, CDs, money market")
                        }
                        HStack(spacing: 6) {
                            Text("4\u{2013}6%")
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                            Text("Moderate \u{2014} balanced stock/bond portfolio")
                        }
                        HStack(spacing: 6) {
                            Text("7\u{2013}10%")
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                            Text("Aggressive \u{2014} equity-heavy portfolio")
                        }
                        HStack(spacing: 6) {
                            Text("< 0%")
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                            Text("Market downturn \u{2014} stress-test your plan")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Label("Key Insight", systemImage: "lightbulb")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Higher growth means larger future balances but also larger future RMDs, which increases taxable income. Use the Scenarios tab to model the tax impact of different withdrawal strategies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("How to Use This Calculator", systemImage: "questionmark.circle")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Current Year RMD

    /// Whether any RMDs (regular or inherited) are required this year
    private var hasAnyRMDs: Bool {
        (dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0)
        || (dataManager.enableSpouse && dataManager.spouseIsRMDRequired && dataManager.spouseTraditionalIRABalance > 0)
        || hasInheritedRMDs
    }

    /// Grand total of all RMDs: regular + inherited
    private var grandTotalRMD: Double {
        dataManager.calculateCombinedRMD() + dataManager.inheritedIRARMDTotal
    }

    @ViewBuilder
    private var currentYearRMD: some View {
        if hasAnyRMDs {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(dataManager.currentYear) Required Minimum Distribution")
                    .font(.headline)

                // Your RMD
                if dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0 {
                    let primaryRMD = dataManager.calculatePrimaryRMD()

                    VStack(spacing: 12) {
                        HStack {
                            Label("Your RMD", systemImage: "person.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Traditional IRA/401(k)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dataManager.primaryTraditionalIRABalance, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Factor")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(dataManager.lifeExpectancyFactor(for: dataManager.currentAge), specifier: "%.1f")")
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(primaryRMD, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Text("(\(primaryRMD / dataManager.primaryTraditionalIRABalance * 100, specifier: "%.2f")% of balance)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Spouse RMD
                if dataManager.enableSpouse && dataManager.spouseIsRMDRequired && dataManager.spouseTraditionalIRABalance > 0 {
                    let spouseRMD = dataManager.calculateSpouseRMD()

                    VStack(spacing: 12) {
                        HStack {
                            Label(dataManager.spouseName.isEmpty ? "Spouse's RMD" : "\(dataManager.spouseName)'s RMD",
                                  systemImage: "person.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Traditional IRA/401(k)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(dataManager.spouseTraditionalIRABalance, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Factor")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(dataManager.lifeExpectancyFactor(for: dataManager.spouseCurrentAge), specifier: "%.1f")")
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(spouseRMD, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Text("(\(spouseRMD / dataManager.spouseTraditionalIRABalance * 100, specifier: "%.2f")% of balance)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if dataManager.enableSpouse && !dataManager.spouseIsRMDRequired {
                    HStack {
                        Label(dataManager.spouseName.isEmpty ? "Spouse's RMD" : "\(dataManager.spouseName)'s RMD",
                              systemImage: "person.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Not yet required")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Inherited IRA RMDs summary
                if hasInheritedRMDs {
                    ForEach(dataManager.inheritedAccounts) { account in
                        let result = dataManager.calculateInheritedIRARMD(account: account, forYear: dataManager.currentYear)
                        if result.annualRMD > 0 {
                            VStack(spacing: 12) {
                                HStack {
                                    Label {
                                        HStack(spacing: 6) {
                                            Text(account.name)
                                            if dataManager.enableSpouse {
                                                Text(account.owner.rawValue)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.purple.opacity(0.2))
                                                    .foregroundStyle(.purple)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: "arrow.down.doc.fill")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    Spacer()
                                    Text("Inherited")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Balance")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(account.balance, format: .currency(code: "USD"))
                                            .font(.callout)
                                            .fontWeight(.medium)
                                    }

                                    Spacer()

                                    if let deadline = result.mustEmptyByYear {
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("Empty By")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(String(deadline))
                                                .font(.callout)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.orange)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Required")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(result.annualRMD, format: .currency(code: "USD"))
                                            .font(.callout)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(PlatformColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                // Grand Total
                Divider()

                ViewThatFits {
                    HStack {
                        Text(dataManager.enableSpouse ? "Total Household RMD" : "Total Required Withdrawal")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(grandTotalRMD, format: .currency(code: "USD"))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(hasInheritedRMDs && !dataManager.isRMDRequired ? .orange : .blue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dataManager.enableSpouse ? "Total Household RMD" : "Total Required Withdrawal")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(grandTotalRMD, format: .currency(code: "USD"))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(hasInheritedRMDs && !dataManager.isRMDRequired ? .orange : .blue)
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Inherited IRA RMDs

    @ViewBuilder
    private var inheritedIRASection: some View {
        if dataManager.hasInheritedAccounts {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Inherited IRA RMDs", systemImage: "arrow.down.doc.fill")
                        .font(.headline)
                    Spacer()
                }

                ForEach(dataManager.inheritedAccounts) { account in
                    let result = dataManager.calculateInheritedIRARMD(account: account, forYear: dataManager.currentYear)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(account.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if dataManager.enableSpouse {
                                        Text(account.owner.rawValue)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.purple.opacity(0.2))
                                            .foregroundStyle(.purple)
                                            .clipShape(Capsule())
                                    }
                                }
                                if let beneficiary = account.beneficiaryType {
                                    Text(beneficiary.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }

                            Spacer()

                            Text(account.balance, format: .currency(code: "USD"))
                                .font(.callout)
                                .fontWeight(.medium)
                        }

                        // RMD amount
                        HStack {
                            Text("Required Withdrawal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if result.annualRMD > 0 {
                                Text(result.annualRMD, format: .currency(code: "USD"))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("None required")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Deadline warning
                        if let deadline = result.mustEmptyByYear {
                            let remaining = result.yearsRemaining ?? 0
                            HStack(spacing: 6) {
                                Image(systemName: remaining <= 1 ? "exclamationmark.triangle.fill" : "clock")
                                    .foregroundStyle(remaining <= 1 ? .red : (remaining <= 3 ? .orange : .secondary))
                                Text("Must empty by end of \(String(deadline))")
                                    .font(.caption)
                                if remaining > 0 {
                                    Text("(\(remaining) years)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Rule description
                        Text(result.rule)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(PlatformColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Total inherited RMD
                if dataManager.inheritedAccounts.count > 1 {
                    Divider()
                    HStack {
                        Text("Total Inherited IRA RMD")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(dataManager.inheritedIRARMDTotal, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                }

                // QCD ineligibility notice
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Inherited IRA distributions are not eligible for Qualified Charitable Distributions (QCDs).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Account Breakdown

    @ViewBuilder
    private var accountBreakdown: some View {
        if !dataManager.iraAccounts.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Account Breakdown")
                    .font(.headline)

                ForEach(dataManager.iraAccounts.filter {
                    $0.accountType == .traditionalIRA || $0.accountType == .traditional401k
                }) { account in
                    let ownerAge = accountOwnerAge(for: account)
                    let ownerRMDAge = accountOwnerRMDAge(for: account)
                    let ownerRMDRequired = ownerAge >= ownerRMDAge

                    if ownerRMDRequired {
                        let accountRMD = dataManager.calculateRMD(
                            for: ownerAge,
                            balance: account.balance
                        )

                        AccountRMDRow(
                            accountName: account.name,
                            ownerLabel: dataManager.enableSpouse ? account.owner.rawValue : nil,
                            balance: account.balance,
                            rmd: accountRMD
                        )
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                HStack(spacing: 4) {
                                    Text(account.accountType.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if dataManager.enableSpouse {
                                        Text("·")
                                            .foregroundStyle(.secondary)
                                        Text(account.owner.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Text(account.balance, format: .currency(code: "USD"))
                                .font(.callout)
                                .fontWeight(.semibold)
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

    // MARK: - RMD Projection Chart

    private struct RMDChartDataPoint: Identifiable {
        let id = UUID()
        let year: Int
        let yearLabel: String
        let amount: Double
        let category: String
    }

    private var hasChartData: Bool {
        dataManager.primaryTraditionalIRABalance > 0
        || (dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0)
        || dataManager.hasInheritedAccounts
    }

    /// Combined stacked chart data for both IRA/401(k) and Inherited IRA RMDs
    private var rmdChartData: [RMDChartDataPoint] {
        var data: [RMDChartDataPoint] = []

        for yearOffset in 0..<projectionYears {
            let projectedYear = dataManager.currentYear + yearOffset
            let label = "'\(String(projectedYear).suffix(2))"

            // Regular IRA/401(k) RMDs
            var regularRMD: Double = 0

            if dataManager.primaryTraditionalIRABalance > 0 {
                let pAge = dataManager.currentAge + yearOffset
                if pAge >= dataManager.rmdAge {
                    let balance = projectBalance(
                        years: yearOffset,
                        startingBalance: dataManager.primaryTraditionalIRABalance,
                        startAge: dataManager.currentAge,
                        rmdStartAge: dataManager.rmdAge,
                        growthPercent: dataManager.primaryGrowthRate
                    )
                    regularRMD += dataManager.calculateRMD(for: pAge, balance: balance)
                }
            }

            if dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0 {
                let sAge = dataManager.spouseCurrentAge + yearOffset
                if sAge >= dataManager.spouseRmdAge {
                    let balance = projectBalance(
                        years: yearOffset,
                        startingBalance: dataManager.spouseTraditionalIRABalance,
                        startAge: dataManager.spouseCurrentAge,
                        rmdStartAge: dataManager.spouseRmdAge,
                        growthPercent: dataManager.spouseGrowthRate
                    )
                    regularRMD += dataManager.calculateRMD(for: sAge, balance: balance)
                }
            }

            data.append(RMDChartDataPoint(year: projectedYear, yearLabel: label, amount: regularRMD, category: "IRA / 401(k)"))

            // Inherited IRA RMDs
            var inheritedRMD: Double = 0

            if dataManager.hasInheritedAccounts {
                for account in dataManager.inheritedAccounts {
                    let growthRate = account.owner == .spouse
                        ? dataManager.spouseGrowthRate
                        : dataManager.primaryGrowthRate
                    let projections = projectInheritedIRA(account: account, growthPercent: growthRate)
                    if let row = projections.first(where: { $0.year == projectedYear }) {
                        inheritedRMD += row.rmd
                    }
                }
            }

            data.append(RMDChartDataPoint(year: projectedYear, yearLabel: label, amount: inheritedRMD, category: "Inherited IRA"))
        }
        return data
    }

    /// Formats Y-axis labels compactly ($5K, $150K, etc.)
    private func chartYAxisLabel(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$\(String(format: "%.1f", amount / 1_000_000))M"
        } else if amount >= 1000 {
            return "$\(Int(amount / 1000))K"
        } else {
            return "$\(Int(amount))"
        }
    }

    @ViewBuilder
    private var rmdProjectionChart: some View {
        if hasChartData {
            let chartData = rmdChartData
            let hasRegularRMDs = chartData.contains { $0.category == "IRA / 401(k)" && $0.amount > 0 }
            let hasInheritedRMDs = chartData.contains { $0.category == "Inherited IRA" && $0.amount > 0 }
            let anyRMDs = hasRegularRMDs || hasInheritedRMDs

            VStack(alignment: .leading, spacing: 16) {
                // Eye-catching header with gradient icon
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.85), .orange.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Projected Annual RMDs")
                            .font(.headline)
                        Text("\(projectionYears)-Year Outlook")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if anyRMDs {
                    // Legend
                    HStack(spacing: 16) {
                        if hasRegularRMDs {
                            HStack(spacing: 6) {
                                Circle().fill(.blue).frame(width: 8, height: 8)
                                Text("IRA / 401(k)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if hasInheritedRMDs {
                            HStack(spacing: 6) {
                                Circle().fill(.orange).frame(width: 8, height: 8)
                                Text("Inherited IRA")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    // Single stacked bar chart
                    Chart(chartData) { point in
                        BarMark(
                            x: .value("Year", point.yearLabel),
                            y: .value("RMD", point.amount)
                        )
                        .foregroundStyle(by: .value("Type", point.category))
                        .cornerRadius(3)
                    }
                    .chartForegroundStyleScale([
                        "IRA / 401(k)": Color.blue,
                        "Inherited IRA": Color.orange
                    ])
                    .chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(chartYAxisLabel(amount))
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 220)

                    // Peak callouts
                    VStack(alignment: .leading, spacing: 4) {
                        if hasRegularRMDs,
                           let peak = chartData.filter({ $0.category == "IRA / 401(k)" }).max(by: { $0.amount < $1.amount }),
                           peak.amount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                                Text("IRA / 401(k) Peak:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(peak.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("in \(String(peak.year))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if hasInheritedRMDs,
                           let peak = chartData.filter({ $0.category == "Inherited IRA" }).max(by: { $0.amount < $1.amount }),
                           peak.amount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("Inherited IRA Peak:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(peak.amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("in \(String(peak.year))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Combined peak when both types present
                        if hasRegularRMDs && hasInheritedRMDs {
                            let totalsByYear: [(year: Int, total: Double)] = (0..<projectionYears).map { offset in
                                let yr = dataManager.currentYear + offset
                                let reg = chartData.first(where: { $0.year == yr && $0.category == "IRA / 401(k)" })?.amount ?? 0
                                let inh = chartData.first(where: { $0.year == yr && $0.category == "Inherited IRA" })?.amount ?? 0
                                return (year: yr, total: reg + inh)
                            }
                            if let peakTotal = totalsByYear.max(by: { $0.total < $1.total }), peakTotal.total > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.purple)
                                        .font(.caption)
                                    Text("Combined Peak:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(peakTotal.total, format: .currency(code: "USD").precision(.fractionLength(0)))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("in \(String(peakTotal.year))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No RMDs projected in this period")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Your first RMD begins at age \(dataManager.rmdAge)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .orange.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }

    // MARK: - Projections Section

    private var projectionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RMD Projections")
                    .font(.headline)

                Spacer()

                Picker("Years", selection: $projectionYears) {
                    Text("5 years").tag(5)
                    Text("10 years").tag(10)
                    Text("15 years").tag(15)
                    Text("20 years").tag(20)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            // Growth rate controls
            if dataManager.primaryTraditionalIRABalance > 0 || (dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0) {
                VStack(spacing: 12) {
                    if dataManager.primaryTraditionalIRABalance > 0 {
                        HStack {
                            Text(dataManager.enableSpouse ? "\(dataManager.primaryLabel) Growth Rate" : "Growth Rate")
                                .font(.subheadline)
                            Spacer()
                            Text("\(dataManager.primaryGrowthRate, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $dataManager.primaryGrowthRate, in: -5...12, step: 0.5)
                            .tint(.blue)
                    }

                    if dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0 {
                        let spLabel = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
                        HStack {
                            Text("\(spLabel)'s Growth Rate")
                                .font(.subheadline)
                            Spacer()
                            Text("\(dataManager.spouseGrowthRate, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $dataManager.spouseGrowthRate, in: -5...12, step: 0.5)
                            .tint(.green)
                    }
                }
                .padding()
                .background(Color(PlatformColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if dataManager.primaryTraditionalIRABalance > 0 || (dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0) {

                let showSpouse = dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0
                let spouseLabel = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName

                if showSpouse {
                    // Horizontal scroll for combined table on narrower screens
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Combined header row
                            HStack(spacing: 0) {
                                Text("Year")
                                    .frame(width: 50, alignment: .leading)
                                Text("Age")
                                    .frame(width: 32, alignment: .trailing)
                                Text("Balance")
                                    .frame(width: 95, alignment: .trailing)
                                Text("RMD")
                                    .frame(width: 80, alignment: .trailing)
                                Color.clear.frame(width: 8)
                                Text("Age")
                                    .frame(width: 32, alignment: .trailing)
                                Text("Balance")
                                    .frame(width: 95, alignment: .trailing)
                                Text("RMD")
                                    .frame(width: 80, alignment: .trailing)
                                Color.clear.frame(width: 8)
                                Text("Total")
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)

                            // Sub-header: owner labels
                            HStack(spacing: 0) {
                                Color.clear.frame(width: 50)
                                Text("You")
                                    .frame(width: 207, alignment: .center)
                                Color.clear.frame(width: 8)
                                Text(spouseLabel)
                                    .frame(width: 207, alignment: .center)
                                Color.clear.frame(width: 8)
                                Text("RMD")
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)

                            // Combined projection rows
                            VStack(spacing: 6) {
                                ForEach(0..<projectionYears, id: \.self) { yearOffset in
                                    let projectedYear = dataManager.currentYear + yearOffset

                                    // Primary data
                                    let pAge = dataManager.currentAge + yearOffset
                                    let pHasBalance = dataManager.primaryTraditionalIRABalance > 0
                                    let pEligible = pAge >= dataManager.rmdAge && pHasBalance
                                    let pBalance: Double? = pEligible ? projectBalance(
                                        years: yearOffset,
                                        startingBalance: dataManager.primaryTraditionalIRABalance,
                                        startAge: dataManager.currentAge,
                                        rmdStartAge: dataManager.rmdAge,
                                        growthPercent: dataManager.primaryGrowthRate
                                    ) : nil
                                    let pRMD: Double? = pEligible ? dataManager.calculateRMD(
                                        for: pAge,
                                        balance: pBalance ?? 0
                                    ) : nil

                                    // Spouse data
                                    let sAge = dataManager.spouseCurrentAge + yearOffset
                                    let sEligible = sAge >= dataManager.spouseRmdAge
                                    let sBalance: Double? = sEligible ? projectBalance(
                                        years: yearOffset,
                                        startingBalance: dataManager.spouseTraditionalIRABalance,
                                        startAge: dataManager.spouseCurrentAge,
                                        rmdStartAge: dataManager.spouseRmdAge,
                                        growthPercent: dataManager.spouseGrowthRate
                                    ) : nil
                                    let sRMD: Double? = sEligible ? dataManager.calculateRMD(
                                        for: sAge,
                                        balance: sBalance ?? 0
                                    ) : nil

                                    let totalRMD = (pRMD ?? 0) + (sRMD ?? 0)

                                    CombinedRMDProjectionRow(
                                        year: projectedYear,
                                        isCurrentYear: yearOffset == 0,
                                        primaryAge: pHasBalance ? pAge : nil,
                                        primaryBalance: pBalance,
                                        primaryRMD: pRMD,
                                        spouseAge: sAge,
                                        spouseBalance: sBalance,
                                        spouseRMD: sRMD,
                                        totalRMD: totalRMD
                                    )
                                }
                            }
                        }
                    }
                } else {
                    // Single-person header row
                    HStack(spacing: 0) {
                        Text("Year")
                            .frame(width: 50, alignment: .leading)
                        Text("Age")
                            .frame(width: 40, alignment: .trailing)
                        Spacer()
                        Text("Balance")
                            .frame(width: 140, alignment: .trailing)
                        Spacer()
                        Text("RMD")
                            .frame(width: 100, alignment: .trailing)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                    // Single-person projection rows
                    VStack(spacing: 8) {
                        ForEach(0..<projectionYears, id: \.self) { yearOffset in
                            let projectedAge = dataManager.currentAge + yearOffset
                            let projectedYear = dataManager.currentYear + yearOffset

                            if projectedAge >= dataManager.rmdAge {
                                let projectedBalance = projectBalance(
                                    years: yearOffset,
                                    startingBalance: dataManager.primaryTraditionalIRABalance,
                                    startAge: dataManager.currentAge,
                                    rmdStartAge: dataManager.rmdAge,
                                    growthPercent: dataManager.primaryGrowthRate
                                )
                                let projectedRMD = dataManager.calculateRMD(
                                    for: projectedAge,
                                    balance: projectedBalance
                                )

                                RMDProjectionRow(
                                    year: projectedYear,
                                    age: projectedAge,
                                    balance: projectedBalance,
                                    rmd: projectedRMD,
                                    isCurrentYear: yearOffset == 0
                                )
                            }
                        }
                    }
                }
            } else {
                Text("Add Traditional IRA/401(k) accounts to see projections")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - About RMDs (Collapsible)

    private var aboutRMDs: some View {
        DisclosureGroup(isExpanded: $showAboutRMDs) {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(
                    icon: "info.circle",
                    text: "RMDs are the minimum amount you must withdraw from retirement accounts annually",
                    color: .blue
                )

                InfoRow(
                    icon: "exclamationmark.triangle",
                    text: "Penalty for missing RMD: 25% of the amount not withdrawn",
                    color: .red
                )

                InfoRow(
                    icon: "checkmark.circle",
                    text: "Roth IRAs do NOT require RMDs during your lifetime",
                    color: .green
                )

                InfoRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "RMD amount increases each year as life expectancy factor decreases",
                    color: .purple
                )
            }
            .padding(.top, 8)
        } label: {
            Label("About RMDs", systemImage: "book.closed")
                .font(.headline)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Inherited IRA Projections

    private struct InheritedProjectionRow: Identifiable {
        var id: Int { year }
        let year: Int
        let balance: Double
        let rmd: Double
        let remaining: Int?
        let isDeadline: Bool
    }

    /// Projects an inherited IRA balance forward, computing annual RMDs, growth, and deadline tracking.
    private func projectInheritedIRA(account: IRAAccount, growthPercent: Double) -> [InheritedProjectionRow] {
        guard account.accountType.isInherited,
              let beneficiaryType = account.beneficiaryType,
              let yearOfInheritance = account.yearOfInheritance,
              let beneficiaryBirthYear = account.beneficiaryBirthYear else { return [] }

        let isRoth = account.accountType == .inheritedRothIRA
        let rbdStatus = account.decedentRBDStatus ?? .beforeRBD
        let growthRate = growthPercent / 100.0

        // Determine deadline year (nil = lifetime stretch)
        let deadlineYear: Int? = {
            switch beneficiaryType {
            case .spouse, .disabled, .chronicallyIll, .notTenYearsYounger:
                return nil
            case .minorChild:
                let majorityYear = account.minorChildMajorityYear ?? (beneficiaryBirthYear + 21)
                return majorityYear + 10
            case .nonEligibleDesignated:
                return yearOfInheritance + 10
            }
        }()

        // Project until deadline or projectionYears for lifetime stretch
        let lastYear: Int
        if let deadline = deadlineYear {
            lastYear = max(deadline, dataManager.currentYear)
        } else {
            lastYear = dataManager.currentYear + projectionYears - 1
        }

        var balance = account.balance
        var rows: [InheritedProjectionRow] = []

        for year in dataManager.currentYear...lastYear {
            guard balance > 0.01 else { break }

            let yearsElapsed = year - yearOfInheritance
            let beneficiaryAge = year - beneficiaryBirthYear
            let isDeadlineYear = (deadlineYear != nil && year >= deadlineYear!)

            var rmd: Double = 0

            if isDeadlineYear {
                rmd = balance
            } else if isRoth {
                // Inherited Roth: no annual RMDs, just must empty by deadline
                rmd = 0
            } else {
                switch beneficiaryType {
                case .nonEligibleDesignated:
                    if rbdStatus == .afterRBD && yearsElapsed >= 1 {
                        let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
                        let initialFactor = dataManager.singleLifeExpectancyFactor(for: initialAge)
                        let yearsOfReduction = year - (yearOfInheritance + 1)
                        let factor = max(1.0, initialFactor - Double(yearsOfReduction))
                        rmd = balance / factor
                    }

                case .spouse, .disabled, .chronicallyIll:
                    if yearsElapsed >= 1 {
                        let factor = dataManager.singleLifeExpectancyFactor(for: beneficiaryAge)
                        rmd = factor > 0 ? balance / factor : balance
                    }

                case .notTenYearsYounger:
                    if yearsElapsed >= 1 {
                        let initialAge = (yearOfInheritance + 1) - beneficiaryBirthYear
                        let initialFactor = dataManager.singleLifeExpectancyFactor(for: initialAge)
                        let yearsOfReduction = year - (yearOfInheritance + 1)
                        let factor = max(1.0, initialFactor - Double(yearsOfReduction))
                        rmd = balance / factor
                    }

                case .minorChild:
                    let majorityYear = account.minorChildMajorityYear ?? (beneficiaryBirthYear + 21)
                    if year < majorityYear {
                        if yearsElapsed >= 1 {
                            let factor = dataManager.singleLifeExpectancyFactor(for: beneficiaryAge)
                            rmd = factor > 0 ? balance / factor : balance
                        }
                    } else if rbdStatus == .afterRBD {
                        let ageAtMajorityPlus1 = (majorityYear + 1) - beneficiaryBirthYear
                        let initialFactor = dataManager.singleLifeExpectancyFactor(for: ageAtMajorityPlus1)
                        let yearsOfReduction = year - (majorityYear + 1)
                        let factor = max(1.0, initialFactor - Double(max(0, yearsOfReduction)))
                        rmd = balance / factor
                    }
                }
            }

            rmd = min(rmd, balance)
            let remaining: Int? = deadlineYear.map { max(0, $0 - year) }

            rows.append(InheritedProjectionRow(
                year: year,
                balance: balance,
                rmd: rmd,
                remaining: remaining,
                isDeadline: isDeadlineYear
            ))

            balance -= rmd
            balance *= (1 + growthRate)
            balance = max(0, balance)
        }

        return rows
    }

    @ViewBuilder
    private var inheritedIRAProjectionsSection: some View {
        if dataManager.hasInheritedAccounts {
            VStack(alignment: .leading, spacing: 16) {
                Text("Inherited IRA Projections")
                    .font(.headline)

                ForEach(dataManager.inheritedAccounts) { account in
                    let growthRate = account.owner == .spouse ? dataManager.spouseGrowthRate : dataManager.primaryGrowthRate
                    let projections = projectInheritedIRA(account: account, growthPercent: growthRate)

                    if !projections.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            // Account header
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .foregroundStyle(.orange)
                                    Text(account.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    if dataManager.enableSpouse {
                                        Text(account.owner.rawValue)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.purple.opacity(0.2))
                                            .foregroundStyle(.purple)
                                            .clipShape(Capsule())
                                    }
                                }
                                Spacer()
                                if let beneficiary = account.beneficiaryType {
                                    Text(beneficiary.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }

                            // Growth rate note
                            Text("Using \(growthRate, specifier: "%.1f")% annual growth rate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            // Table header
                            HStack(spacing: 0) {
                                Text("Year")
                                    .frame(width: 50, alignment: .leading)
                                Text("Balance")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("RMD")
                                    .frame(width: 90, alignment: .trailing)
                                if projections.first?.remaining != nil {
                                    Text("Left")
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)

                            // Rows
                            VStack(spacing: 4) {
                                ForEach(projections) { row in
                                    HStack(spacing: 0) {
                                        Text("\(row.year)")
                                            .font(.caption)
                                            .fontWeight(row.year == dataManager.currentYear ? .bold : .regular)
                                            .frame(width: 50, alignment: .leading)

                                        Text(row.balance, format: .currency(code: "USD").precision(.fractionLength(0)))
                                            .font(.caption2)
                                            .frame(maxWidth: .infinity, alignment: .trailing)

                                        Text(row.rmd > 0 ? row.rmd.formatted(.currency(code: "USD").precision(.fractionLength(0))) : "—")
                                            .font(.caption)
                                            .fontWeight(row.isDeadline ? .bold : .medium)
                                            .foregroundStyle(row.isDeadline ? .red : (row.rmd > 0 ? .orange : .secondary))
                                            .frame(width: 90, alignment: .trailing)

                                        if projections.first?.remaining != nil {
                                            if let remaining = row.remaining {
                                                Text("\(remaining)")
                                                    .font(.caption)
                                                    .fontWeight(remaining <= 1 ? .bold : .regular)
                                                    .foregroundStyle(remaining <= 1 ? .red : (remaining <= 3 ? .orange : .secondary))
                                                    .frame(width: 40, alignment: .trailing)
                                            } else {
                                                Text("—")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 40, alignment: .trailing)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(
                                        row.year == dataManager.currentYear ? Color.orange.opacity(0.1) :
                                        row.isDeadline ? Color.red.opacity(0.08) :
                                        Color(PlatformColor.secondarySystemBackground)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }

                            // Deadline note
                            if let deadline = projections.last, deadline.isDeadline {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                    Text("Full remaining balance must be withdrawn by end of \(String(deadline.year))")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color(PlatformColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Helper Functions

    /// Projects a balance forward using the given annual growth rate minus RMDs.
    private func projectBalance(years: Int, startingBalance: Double, startAge: Int, rmdStartAge: Int, growthPercent: Double) -> Double {
        var balance = startingBalance
        let growthRate = growthPercent / 100.0

        for year in 0..<years {
            let age = startAge + year

            if age >= rmdStartAge {
                let rmd = dataManager.calculateRMD(for: age, balance: balance)
                balance -= rmd
            }

            balance *= (1 + growthRate)
        }

        return max(0, balance)
    }

    /// Returns the current age of the account's owner.
    private func accountOwnerAge(for account: IRAAccount) -> Int {
        switch account.owner {
        case .spouse:
            return dataManager.spouseCurrentAge
        default:
            return dataManager.currentAge
        }
    }

    /// Returns the RMD start age for the account's owner.
    private func accountOwnerRMDAge(for account: IRAAccount) -> Int {
        switch account.owner {
        case .spouse:
            return dataManager.spouseRmdAge
        default:
            return dataManager.rmdAge
        }
    }
}

// MARK: - Supporting Views

struct AccountRMDRow: View {
    let accountName: String
    var ownerLabel: String? = nil
    let balance: Double
    let rmd: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let ownerLabel = ownerLabel {
                        Text(ownerLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(balance, format: .currency(code: "USD"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Required Withdrawal")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(rmd, format: .currency(code: "USD"))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CombinedRMDProjectionRow: View {
    let year: Int
    let isCurrentYear: Bool
    let primaryAge: Int?
    let primaryBalance: Double?
    let primaryRMD: Double?
    let spouseAge: Int?
    let spouseBalance: Double?
    let spouseRMD: Double?
    let totalRMD: Double

    private let currencyFormat = FloatingPointFormatStyle<Double>.Currency(code: "USD").precision(.fractionLength(0))

    var body: some View {
        HStack(spacing: 0) {
            // Year
            Text("\(year)")
                .font(.caption)
                .fontWeight(isCurrentYear ? .bold : .regular)
                .frame(width: 50, alignment: .leading)

            // Primary: Age / Balance / RMD
            personColumns(age: primaryAge, balance: primaryBalance, rmd: primaryRMD)

            Color.clear.frame(width: 8)

            // Spouse: Age / Balance / RMD
            personColumns(age: spouseAge, balance: spouseBalance, rmd: spouseRMD)

            Color.clear.frame(width: 8)

            // Total RMD
            if totalRMD > 0 {
                Text(totalRMD, format: currencyFormat)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(isCurrentYear ? .blue : .primary)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isCurrentYear ? Color.blue.opacity(0.1) : Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func personColumns(age: Int?, balance: Double?, rmd: Double?) -> some View {
        if let age = age {
            Text("\(age)")
                .font(.caption)
                .frame(width: 32, alignment: .trailing)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }

        if let balance = balance {
            Text(balance, format: currencyFormat)
                .font(.caption2)
                .frame(width: 95, alignment: .trailing)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 95, alignment: .trailing)
        }

        if let rmd = rmd {
            Text(rmd, format: currencyFormat)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

struct RMDProjectionRow: View {
    let year: Int
    let age: Int
    let balance: Double
    let rmd: Double
    let isCurrentYear: Bool

    var body: some View {
        HStack {
            Text("\(year)")
                .font(.callout)
                .fontWeight(isCurrentYear ? .bold : .regular)
                .frame(width: 50, alignment: .leading)

            Text("\(age)")
                .font(.callout)
                .frame(width: 40, alignment: .trailing)

            Spacer()

            Text(balance, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 140, alignment: .trailing)

            Spacer()

            Text(rmd, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(isCurrentYear ? .blue : .primary)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrentYear ? Color.blue.opacity(0.1) : Color(PlatformColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    RMDCalculatorView()
        .environmentObject(DataManager())
}
