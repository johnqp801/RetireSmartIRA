//
//  Year1QuickEditor.swift
//  RetireSmartIRA
//
//  HARD SCOPE CAP: Roth + Withdrawal + QCD sliders (per spouse), live impact
//  strip, Restore engine optimal button. Anything else → ScenarioBuilderView
//  at .large detent / master-detail right pane.
//

import SwiftUI

struct Year1QuickEditor: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var manager: MultiYearStrategyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            sliderSection
            impactStrip
            resetButton
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var header: some View {
        HStack {
            Text("Year 1 levers")
                .font(.headline)
            Spacer()
            Text("\(dataManager.currentYear) · Editable")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(4)
        }
    }

    private var sliderSection: some View {
        VStack(spacing: 10) {
            leverSlider(
                label: "Roth (you)",
                value: Binding(
                    get: { dataManager.yourRothConversion },
                    set: { dataManager.yourRothConversion = $0 }
                ),
                maxValue: dataManager.primaryTraditionalIRABalance
            )
            if dataManager.enableSpouse {
                leverSlider(
                    label: "Roth (spouse)",
                    value: Binding(
                        get: { dataManager.spouseRothConversion },
                        set: { dataManager.spouseRothConversion = $0 }
                    ),
                    maxValue: dataManager.spouseTraditionalIRABalance
                )
            }
            leverSlider(
                label: "Withdraw (you)",
                value: Binding(
                    get: { dataManager.yourExtraWithdrawal },
                    set: { dataManager.yourExtraWithdrawal = $0 }
                ),
                maxValue: dataManager.primaryTraditionalIRABalance
            )
            if dataManager.enableSpouse {
                leverSlider(
                    label: "Withdraw (sp)",
                    value: Binding(
                        get: { dataManager.spouseExtraWithdrawal },
                        set: { dataManager.spouseExtraWithdrawal = $0 }
                    ),
                    maxValue: dataManager.spouseTraditionalIRABalance
                )
            }
            if dataManager.isQCDEligible {
                leverSlider(
                    label: "QCD (you)",
                    value: Binding(
                        get: { dataManager.yourQCDAmount },
                        set: { dataManager.yourQCDAmount = $0 }
                    ),
                    maxValue: dataManager.yourMaxQCDAmount
                )
            }
            if dataManager.enableSpouse && dataManager.spouseIsQCDEligible {
                leverSlider(
                    label: "QCD (sp)",
                    value: Binding(
                        get: { dataManager.spouseQCDAmount },
                        set: { dataManager.spouseQCDAmount = $0 }
                    ),
                    maxValue: dataManager.spouseMaxQCDAmount
                )
            }
        }
    }

    private func leverSlider(label: String, value: Binding<Double>, maxValue: Double) -> some View {
        let safeMax = max(maxValue, 1)
        return HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Slider(value: value, in: 0...safeMax, step: 1_000)
                .accessibilityLabel(label)
                .accessibilityValue(Text("$\(Int(value.wrappedValue / 1_000))K"))
            Text("$\(Int(value.wrappedValue / 1000))K")
                .font(.caption.weight(.semibold))
                .frame(width: 60, alignment: .trailing)
                .monospacedDigit()
        }
    }

    private var impactStrip: some View {
        let bracketInfo = dataManager.federalBracketInfo(
            income: dataManager.scenarioTaxableIncome,
            filingStatus: dataManager.filingStatus
        )
        return VStack(alignment: .leading, spacing: 4) {
            Text("THIS YEAR'S IMPACT")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                impactRow(label: "Federal", value: "$\(Int(dataManager.scenarioFederalTax / 1000))K")
                impactRow(label: "State", value: "$\(Int(dataManager.scenarioStateTax / 1000))K")
                impactRow(label: "IRMAA", value: irmaaText, valueColor: irmaaColor)
                impactRow(label: "Bracket", value: bracketText(info: bracketInfo))
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
    }

    private func impactRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.semibold)).foregroundColor(valueColor)
        }
    }

    private var irmaaText: String {
        let tier = dataManager.scenarioIRMAA.tier
        return tier == 0 ? "Clear" : "Tier \(tier)"
    }

    private var irmaaColor: Color {
        dataManager.scenarioIRMAA.tier == 0 ? .green : .orange
    }

    private func bracketText(info: BracketInfo) -> String {
        let pct = Int(info.currentRate * 100)
        if info.roomRemaining > 0 && info.roomRemaining < Double.infinity {
            return "\(pct)% · $\(Int(info.roomRemaining / 1000))K rm"
        }
        return "\(pct)%"
    }

    private var resetButton: some View {
        Button {
            manager.resetYear1ToEngineOptimal()
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise.circle")
                Text("Restore engine optimal")
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(isAlreadyAtOptimal)
    }

    private var isAlreadyAtOptimal: Bool {
        guard let optimal = manager.engineOptimalResult,
              let firstYear = optimal.recommendedPath.first else { return true }
        let engineRoth = firstYear.actions.compactMap { action -> Double? in
            if case .rothConversion(let a) = action { return a } else { return nil }
        }.reduce(0, +)
        let userRoth = dataManager.yourRothConversion + (dataManager.enableSpouse ? dataManager.spouseRothConversion : 0)
        return abs(engineRoth - userRoth) < 1
    }
}
