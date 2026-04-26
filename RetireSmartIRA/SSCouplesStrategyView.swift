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
    @State private var showAppliedConfirmation = false

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

    // MARK: - Claiming Status

    /// Whether the primary has effectively claimed (either marked "already claiming" or past planned age)
    private var primaryHasClaimed: Bool {
        guard let b = dataManager.primarySSBenefit, b.hasData else { return false }
        if b.isAlreadyClaiming { return true }
        let age = dataManager.currentYear - dataManager.birthYear
        return age >= b.plannedClaimingAge
    }

    /// Whether the spouse has effectively claimed
    private var spouseHasClaimed: Bool {
        guard let b = dataManager.spouseSSBenefit, b.hasData else { return false }
        if b.isAlreadyClaiming { return true }
        let age = dataManager.currentYear - dataManager.spouseBirthYear
        return age >= b.plannedClaimingAge
    }

    private var bothHaveClaimed: Bool { primaryHasClaimed && spouseHasClaimed }
    private var neitherHasClaimed: Bool { !primaryHasClaimed && !spouseHasClaimed }
    private var oneClaimedOnePlanning: Bool {
        (primaryHasClaimed && !spouseHasClaimed) || (!primaryHasClaimed && spouseHasClaimed)
    }

    /// The name of the spouse who still needs to decide
    private var decidingSpouseName: String {
        primaryHasClaimed ? spouseName : primaryName
    }

    /// The name of the spouse who already claimed
    private var claimedSpouseName: String {
        primaryHasClaimed ? primaryName : spouseName
    }

    /// The locked claiming age of the spouse who already claimed
    private var claimedSpouseAge: Int {
        if primaryHasClaimed {
            return dataManager.primarySSBenefit?.plannedClaimingAge ?? 67
        } else {
            return dataManager.spouseSSBenefit?.plannedClaimingAge ?? 67
        }
    }

    /// Filter the full matrix to just the row/column for the claimed spouse's age
    private var filteredStripCells: [SSCouplesMatrixCell] {
        if primaryHasClaimed {
            // Primary claimed — filter to their claiming age, vary spouse age
            return matrix.filter { $0.primaryClaimingAge == claimedSpouseAge }
                .sorted { $0.spouseClaimingAge < $1.spouseClaimingAge }
        } else {
            // Spouse claimed — filter to their claiming age, vary primary age
            return matrix.filter { $0.spouseClaimingAge == claimedSpouseAge }
                .sorted { $0.primaryClaimingAge < $1.primaryClaimingAge }
        }
    }

    /// Best cell from the filtered strip
    private var stripTopStrategy: SSCouplesMatrixCell? {
        filteredStripCells.max(by: { $0.combinedLifetimeBenefit < $1.combinedLifetimeBenefit })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if matrix.isEmpty {
                        emptyState
                    } else if bothHaveClaimed {
                        // Both have claimed — show actual current benefits
                        currentBenefitsSummaryCard
                        survivorPreviewCard
                        Divider().padding(.horizontal)
                        whatIfExplorerHeader
                        topStrategyCard
                        howToReadCard
                        matrixCard
                        if let cell = selectedCell {
                            cellDetailCard(cell)
                        }
                    } else if oneClaimedOnePlanning {
                        // One spouse claimed — show 1×9 strip optimizer for the deciding spouse
                        oneClaimedHeaderCard
                        stripRecommendationCard
                        stripMatrixCard
                        if let cell = selectedCell {
                            cellDetailCard(cell)
                        }
                        survivorPreviewCard
                        Divider().padding(.horizontal)
                        // Offer full matrix as optional exploration
                        fullMatrixDisclosure
                    } else {
                        // Both still planning — show full 9×9 optimizer
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

    // MARK: - Current Benefits Summary (Both Have Claimed)

    private var currentBenefitsSummaryCard: some View {
        let pResult = dataManager.ssEffectiveMonthlyBenefit(for: .primary)
        let sResult = dataManager.ssEffectiveMonthlyBenefit(for: .spouse)
        let combinedMonthly = pResult.monthly + sResult.monthly

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Benefits")
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.UI.brandTeal)
                Text("Both Collecting")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.UI.brandTeal)
            }

            // Primary
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let b = dataManager.primarySSBenefit {
                        Text("Claimed at age \(b.isAlreadyClaiming ? "N/A" : "\(b.plannedClaimingAge)")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(SSCalculationEngine.formatCurrency(pResult.monthly) + "/mo")
                        .font(.title3)
                        .fontWeight(.bold)
                    if pResult.includesSpousalTopUp {
                        Text("Includes \(SSCalculationEngine.formatCurrency(pResult.spousalTopUp)) spousal top-up")
                            .font(.caption2)
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }
            }

            Divider()

            // Spouse
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spouseName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let b = dataManager.spouseSSBenefit {
                        Text("Claimed at age \(b.isAlreadyClaiming ? "N/A" : "\(b.plannedClaimingAge)")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(SSCalculationEngine.formatCurrency(sResult.monthly) + "/mo")
                        .font(.title3)
                        .fontWeight(.bold)
                    if sResult.includesSpousalTopUp {
                        Text("Includes \(SSCalculationEngine.formatCurrency(sResult.spousalTopUp)) spousal top-up")
                            .font(.caption2)
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }
            }

            Divider()

            // Combined
            HStack {
                Text("Combined Household")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(SSCalculationEngine.formatCurrency(combinedMonthly) + "/mo")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.UI.textPrimary)
                    Text(SSCalculationEngine.formatCurrency(combinedMonthly * 12) + "/yr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Tie to Income & Deductions
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption2)
                    .foregroundStyle(Color.UI.brandTeal)
                Text("These amounts are synced to your Income & Deductions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - What-If Explorer Header (for already-claimed users)

    private var whatIfExplorerHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(Color.UI.textSecondary)
                Text("What-If Explorer")
                    .font(.headline)
            }
            Text("Since both spouses have already claimed, the matrix below shows what different claiming age combinations would have yielded. This can be helpful for understanding how timing affects lifetime benefits.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.UI.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                            .foregroundStyle(Color.UI.brandTeal)
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
                            .foregroundStyle(Color.Chart.callout)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isPresentValue ? "Present Value" : "Combined Lifetime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.formatLargeCurrency(rec.combinedLifetime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.UI.textPrimary)
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(Color.UI.textSecondary)
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

                // Show spousal top-up detail when claiming ages differ
                if rec.primaryClaimingAge != rec.spouseClaimingAge {
                    let earlierAge = min(rec.primaryClaimingAge, rec.spouseClaimingAge)
                    let laterAge = max(rec.primaryClaimingAge, rec.spouseClaimingAge)
                    let earlyFilerOwn = rec.primaryClaimingAge < rec.spouseClaimingAge
                        ? rec.primaryOwnMonthly : rec.spouseOwnMonthly
                    let hasSpousalTopUp = rec.primaryClaimingAge < rec.spouseClaimingAge
                        ? (rec.primaryMonthly > rec.primaryOwnMonthly)
                        : (rec.spouseMonthly > rec.spouseOwnMonthly)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption2)
                                .foregroundStyle(Color.UI.brandTeal)
                            Text("Ages \(earlierAge)–\(laterAge - 1): \(SSCalculationEngine.formatCurrency(earlyFilerOwn))/mo (own benefit only)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if hasSpousalTopUp {
                            let earlyFilerName = rec.primaryClaimingAge < rec.spouseClaimingAge
                                ? primaryName : spouseName
                            let earlyFilerTopUp = rec.primaryClaimingAge < rec.spouseClaimingAge
                                ? (rec.primaryMonthly - rec.primaryOwnMonthly)
                                : (rec.spouseMonthly - rec.spouseOwnMonthly)
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.UI.brandTeal)
                                Text("At age \(laterAge): \(earlyFilerName) gets +\(SSCalculationEngine.formatCurrency(earlyFilerTopUp))/mo spousal top-up")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Apply button — only when not both already claimed
                if !bothHaveClaimed {
                    applyStrategyButton(primaryAge: rec.primaryClaimingAge, spouseAge: rec.spouseClaimingAge)
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Apply Strategy Button

    private func applyStrategyButton(primaryAge: Int, spouseAge: Int) -> some View {
        let isCurrentPlan = dataManager.primarySSBenefit?.plannedClaimingAge == primaryAge &&
                            dataManager.spouseSSBenefit?.plannedClaimingAge == spouseAge

        return VStack(spacing: 6) {
            Divider()

            if isCurrentPlan {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("This is your current plan")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.UI.brandTeal)
                }
                .padding(.vertical, 4)
            } else if showAppliedConfirmation {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("Strategy applied! Income & Deductions updated.")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.UI.brandTeal)
                }
                .padding(.vertical, 4)
                .transition(.opacity)
            } else {
                Button {
                    applyStrategy(primaryAge: primaryAge, spouseAge: spouseAge)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                        Text("Apply This Strategy")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func applyStrategy(primaryAge: Int, spouseAge: Int) {
        // Defensive clamp: even though the matrix now excludes past ages, guard
        // against any caller (or stale selection) that might try to apply an age
        // the user has already passed.
        let clampedPrimary = max(primaryAge, dataManager.currentAge)
        let clampedSpouse = max(spouseAge, dataManager.spouseCurrentAge)
        dataManager.primarySSBenefit?.plannedClaimingAge = min(70, clampedPrimary)
        dataManager.spouseSSBenefit?.plannedClaimingAge = min(70, clampedSpouse)
        dataManager.saveSSData()
        dataManager.syncSSToIncomeSources()

        withAnimation {
            showAppliedConfirmation = true
        }

        // Auto-dismiss confirmation after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showAppliedConfirmation = false
            }
        }
    }

    // MARK: - How to Read This

    private var howToReadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showGuide.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.UI.brandTeal)
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
                .background(Color.UI.brandTeal)
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
                    .foregroundStyle(Color.UI.brandTeal)
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
                        .foregroundStyle(Color.UI.textPrimary)
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

            // Apply button — only when not both already claimed
            if !bothHaveClaimed {
                applyStrategyButton(primaryAge: cell.primaryClaimingAge, spouseAge: cell.spouseClaimingAge)
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
                    .foregroundStyle(Color.UI.textSecondary)
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
                legendItem(color: Color.UI.brandTeal, label: "Highest lifetime")
                legendItem(color: Color.UI.brandTeal, label: "Your current plan")
                legendItem(color: Color.Chart.callout, label: "Selected")
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
                    .tint(Color.UI.brandTeal)
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
                .foregroundStyle(Color.UI.brandTeal)
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
        .background(Color.UI.surfaceInset)
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
        // Restrict axes to feasible claim ages — exclude any age the user has already
        // passed, since the matrix excludes them too. When neither spouse is past 62
        // the grid is the familiar full 9×9.
        let primaryMin = max(62, min(70, dataManager.currentAge))
        let spouseMin = max(62, min(70, dataManager.spouseCurrentAge))
        let pAges = Array(primaryMin...70)
        let sAges = Array(spouseMin...70)
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
                ForEach(pAges, id: \.self) { age in
                    Text("\(age)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                }
            }

            // Data rows
            ForEach(sAges, id: \.self) { sAge in
                HStack(spacing: 2) {
                    Text("\(sAge)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(width: 28, height: 32)

                    ForEach(pAges, id: \.self) { pAge in
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
                        isSelected ? Color.Chart.callout :
                        cell.isHighestLifetime ? Color.UI.brandTeal :
                        isCurrent ? Color.UI.brandTeal : Color.clear,
                        lineWidth: isSelected || cell.isHighestLifetime ? 2 : 1.5
                    )
            )
            .onTapGesture {
                withAnimation { selectedCell = cell }
            }
    }

    private func cellColor(intensity: Double, isHighestLifetime: Bool) -> Color {
        if isHighestLifetime {
            return Color.UI.brandTeal.opacity(0.2)
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
            return String(format: "$%.2fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.0fK", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }

    // MARK: - One Claimed / One Planning Views

    /// Header explaining the one-claimed scenario
    private var oneClaimedHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill.checkmark")
                    .foregroundStyle(Color.UI.brandTeal)
                Text("\(claimedSpouseName) Has Claimed")
                    .font(.headline)
            }

            let claimedResult = primaryHasClaimed
                ? dataManager.ssEffectiveMonthlyBenefit(for: .primary)
                : dataManager.ssEffectiveMonthlyBenefit(for: .spouse)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(claimedSpouseName) claimed at age \(claimedSpouseAge)")
                        .font(.subheadline)
                    Text("Currently receiving \(SSCalculationEngine.formatCurrency(claimedResult.monthly))/mo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(Color.UI.brandTeal)
                Text("Now let's find the best claiming age for \(decidingSpouseName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    /// Recommendation card based on the best option from the 1×9 strip
    private var stripRecommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Best Claiming Age for \(decidingSpouseName)")
                .font(.headline)

            if let best = stripTopStrategy {
                let decidingAge = primaryHasClaimed ? best.spouseClaimingAge : best.primaryClaimingAge
                let decidingMonthly = primaryHasClaimed ? best.spouseMonthly : best.primaryMonthly
                let decidingOwnMonthly = primaryHasClaimed ? best.spouseOwnMonthly : best.primaryOwnMonthly
                let hasSpousalTopUp = decidingMonthly > decidingOwnMonthly + 0.01

                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(decidingSpouseName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Age \(decidingAge)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.UI.brandTeal)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isPresentValue ? "Present Value" : "Combined Lifetime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.formatLargeCurrency(best.combinedLifetimeBenefit))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.UI.textPrimary)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(decidingSpouseName)'s monthly")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.formatCurrency(decidingMonthly) + "/mo")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Combined monthly")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(SSCalculationEngine.formatCurrency(best.primaryMonthly + best.spouseMonthly) + "/mo")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.UI.textPrimary)
                    }
                }

                if hasSpousalTopUp {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.UI.brandTeal)
                        Text("Includes \(SSCalculationEngine.formatCurrency(decidingMonthly - decidingOwnMonthly))/mo spousal top-up")
                            .font(.caption)
                            .foregroundStyle(Color.UI.brandTeal)
                    }
                }

                applyStrategyButton(primaryAge: best.primaryClaimingAge, spouseAge: best.spouseClaimingAge)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    /// 1×9 strip matrix showing the deciding spouse's options
    private var stripMatrixCard: some View {
        let cells = filteredStripCells
        let maxVal = cells.map(\.combinedLifetimeBenefit).max() ?? 1
        let minVal = cells.map(\.combinedLifetimeBenefit).min() ?? 0
        let range = maxVal - minVal

        let currentDecidingAge = primaryHasClaimed
            ? (dataManager.spouseSSBenefit?.plannedClaimingAge ?? 67)
            : (dataManager.primarySSBenefit?.plannedClaimingAge ?? 67)

        return VStack(alignment: .leading, spacing: 12) {
            Text("\(decidingSpouseName)'s Claiming Age Options")
                .font(.headline)

            valuationToggle

            Text("Tap any cell to see details. \(claimedSpouseName) is locked at age \(claimedSpouseAge).")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Strip grid: header row + single data row
            VStack(spacing: 2) {
                // Header — deciding spouse's ages
                HStack(spacing: 3) {
                    Text("Age")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(width: 28, height: 24)
                    ForEach(cells, id: \.id) { cell in
                        let age = primaryHasClaimed ? cell.spouseClaimingAge : cell.primaryClaimingAge
                        Text("\(age)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                    }
                }

                // Data row — combined lifetime values
                HStack(spacing: 3) {
                    Image(systemName: "dollarsign.circle")
                        .font(.caption2)
                        .frame(width: 28, height: 48)
                        .foregroundStyle(.secondary)
                    ForEach(cells, id: \.id) { cell in
                        let intensity = range > 0 ? (cell.combinedLifetimeBenefit - minVal) / range : 0.5
                        let decidingAge = primaryHasClaimed ? cell.spouseClaimingAge : cell.primaryClaimingAge
                        let isCurrent = decidingAge == currentDecidingAge
                        stripCellView(cell: cell, intensity: intensity, isCurrent: isCurrent)
                    }
                }

                // Monthly benefit row
                HStack(spacing: 3) {
                    Text("/mo")
                        .font(.system(size: 8))
                        .frame(width: 28, height: 32)
                        .foregroundStyle(.secondary)
                    ForEach(cells, id: \.id) { cell in
                        let decidingMonthly = primaryHasClaimed ? cell.spouseMonthly : cell.primaryMonthly
                        Text(SSCalculationEngine.formatCurrency(decidingMonthly))
                            .font(.system(size: 8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                legendItem(color: Color.UI.brandTeal, label: "Highest lifetime")
                legendItem(color: Color.UI.brandTeal, label: "Current plan")
                legendItem(color: Color.Chart.callout, label: "Selected")
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private func stripCellView(cell: SSCouplesMatrixCell, intensity: Double, isCurrent: Bool) -> some View {
        let abbreviated = abbreviatedCurrency(cell.combinedLifetimeBenefit)
        let isSelected = selectedCell?.primaryClaimingAge == cell.primaryClaimingAge &&
                         selectedCell?.spouseClaimingAge == cell.spouseClaimingAge
        let isBest = cell.isHighestLifetime

        return VStack(spacing: 2) {
            Text(abbreviated)
                .font(.system(size: 9))
                .fontWeight(isBest ? .bold : .regular)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(cellColor(intensity: intensity, isHighestLifetime: isBest))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    isSelected ? Color.Chart.callout :
                    isBest ? Color.UI.brandTeal :
                    isCurrent ? Color.UI.brandTeal : Color.clear,
                    lineWidth: isSelected || isBest ? 2.5 : 1.5
                )
        )
        .onTapGesture {
            withAnimation { selectedCell = cell }
        }
    }

    /// Disclosure group to optionally show the full 9×9 matrix
    @State private var showFullMatrix = false

    private var fullMatrixDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { showFullMatrix.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tablecells")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("View Full 9×9 Matrix")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showFullMatrix ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
            }

            if showFullMatrix {
                Text("Explore all 81 claiming age combinations. \(claimedSpouseName)'s actual age (\(claimedSpouseAge)) row/column is highlighted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                matrixGrid

                HStack(spacing: 16) {
                    legendItem(color: Color.UI.brandTeal, label: "Highest lifetime")
                    legendItem(color: Color.UI.brandTeal, label: "Current plan")
                    legendItem(color: Color.Chart.callout, label: "Selected")
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
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
                                .foregroundStyle(Color.UI.textPrimary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Reduction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("-\(String(format: "%.0f", scenario.percentReduction))%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.UI.textPrimary)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(Color.UI.brandTeal)
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
                    .foregroundStyle(Color.UI.brandTeal)
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
