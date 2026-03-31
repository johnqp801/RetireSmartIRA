//
//  SSCouplesStrategyView.swift
//  RetireSmartIRA
//
//  Couples claiming strategy analysis — heat map matrix, top strategy,
//  and survivor impact summary.
//

import SwiftUI

struct SSCouplesStrategyView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var showGuide = false
    @State private var showValuationNote = false
    @State private var selectedCell: SSCouplesMatrixCell?

    private var matrix: [SSCouplesMatrixCell] {
        dataManager.ssCouplesMatrix()
    }

    private var topStrategy: SSCouplesTopStrategy? {
        dataManager.ssCouplesTopStrategy()
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
                    if matrix.isEmpty {
                        emptyState
                    } else {
                        topStrategyCard
                        howToReadCard
                        matrixCard
                        if let cell = selectedCell {
                            cellDetailCard(cell)
                        }
                        deemedFilingCard
                        survivorPreviewCard
                    }
                }
                .padding()
            }
            .background(Color(PlatformColor.systemGroupedBackground))
            .navigationTitle("Couples Strategy")
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

    // MARK: - Top Strategy Card

    private var topStrategyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highest Potential Lifetime Benefits")
                .font(.headline)

            if let rec = topStrategy {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(primaryName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Age \(rec.primaryClaimingAge)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }

                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        Text(spouseName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Age \(rec.spouseClaimingAge)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isPresentValue ? "Present Value" : "Combined Lifetime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.formatLargeCurrency(rec.combinedLifetime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.orange)
                    Text(rec.rationale)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Monthly while both alive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(SSCalculationEngine.formatCurrency(rec.monthlyWhileBothAlive) + "/mo")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - How to Read This

    private var howToReadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showGuide.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.blue)
                    Text("How to Read the Strategy Table")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showGuide ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }

            if showGuide {
                VStack(alignment: .leading, spacing: 14) {
                    guideStep(
                        number: "1",
                        title: "Each cell is a strategy",
                        detail: "\(primaryName)'s claiming age is across the top. \(spouseName)'s age is down the side. Where they meet shows the combined lifetime SS income for that pair of choices."
                    )
                    guideStep(
                        number: "2",
                        title: "Look for the green zone",
                        detail: "Greener cells have higher lifetime benefits. The green-bordered cell has the highest potential total. Your current planned ages are outlined in blue."
                    )
                    guideStep(
                        number: "3",
                        title: "Compare nearby cells",
                        detail: "Tap any cell to see its details. Check what happens if either spouse claims 1-2 years earlier or later — small changes in timing can mean large differences."
                    )
                    guideStep(
                        number: "4",
                        title: "Notice the pattern",
                        detail: "In most cases, the higher earner delaying to 70 produces the best outcomes — it maximizes the survivor benefit that protects the surviving spouse."
                    )
                    guideStep(
                        number: "5",
                        title: "This is a joint decision",
                        detail: "Don't optimize each person's claiming age separately. What matters is the combination — when one spouse delays, the other may benefit from claiming earlier to bridge the income gap."
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func guideStep(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Cell Detail Card

    private func cellDetailCard(_ cell: SSCouplesMatrixCell) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .foregroundStyle(.blue)
                Text("Selected Strategy")
                    .font(.headline)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryName + " claims at \(cell.primaryClaimingAge)")
                        .font(.subheadline)
                    Text(SSCalculationEngine.formatCurrency(cell.primaryMonthly) + "/mo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(spouseName + " claims at \(cell.spouseClaimingAge)")
                        .font(.subheadline)
                    Text(SSCalculationEngine.formatCurrency(cell.spouseMonthly) + "/mo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Combined monthly")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatCurrency(cell.primaryMonthly + cell.spouseMonthly) + "/mo")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isPresentValue ? "Present value" : "Lifetime total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(SSCalculationEngine.formatLargeCurrency(cell.combinedLifetimeBenefit))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("If \(primaryName) passes first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Survivor gets " + SSCalculationEngine.formatCurrency(cell.survivorBenefitIfPrimaryDies) + "/mo")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("If \(spouseName) passes first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Survivor gets " + SSCalculationEngine.formatCurrency(cell.survivorBenefitIfSpouseDies) + "/mo")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Deemed Filing Card

    private var deemedFilingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Current Rules: Deemed Filing")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text("Under current law (for anyone born 1954 or later), when you file for Social Security you automatically receive the **higher** of your own benefit or your spousal benefit. You cannot claim one now and switch to the other later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Matrix Card

    private var isPresentValue: Bool {
        dataManager.ssWhatIfParams.discountRate > 0
    }

    private var matrixCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claiming Age Combinations")
                .font(.headline)

            // Valuation mode toggle
            valuationToggle

            Text("Tap any cell to see details. \(primaryName)'s age across top, \(spouseName)'s down the side.")
                .font(.caption)
                .foregroundStyle(.secondary)

            matrixGrid

            // Legend
            HStack(spacing: 16) {
                legendItem(color: .green, label: "Highest lifetime")
                legendItem(color: .blue, label: "Your current plan")
                legendItem(color: .orange, label: "Selected")
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Valuation Mode

    private var valuationToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Values shown as")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: Binding(
                    get: { isPresentValue ? 1 : 0 },
                    set: {
                        dataManager.ssWhatIfParams.discountRate = $0 == 1 ? 3.0 : 0
                        selectedCell = nil
                        dataManager.saveAllData()
                    }
                )) {
                    Text("Total Dollars").tag(0)
                    Text("Present Value").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            if isPresentValue {
                VStack(spacing: 4) {
                    HStack {
                        Text("Discount Rate")
                            .font(.caption)
                        Spacer()
                        Text("\(dataManager.ssWhatIfParams.discountRate, specifier: "%.1f")%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .trailing)
                    }
                    Slider(
                        value: $dataManager.ssWhatIfParams.discountRate,
                        in: 1...6, step: 0.5
                    )
                    .tint(.blue)
                    .onChange(of: dataManager.ssWhatIfParams.discountRate) {
                        selectedCell = nil
                        dataManager.saveAllData()
                    }
                }
            }

            // Explanation toggle
            Button {
                withAnimation { showValuationNote.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(isPresentValue ? "What is Present Value?" : "What does Total Dollars mean?")
                        .font(.caption)
                    Spacer()
                    Image(systemName: showValuationNote ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
            }

            if showValuationNote {
                valuationExplanation
            }
        }
    }

    private var valuationExplanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isPresentValue {
                Text("**Present Value** answers: \"What is this stream of future payments worth in today's dollars?\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("A dollar received 20 years from now is worth less than a dollar today, because today's dollar could be invested. The discount rate represents what you could earn on safe investments (like Treasury bonds).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("**Why it matters:** Total Dollars tends to favor delaying (bigger numbers from COLA compounding), which can be misleading. Present Value gives a more balanced comparison by accounting for the time value of money.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("**Typical rates:** 2-3% matches Treasury/TIPS yields. Higher rates favor claiming earlier; lower rates favor delaying.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("**Total Dollars** shows the sum of all SS payments you would receive over your lifetime, adjusted for annual COLA increases (\(String(format: "%.1f", dataManager.ssWhatIfParams.colaRate))%).")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("This is the simplest view — it answers: \"How many total dollars will we collect?\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("**Keep in mind:** These are future dollars, not today's purchasing power. A dollar at age 85 buys less than a dollar today. For a more rigorous comparison, switch to Present Value.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(color, lineWidth: 2)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var matrixGrid: some View {
        let ages = Array(62...70)
        let maxVal = matrix.map(\.combinedLifetimeBenefit).max() ?? 1
        let minVal = matrix.map(\.combinedLifetimeBenefit).min() ?? 0
        let range = maxVal - minVal

        let currentPrimaryAge = dataManager.primarySSBenefit?.plannedClaimingAge ?? 67
        let currentSpouseAge = dataManager.spouseSSBenefit?.plannedClaimingAge ?? 67

        return VStack(spacing: 2) {
            // Header row
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 28, height: 24)
                ForEach(ages, id: \.self) { age in
                    Text("\(age)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
            }

            // Data rows
            ForEach(ages, id: \.self) { sAge in
                HStack(spacing: 2) {
                    Text("\(sAge)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(width: 28, height: 32)

                    ForEach(ages, id: \.self) { pAge in
                        let cell = matrix.first(where: {
                            $0.primaryClaimingAge == pAge && $0.spouseClaimingAge == sAge
                        })
                        if let cell = cell {
                            matrixCellView(
                                cell: cell,
                                intensity: range > 0 ? (cell.combinedLifetimeBenefit - minVal) / range : 0.5,
                                isCurrent: pAge == currentPrimaryAge && sAge == currentSpouseAge
                            )
                        }
                    }
                }
            }
        }
    }

    private func matrixCellView(cell: SSCouplesMatrixCell, intensity: Double, isCurrent: Bool) -> some View {
        let abbreviated = abbreviatedCurrency(cell.combinedLifetimeBenefit)
        let isSelected = selectedCell?.primaryClaimingAge == cell.primaryClaimingAge &&
                         selectedCell?.spouseClaimingAge == cell.spouseClaimingAge
        return Text(abbreviated)
            .font(.system(size: 9))
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(cellColor(intensity: intensity, isHighestLifetime: cell.isHighestLifetime))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        isSelected ? Color.orange :
                        cell.isHighestLifetime ? Color.green :
                        isCurrent ? Color.blue : Color.clear,
                        lineWidth: isSelected || cell.isHighestLifetime ? 2 : 1.5
                    )
            )
            .onTapGesture {
                withAnimation { selectedCell = cell }
            }
    }

    private func cellColor(intensity: Double, isHighestLifetime: Bool) -> Color {
        if isHighestLifetime {
            return Color.green.opacity(0.25)
        }
        // Gradient from red (low) through yellow to green (high)
        let clamped = min(max(intensity, 0), 1)
        if clamped < 0.5 {
            let t = clamped * 2
            return Color(red: 0.9 - t * 0.4, green: 0.3 + t * 0.5, blue: 0.2, opacity: 0.15 + t * 0.1)
        } else {
            let t = (clamped - 0.5) * 2
            return Color(red: 0.5 - t * 0.3, green: 0.8 + t * 0.1, blue: 0.2, opacity: 0.2 + t * 0.1)
        }
    }

    private func abbreviatedCurrency(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    // MARK: - Survivor Preview Card

    private var survivorPreviewCard: some View {
        let scenarios = dataManager.ssSurvivorScenarios()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Survivor Benefit Impact")
                .font(.headline)

            Text("How SS income changes when one spouse passes, based on your planned claiming ages.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(scenarios) { scenario in
                VStack(alignment: .leading, spacing: 8) {
                    Text(scenario.title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Before")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(SSCalculationEngine.formatCurrency(scenario.householdMonthlyBefore) + "/mo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("After")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(SSCalculationEngine.formatCurrency(scenario.householdMonthlyAfter) + "/mo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Reduction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("-\(String(format: "%.0f", scenario.percentReduction))%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text(scenario.survivorBenefitSource)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("  \u{2022}  ")
                            .foregroundStyle(.tertiary)
                        Text(scenario.filingStatusChange)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)

                if scenario.id != scenarios.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Couples Strategy")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("Enter benefit estimates for both you and your spouse to compare claiming strategies and see survivor analysis.")
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
