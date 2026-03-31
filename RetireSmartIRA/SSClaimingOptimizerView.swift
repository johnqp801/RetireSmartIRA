//
//  SSClaimingOptimizerView.swift
//  RetireSmartIRA
//
//  Detailed break-even analysis and claiming age comparison table.
//

import SwiftUI

struct SSClaimingOptimizerView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    let owner: Owner

    private var scenarios: [SSClaimingScenario] {
        dataManager.ssClaimingScenarios(for: owner)
    }

    private var breakEvens: [SSBreakEvenComparison] {
        dataManager.ssBreakEvenComparisons(for: owner)
    }

    private var lifeExpectancy: Int {
        owner == .primary
            ? dataManager.ssWhatIfParams.primaryLifeExpectancy
            : dataManager.ssWhatIfParams.spouseLifeExpectancy
    }

    private var chartData: [SSCumulativeChartPoint] {
        dataManager.ssCumulativeChartData(for: owner)
    }

    private var ownerName: String {
        if owner == .primary {
            return dataManager.userName.isEmpty ? "Your" : "\(dataManager.userName)'s"
        }
        return dataManager.spouseName.isEmpty ? "Spouse's" : "\(dataManager.spouseName)'s"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Cumulative chart with all 3 key scenarios (62, FRA, 70)
                    let filteredData = chartData.filter { point in
                        point.scenarioLabel.contains("62") ||
                        point.scenarioLabel.contains("FRA") ||
                        point.scenarioLabel.contains("67") ||
                        point.scenarioLabel.contains("70")
                    }
                    SSCumulativeBenefitsChart(
                        chartData: filteredData,
                        lifeExpectancy: lifeExpectancy,
                        breakEvenComparisons: breakEvens,
                        highlightClaimingAge: nil
                    )

                    breakEvenCard

                    allScenariosCard
                }
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle("\(ownerName) Claiming Analysis")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Break-Even Card

    private var breakEvenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Break-Even Analysis")
                .font(.headline)

            Text("The break-even age is when delaying starts to pay off compared to claiming earlier.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(breakEvens) { comparison in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Age \(comparison.earlyAge) vs. \(comparison.laterAge)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 4) {
                            Text(SSCalculationEngine.formatCurrency(comparison.earlyMonthly))
                                .foregroundStyle(.secondary)
                            Text("vs.")
                                .foregroundStyle(.tertiary)
                            Text(SSCalculationEngine.formatCurrency(comparison.laterMonthly))
                                .foregroundStyle(.secondary)
                            Text("/mo")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .font(.caption)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        if let be = comparison.breakEvenAge {
                            Text("Break-even at \(be)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(be <= lifeExpectancy ? .green : .orange)
                        } else {
                            Text("Later never catches up")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if comparison.advantageAtLifeExpectancy != 0 {
                            let adv = comparison.advantageAtLifeExpectancy
                            Text("\(adv > 0 ? "+" : "")\(SSCalculationEngine.formatLargeCurrency(adv)) by age \(lifeExpectancy)")
                                .font(.caption)
                                .foregroundStyle(adv > 0 ? .green : .red)
                        }
                    }
                }
                .padding(.vertical, 6)

                if comparison.id != breakEvens.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - All Scenarios Card

    private var allScenariosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Claiming Ages")
                .font(.headline)

            let benefit = owner == .primary ? dataManager.primarySSBenefit : dataManager.spouseSSBenefit
            let plannedAge = benefit?.plannedClaimingAge ?? 67

            ForEach(scenarios) { scenario in
                let isPlanned = scenario.claimingAge == plannedAge
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Age \(scenario.claimingAge)")
                                .font(.subheadline)
                                .fontWeight(isPlanned ? .bold : .medium)
                            if isPlanned {
                                Text("PLANNED")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                            if scenario.label.contains("FRA") {
                                Text("FRA")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(SSCalculationEngine.formatCurrency(scenario.monthlyBenefit) + "/mo")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(SSCalculationEngine.formatCurrency(scenario.annualBenefit) + "/yr")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(isPlanned ? Color.blue.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if scenario.claimingAge < 70 {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
