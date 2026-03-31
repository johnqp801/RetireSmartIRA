//
//  SSSurvivorAnalysisView.swift
//  RetireSmartIRA
//
//  Detailed survivor benefit analysis — income before/after for each
//  death-order scenario, filing status implications, and key takeaways.
//

import SwiftUI
import Charts

struct SSSurvivorAnalysisView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    private var scenarios: [SSSurvivorScenario] {
        dataManager.ssSurvivorScenarios()
    }

    private var primaryName: String {
        dataManager.userName.isEmpty ? "You" : dataManager.userName
    }

    private var spouseName: String {
        dataManager.spouseName.isEmpty ? "Spouse" : dataManager.spouseName
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if scenarios.isEmpty {
                        emptyState
                    } else {
                        overviewCard
                        ForEach(scenarios) { scenario in
                            scenarioCard(scenario)
                        }
                        keyTakeawaysCard
                    }
                }
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle("Survivor Analysis")
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

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Survivor Benefits")
                .font(.headline)

            Text("When one spouse passes, the survivor keeps the higher of the two Social Security benefits — not both. This means household SS income drops significantly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !scenarios.isEmpty {
                let combined = scenarios[0].householdMonthlyBefore
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current combined SS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.formatCurrency(combined) + "/mo")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Annual")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.formatCurrency(combined * 12) + "/yr")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Scenario Card

    private func scenarioCard(_ scenario: SSSurvivorScenario) -> some View {
        let survivorName = scenario.deceasedOwner == .primary ? spouseName : primaryName
        let deceasedName = scenario.deceasedOwner == .primary ? primaryName : spouseName

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill.xmark")
                    .foregroundStyle(.red)
                Text(scenario.title)
                    .font(.headline)
            }

            Text("\(deceasedName) passes. \(survivorName) continues with the higher benefit.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Before/After comparison bars
            survivorBarChart(scenario: scenario, survivorName: survivorName)
                .frame(height: 120)

            HStack(spacing: 0) {
                statBlock(
                    label: "Before",
                    value: SSCalculationEngine.formatCurrency(scenario.householdMonthlyBefore),
                    detail: "/mo combined",
                    color: .primary
                )
                Spacer()
                statBlock(
                    label: "After",
                    value: SSCalculationEngine.formatCurrency(scenario.householdMonthlyAfter),
                    detail: "/mo survivor",
                    color: .orange
                )
                Spacer()
                statBlock(
                    label: "Monthly Loss",
                    value: SSCalculationEngine.formatCurrency(scenario.monthlyReduction),
                    detail: String(format: "-%.0f%%", scenario.percentReduction),
                    color: .red
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("Survivor receives: \(scenario.survivorBenefitSource)")
                        .font(.caption)
                }
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Filing status: \(scenario.filingStatusChange)")
                        .font(.caption)
                }
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text("Annual income drops by \(SSCalculationEngine.formatCurrency(scenario.monthlyReduction * 12))/yr")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func statBlock(label: String, value: String, detail: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func survivorBarChart(scenario: SSSurvivorScenario, survivorName: String) -> some View {
        let data: [(String, Double, Color)] = [
            ("Both Alive", scenario.householdMonthlyBefore, .blue),
            ("Survivor (\(survivorName))", scenario.householdMonthlyAfter, .orange),
        ]

        return Chart {
            ForEach(data, id: \.0) { label, amount, color in
                BarMark(
                    x: .value("Scenario", label),
                    y: .value("Monthly", amount)
                )
                .foregroundStyle(color.gradient)
                .cornerRadius(6)
                .annotation(position: .top) {
                    Text(SSCalculationEngine.formatCurrency(amount))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("$\(String(format: "%.0f", amount))")
                            .font(.caption2)
                    }
                }
            }
        }
    }

    // MARK: - Key Takeaways

    private var keyTakeawaysCard: some View {
        let higherEarnerDelays = isHigherEarnerDelaying

        return VStack(alignment: .leading, spacing: 12) {
            Text("Key Takeaways")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                takeaway(
                    icon: "1.circle.fill",
                    color: .blue,
                    text: "The survivor keeps the **higher** of the two benefits, not both. Plan for a significant income drop."
                )
                takeaway(
                    icon: "2.circle.fill",
                    color: .blue,
                    text: "Filing status changes from Married Filing Jointly to Single, which can **increase taxes** on the remaining benefit."
                )
                takeaway(
                    icon: "3.circle.fill",
                    color: .blue,
                    text: higherEarnerDelays
                        ? "The higher earner is delaying benefits, which **maximizes the survivor benefit** — a strong strategy."
                        : "Consider having the higher earner **delay to 70** to maximize the survivor benefit for the surviving spouse."
                )
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func takeaway(icon: String, color: Color, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var isHigherEarnerDelaying: Bool {
        guard let p = dataManager.primarySSBenefit,
              let s = dataManager.spouseSSBenefit else { return false }
        if p.benefitAtFRA >= s.benefitAtFRA {
            return p.plannedClaimingAge >= 69
        } else {
            return s.plannedClaimingAge >= 69
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Survivor Analysis")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Enter benefit estimates for both spouses to see how SS income changes when one spouse passes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
