//
//  RothConversionView.swift
//  RetireSmartIRA
//
//  Analyze Roth IRA conversion strategies
//

import SwiftUI

struct RothConversionView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var conversionAmount: String = ""
    @State private var selectedOwner: Owner = .primary
    @State private var enhancedAnalysis: EnhancedRothConversionAnalysis?

    // MARK: - Computed properties

    private var spouseEnabled: Bool { dataManager.enableSpouse }

    private var spouseLabel: String {
        dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
    }

    private var selectedBalance: Double {
        selectedOwner == .primary
            ? dataManager.primaryTraditionalIRABalance
            : dataManager.spouseTraditionalIRABalance
    }

    private var selectedIsRMDRequired: Bool {
        selectedOwner == .primary
            ? dataManager.isRMDRequired
            : dataManager.spouseIsRMDRequired
    }

    private var selectedYearsUntilRMD: Int {
        selectedOwner == .primary
            ? dataManager.yearsUntilRMD
            : dataManager.spouseYearsUntilRMD
    }

    private var selectedOwnerLabel: String {
        selectedOwner == .primary ? "You" : spouseLabel
    }

    private var bracketStrategyTitle: String {
        guard let analysis = enhancedAnalysis else {
            return "Stay in Current Bracket"
        }
        return analysis.federalBracketBefore.roomRemaining > 0
            ? "Stay in Current Bracket"
            : "Top Federal Bracket"
    }

    private var bracketStrategyDescription: String {
        guard let analysis = enhancedAnalysis else {
            return "Convert up to the top of your current tax bracket to minimize rate"
        }
        let room = analysis.federalBracketBefore.roomRemaining
        let bracketPct = String(format: "%.0f", analysis.federalMarginalBefore)
        if room > 0 {
            let roomFormatted = room.formatted(.currency(code: "USD"))
            return "You can convert up to \(roomFormatted) more and stay in the \(bracketPct)% federal bracket"
        } else {
            return "Already in the \(bracketPct)% federal bracket — no ceiling on conversions within this rate"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                ownerPickerSection
                opportunityWindowSection
                calculatorSection
                analysisResultsSection
                strategyTipsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: selectedOwner) { _, _ in
            enhancedAnalysis = nil
            conversionAmount = ""
        }
        .onChange(of: dataManager.enableSpouse) { _, newValue in
            if !newValue {
                selectedOwner = .primary
                enhancedAnalysis = nil
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roth Conversion Analyzer")
                .font(.title2)
                .fontWeight(.bold)

            Text("Convert traditional IRA funds to Roth IRA. You'll pay taxes now, but future growth is tax-free.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Owner Picker

    @ViewBuilder
    private var ownerPickerSection: some View {
        if spouseEnabled {
            VStack(alignment: .leading, spacing: 8) {
                Text("Convert From")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Converting From", selection: $selectedOwner) {
                    Text("You").tag(Owner.primary)
                    Text(spouseLabel).tag(Owner.spouse)
                }
                .pickerStyle(.segmented)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Opportunity Window

    @ViewBuilder
    private var opportunityWindowSection: some View {
        if !selectedIsRMDRequired {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Conversion Opportunity Window")
                        .font(.headline)
                }

                Text("\(selectedOwnerLabel) \(selectedOwner == .primary ? "have" : "has") \(selectedYearsUntilRMD) years before RMDs start. This is an ideal time to convert while potentially in a lower tax bracket.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Calculator Card

    private var calculatorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Conversion Calculator")
                .font(.headline)

            VStack(spacing: 16) {
                HStack {
                    Text(spouseEnabled ? "\(selectedOwnerLabel)'s Traditional IRA Balance" : "Traditional IRA Balance")
                        .font(.callout)
                    Spacer()
                    Text(selectedBalance, format: .currency(code: "USD"))
                        .font(.callout)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Current Annual Income")
                        .font(.callout)
                    Spacer()
                    Text(dataManager.totalAnnualIncome(), format: .currency(code: "USD"))
                        .font(.callout)
                        .fontWeight(.semibold)
                }

                if spouseEnabled {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Tax impact based on joint filing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount to Convert")
                        .font(.callout)
                        .fontWeight(.medium)

                    TextField("Enter amount", text: $conversionAmount)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .font(.title3)
                }

                if let amount = Double(conversionAmount), amount > selectedBalance, selectedBalance > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Amount exceeds \(selectedOwnerLabel.lowercased())'s traditional IRA balance")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Button(action: calculateConversion) {
                    Text("Calculate Tax Impact")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedBalance > 0 ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(selectedBalance <= 0)

                if selectedBalance <= 0 {
                    Text("No traditional IRA balance for \(selectedOwnerLabel.lowercased()). Add accounts in the Accounts tab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Analysis Results

    @ViewBuilder
    private var analysisResultsSection: some View {
        if let analysis = enhancedAnalysis {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tax Impact Analysis")
                    .font(.headline)

                // Tax amounts
                VStack(spacing: 12) {
                    TaxRow(
                        label: "Federal Tax on Conversion",
                        amount: analysis.federalTax,
                        color: .blue
                    )

                    TaxRow(
                        label: "California Tax on Conversion",
                        amount: analysis.stateTax,
                        color: .orange
                    )

                    Divider()

                    HStack {
                        Text("Total Tax Due")
                            .font(.callout)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(analysis.totalTax, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

            // Rate Breakdown
            VStack(alignment: .leading, spacing: 16) {
                Text("Tax Rate Breakdown")
                    .font(.headline)

                // Column headers
                HStack {
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Federal")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                    Text("California")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }

                RateRow(
                    label: "Marginal (Before)",
                    federalRate: analysis.federalMarginalBefore,
                    stateRate: analysis.stateMarginalBefore,
                    highlight: false
                )

                RateRow(
                    label: "Marginal (After)",
                    federalRate: analysis.federalMarginalAfter,
                    stateRate: analysis.stateMarginalAfter,
                    highlight: analysis.crossesFederalBracket || analysis.crossesStateBracket
                )

                Divider()

                RateRow(
                    label: "Effective on Conversion",
                    federalRate: analysis.federalEffectiveRate * 100,
                    stateRate: analysis.stateEffectiveRate * 100,
                    highlight: false
                )

                RateRow(
                    label: "Combined Effective",
                    federalRate: analysis.combinedEffectiveRate * 100,
                    stateRate: nil,
                    highlight: false
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

            // Bracket Analysis
            VStack(alignment: .leading, spacing: 16) {
                Text("Bracket Analysis")
                    .font(.headline)

                BracketAnalysisCard(
                    title: "Federal",
                    bracketBefore: analysis.federalBracketBefore,
                    bracketAfter: analysis.federalBracketAfter,
                    marginalBefore: analysis.federalMarginalBefore,
                    marginalAfter: analysis.federalMarginalAfter,
                    crosses: analysis.crossesFederalBracket,
                    color: .blue
                )

                BracketAnalysisCard(
                    title: "California",
                    bracketBefore: analysis.stateBracketBefore,
                    bracketAfter: analysis.stateBracketAfter,
                    marginalBefore: analysis.stateMarginalBefore,
                    marginalAfter: analysis.stateMarginalAfter,
                    crosses: analysis.crossesStateBracket,
                    color: .orange
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Strategy Tips

    private var strategyTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversion Strategies")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                StrategyTip(
                    icon: "chart.bar.fill",
                    title: bracketStrategyTitle,
                    description: bracketStrategyDescription
                )

                StrategyTip(
                    icon: "calendar.badge.clock",
                    title: "Multi-Year Strategy",
                    description: "Spread conversions over several years before RMDs start"
                )

                StrategyTip(
                    icon: "dollarsign.circle",
                    title: "Pay Tax from Other Funds",
                    description: "Use non-retirement money to pay conversion tax for maximum benefit"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Actions

    private func calculateConversion() {
        guard let amount = Double(conversionAmount), amount > 0 else { return }

        enhancedAnalysis = dataManager.analyzeEnhancedRothConversion(
            conversionAmount: amount,
            filingStatus: dataManager.filingStatus
        )
    }
}

// MARK: - Rate Row

struct RateRow: View {
    let label: String
    let federalRate: Double
    var stateRate: Double?
    let highlight: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(federalRate, specifier: "%.1f")%")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(highlight ? .orange : .primary)
                .frame(width: 72, alignment: .trailing)

            if let stateRate = stateRate {
                Text("\(stateRate, specifier: "%.1f")%")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(highlight ? .orange : .primary)
                    .frame(width: 72, alignment: .trailing)
            } else {
                Text("")
                    .frame(width: 72, alignment: .trailing)
            }
        }
    }
}

// MARK: - Bracket Analysis Card

struct BracketAnalysisCard: View {
    let title: String
    let bracketBefore: BracketInfo
    let bracketAfter: BracketInfo
    let marginalBefore: Double
    let marginalAfter: Double
    let crosses: Bool
    let color: Color

    private var isTopBracket: Bool {
        bracketBefore.roomRemaining <= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                Spacer()
                Text("\(marginalBefore, specifier: "%.1f")% bracket")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if isTopBracket {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.to.line")
                        .foregroundStyle(.secondary)
                    Text("Already in top bracket (\(marginalBefore, specifier: "%.1f")%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("Room in current bracket")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(bracketBefore.roomRemaining, format: .currency(code: "USD"))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }

            if crosses {
                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Conversion pushes into the \(marginalAfter, specifier: "%.0f")% bracket")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Existing Supporting Views

struct TaxRow: View {
    let label: String
    let amount: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)

            Spacer()

            Text(amount, format: .currency(code: "USD"))
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}

struct StrategyTip: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RothConversionView()
        .environmentObject(DataManager())
}
