//
//  RMDCalculatorView.swift
//  RetireSmartIRA
//
//  Calculate Required Minimum Distributions
//

import SwiftUI

struct RMDCalculatorView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var projectionYears = 10
    @State private var primaryGrowthRate: Double = 5.0
    @State private var spouseGrowthRate: Double = 5.0
    @State private var showGuide: Bool = false
    @State private var showAboutRMDs: Bool = false

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
                statusCard
                guideCard
                currentYearRMD
                accountBreakdown
                projectionsSection
                aboutRMDs
            }
            .padding()
        }
    }

    private var wideBody: some View {
        HStack(alignment: .top, spacing: 20) {
            ScrollView {
                VStack(spacing: 24) {
                    statusCard
                    guideCard
                    currentYearRMD
                    accountBreakdown
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(spacing: 24) {
                    projectionsSection
                    aboutRMDs
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Status Card

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

                        Text("⚠️ Warning: Delaying means taking 2 RMDs in one year")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.leading, 24)
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
        .background(Color(.systemBackground))
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
                    Text("Higher growth means larger future balances but also larger future RMDs, which increases taxable income. Use the Tax Planning tab to model the tax impact of different withdrawal strategies.")
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Current Year RMD

    @ViewBuilder
    private var currentYearRMD: some View {
        if (dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0)
            || (dataManager.enableSpouse && dataManager.spouseIsRMDRequired && dataManager.spouseTraditionalIRABalance > 0) {
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
                    .background(Color(.secondarySystemBackground))
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
                    .background(Color(.secondarySystemBackground))
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Combined Total
                if dataManager.enableSpouse &&
                    dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0 &&
                    dataManager.spouseIsRMDRequired && dataManager.spouseTraditionalIRABalance > 0 {

                    let combinedRMD = dataManager.calculateCombinedRMD()

                    Divider()

                    HStack {
                        Text("Combined Household RMD")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(combinedRMD, format: .currency(code: "USD"))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                } else if !dataManager.enableSpouse && dataManager.isRMDRequired && dataManager.primaryTraditionalIRABalance > 0 {
                    let primaryRMD = dataManager.calculatePrimaryRMD()

                    Divider()

                    HStack {
                        Text("Required Withdrawal")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Spacer()

                        Text(primaryRMD, format: .currency(code: "USD"))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
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
                            Text(dataManager.enableSpouse ? "Your Growth Rate" : "Growth Rate")
                                .font(.subheadline)
                            Spacer()
                            Text("\(primaryGrowthRate, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $primaryGrowthRate, in: -5...12, step: 0.5)
                            .tint(.blue)
                    }

                    if dataManager.enableSpouse && dataManager.spouseTraditionalIRABalance > 0 {
                        let spLabel = dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
                        HStack {
                            Text("\(spLabel)'s Growth Rate")
                                .font(.subheadline)
                            Spacer()
                            Text("\(spouseGrowthRate, specifier: "%.1f")%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $spouseGrowthRate, in: -5...12, step: 0.5)
                            .tint(.green)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
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
                                        growthPercent: primaryGrowthRate
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
                                        growthPercent: spouseGrowthRate
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
                                    growthPercent: primaryGrowthRate
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
        .background(Color(.systemBackground))
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
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
        .background(Color(.secondarySystemBackground))
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
        .background(isCurrentYear ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
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
        .background(isCurrentYear ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
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
