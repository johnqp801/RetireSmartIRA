import SwiftUI
import Charts

#if canImport(UIKit)
import UIKit
typealias LegacyPlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias LegacyPlatformColor = NSColor
#endif

/// Extracted from TaxPlanningView to reduce view hierarchy depth and prevent
/// EXC_BAD_ACCESS stack overflow on physical devices (iPad).
struct LegacyImpactView: View {
    @EnvironmentObject var dataManager: DataManager
    @Binding var showLegacyDetails: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.availableWidth) private var availableWidth
    private var isWideLayout: Bool { horizontalSizeClass == .regular && availableWidth > 700 }

    // Adaptive fonts: two steps up on macOS/iPad, current sizes on iPhone
    private var bodyFont: Font { isWideLayout ? .body : .caption }
    private var detailFont: Font { isWideLayout ? .subheadline : .caption2 }
    private var sectionHeader: Font { isWideLayout ? .title3 : .headline }
    private var itemHeader: Font { isWideLayout ? .headline : .subheadline }
    private var metricFont: Font { isWideLayout ? .title : .title3 }

    var body: some View {
        let hasRothConversion = dataManager.scenarioTotalRothConversion > 0
        let hasQCD = dataManager.scenarioTotalQCD > 0
        let hasLegacyContent = hasRothConversion || hasQCD

        if dataManager.enableLegacyPlanning && dataManager.hasActiveScenario && hasLegacyContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.85), .indigo.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "gift.fill")
                            .font(.title3) // icon size — keep fixed
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Legacy Impact")
                            .font(sectionHeader)
                        Text("How your decisions affect your heirs")
                            .font(bodyFont)
                            .foregroundStyle(.secondary)
                    }
                }

                // Pain vs. Gain juxtaposition
                if hasRothConversion {
                    painVsGainHeader
                }

                // SECTION A: Family Wealth Impact (clean headline)
                if hasRothConversion {
                    familyWealthSection
                }

                // Growth rate slider — key assumption, visible right where it matters
                if hasRothConversion {
                    legacyGrowthRateSlider
                }

                // Compounding chart (always visible — most intuitive visual)
                if hasRothConversion {
                    compoundingChartSection

                    // Multi-year strategy note
                    if !dataManager.isRMDRequired {
                        let rmdAge = dataManager.rmdAge
                        let currentAge = dataManager.currentAge
                        let gapYears = max(0, rmdAge - currentAge)
                        if gapYears > 1 {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.blue)
                                    .font(bodyFont)
                                Text("You have \(gapYears) gap years before RMDs start at age \(rmdAge). Converting a similar amount each year amplifies this advantage significantly. Re-evaluate annually based on updated brackets, income, and balances.")
                                    .font(bodyFont)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Progressive disclosure toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLegacyDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showLegacyDetails ? "Hide Details" : "See the Full Advantages of Converting")
                            .font(bodyFont)
                            .fontWeight(.semibold)
                        Image(systemName: showLegacyDetails ? "chevron.up" : "chevron.down")
                            .font(detailFont)
                    }
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if showLegacyDetails {
                    // SECTION B: Why This Works
                    if hasRothConversion {
                        whyThisWorksSection
                    }

                    // SECTION D: QCD Legacy Benefit
                    if hasQCD {
                        qcdBenefitSection
                    }

                    // SECTION D2: Widow Tax Bracket Warning
                    if dataManager.widowHasBracketJump {
                        widowBracketSection
                    }

                    // SECTION E: Portfolio at Inheritance
                    portfolioSection

                    // SECTION F: Heir Inheritance Reality Check
                    heirRealitySection
                } // end showLegacyDetails
            }
            .padding()
            .background(Color(LegacyPlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Pain vs. Gain Header

    private var painVsGainHeader: some View {
        let taxCost = dataManager.legacyUserCurrentCost
        let familyGain = dataManager.legacyFamilyWealthAdvantage

        return HStack(spacing: 0) {
            // Pain: tax cost today
            VStack(spacing: 4) {
                Text("Cost Today")
                    .font(detailFont)
                    .foregroundStyle(.secondary)
                Text("+\(compactCurrency(taxCost))")
                    .font(metricFont)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                Text("in tax")
                    .font(detailFont)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
                .font(bodyFont)
                .fontWeight(.bold)
                .foregroundStyle(familyGain >= 0 ? .green : .orange)

            // Gain: family wealth advantage
            VStack(spacing: 4) {
                Text("Family Gain")
                    .font(detailFont)
                    .foregroundStyle(.secondary)
                Text(familyGain >= 0 ? "+\(compactCurrency(familyGain))" : "-\(compactCurrency(abs(familyGain)))")
                    .font(metricFont)
                    .fontWeight(.bold)
                    .foregroundStyle(familyGain >= 0 ? .green : .orange)
                Text("in wealth")
                    .font(detailFont)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(familyGain >= 0 ? Color.green.opacity(0.06) : Color.orange.opacity(0.06))
        )
    }

    // MARK: - Legacy Growth Rate Slider

    private var legacyGrowthRateSlider: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Projected Growth Rate")
                    .font(bodyFont)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(dataManager.legacyGrowthRate, specifier: "%.1f")%")
                    .font(bodyFont)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                    .frame(width: 44, alignment: .trailing)
            }

            Slider(value: $dataManager.legacyGrowthRate, in: 0...12, step: 0.5)
                .tint(.blue)

            HStack {
                Text("Slide to see how different returns change the break-even year and family wealth advantage.")
                    .font(detailFont)
                    .foregroundStyle(.secondary)
                Spacer()
                if dataManager.hasCustomLegacyGrowthRate {
                    Button {
                        dataManager.resetLegacyGrowthRate()
                    } label: {
                        Text("Reset to RMD rate")
                            .font(detailFont)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: dataManager.legacyGrowthRate) {
            dataManager.saveAllData()
        }
    }

    // MARK: - Section A: Family Wealth Impact

    private var familyWealthSection: some View {
        VStack(spacing: 10) {
            Text("Family Wealth Impact")
                .font(itemHeader)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Without conversion")
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                    Text(dataManager.legacyNoConversionTotalWealth, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(metricFont)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    let conversionLabel = compactCurrency(dataManager.scenarioTotalRothConversion)
                    Text("With \(conversionLabel) Roth conversion")
                        .font(bodyFont)
                        .foregroundStyle(.green)
                    Text(dataManager.legacyWithConversionTotalWealth, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(metricFont)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
            }

            let advantage = dataManager.legacyFamilyWealthAdvantage
            HStack(spacing: 6) {
                Image(systemName: advantage >= 0 ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(advantage >= 0 ? .green : .orange)
                Text("Net family gain:")
                    .font(itemHeader)
                    .fontWeight(.semibold)
                Text(abs(advantage), format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(metricFont)
                    .fontWeight(.bold)
                    .foregroundStyle(advantage >= 0 ? .green : .orange)
            }
            .frame(maxWidth: .infinity)

            let rotp = dataManager.legacyReturnOnTaxesPaid
            if dataManager.legacyConversionTaxPaidToday > 0 && abs(rotp) > 0.1 {
                let rotpFmt = String(format: "%.1f", abs(rotp))
                Text("Equivalent to a \(rotpFmt)% return on the \(compactCurrency(dataManager.legacyConversionTaxPaidToday)) in taxes paid")
                    .font(bodyFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                if abs(rotp) > 500 {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Exceptionally high \u{2014} small conversion tax today paired with a long horizon and compounded growth produces large headline returns. Verify your growth-rate assumption and conversion amount; real-world results are sensitive to both.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8)
                }
            }

            if dataManager.scenarioTotalRothConversion > 0 && dataManager.legacyHeirEstimatedSalary > 0 {
                heirSalarySensitivityRow
            }

            let deathAge = dataManager.legacyEstimatedDeathAge
            let yearsLeft = dataManager.legacyYearsUntilDeath
            let growthPct = Int(dataManager.legacyGrowthRate)
            Group {
                if dataManager.legacyHeirType == "spouseThenChild" {
                    Text("Projected \(yearsLeft) years to age \(deathAge), then spouse rollover for \(dataManager.legacySpouseSurvivorYears) years, then child's 10-year drawdown at \(growthPct)% growth")
                } else {
                    let drawdownYears = dataManager.legacyDrawdownYears
                    Text("Projected \(yearsLeft) years to age \(deathAge), then heir's \(drawdownYears)-year drawdown at \(growthPct)% growth")
                }
            }
                .font(detailFont)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Shows net family gain at the current heir salary ±25%.
    /// Gives the user a quick read on how sensitive the conversion decision is
    /// to heir-salary uncertainty — the single biggest unknown in legacy modeling.
    private var heirSalarySensitivityRow: some View {
        let current = dataManager.legacyHeirEstimatedSalary
        let low = max(0, current * 0.75)
        let high = current * 1.25
        let gainLow = dataManager.legacyFamilyWealthAdvantage(atHeirSalary: low)
        let gainCurrent = dataManager.legacyFamilyWealthAdvantage
        let gainHigh = dataManager.legacyFamilyWealthAdvantage(atHeirSalary: high)

        func cell(title: String, salary: Double, gain: Double) -> some View {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(salary, format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(abs(gain), format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(bodyFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(gain >= 0 ? .green : .orange)
            }
            .frame(maxWidth: .infinity)
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text("If the heir's salary is different:")
                .font(detailFont)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                cell(title: "−25%", salary: low, gain: gainLow)
                cell(title: "Current", salary: current, gain: gainCurrent)
                cell(title: "+25%", salary: high, gain: gainHigh)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
    }

    // MARK: - Compounding Divergence Chart

    private var compoundingChartSection: some View {
        let chartData = dataManager.legacyCompoundingChartData
        return Group {
            if chartData.count >= 2 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("How Roth Conversions Increase Family Wealth Over Time")
                        .font(bodyFont)
                        .fontWeight(.semibold)

                    let allValues = chartData.flatMap { [$0.rothValue, $0.traditionalValue] }
                    let minVal = allValues.min() ?? 0
                    let maxVal = allValues.max() ?? 1
                    let range = maxVal - minVal
                    let yFloor = max(0, minVal - range * 0.3)
                    let yCeiling = maxVal + range * 0.1
                    let breakEvenYr = dataManager.legacyBreakEvenYear

                    Chart {
                        ForEach(chartData) { point in
                            LineMark(
                                x: .value("Year", point.year),
                                y: .value("Value", point.rothValue),
                                series: .value("Path", "Roth (tax-free)")
                            )
                            .foregroundStyle(.green)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Year", point.year),
                                y: .value("Value", point.traditionalValue),
                                series: .value("Path", "Traditional + tax $ kept")
                            )
                            .foregroundStyle(.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                            .interpolationMethod(.catmullRom)
                        }

                        ForEach(chartData) { point in
                            if point.rothValue > point.traditionalValue {
                                AreaMark(
                                    x: .value("Year", point.year),
                                    yStart: .value("Trad", point.traditionalValue),
                                    yEnd: .value("Roth", point.rothValue)
                                )
                                .foregroundStyle(.green.opacity(0.12))
                                .interpolationMethod(.catmullRom)
                            }
                        }

                        if let beYear = breakEvenYr, beYear > 0 {
                            RuleMark(x: .value("Break-even", beYear))
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                .annotation(position: .overlay, alignment: .top) {
                                    Text("Yr \(beYear)")
                                        .font(detailFont)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .offset(y: 4)
                                }
                        }
                    }
                    .chartYScale(domain: yFloor...yCeiling)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(compactCurrency(v))
                                        .font(detailFont)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let yr = value.as(Int.self) {
                                    Text("Yr \(yr)")
                                        .font(detailFont)
                                }
                            }
                        }
                    }
                    .chartLegend(position: .bottom, spacing: 4)
                    .frame(height: 200)

                    if let beYear = breakEvenYr {
                        if beYear == 0 {
                            VStack(spacing: 2) {
                                Text("Roth wins immediately at your current inputs.")
                                    .font(detailFont)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                Text("Adjust the growth rate, conversion amount, or your inputs above to see how the result moves. Higher future tax rates (widow bracket jump, or the SECURE Act 10-year rule for heirs) would strengthen the advantage further.")
                                    .font(detailFont)
                                    .foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 2) {
                                Text("Roth overtakes Traditional at year \(beYear), at your current inputs.")
                                    .font(detailFont)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                Text("Adjust the growth rate, conversion amount, or your inputs above to see how the crossover moves. Higher future tax rates (widow bracket jump, or the SECURE Act 10-year rule for heirs) would move the crossover earlier.")
                                    .font(detailFont)
                                    .foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text("The Roth advantage grows the longer the money compounds")
                        .font(detailFont)
                        .italic()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Section B: Why This Works

    private var whyThisWorksSection: some View {
        let taxPaid = dataManager.legacyConversionTaxPaidToday
        let converted = dataManager.scenarioTotalRothConversion
        let growthPct = Int(dataManager.legacyGrowthRate)
        let taxGrowthFmt = String(format: "%.1f", dataManager.taxableAccountGrowthRate)

        return Group {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(bodyFont)
                    Text("Why This Works")
                        .font(bodyFont)
                        .fontWeight(.semibold)
                }

                HStack(spacing: 0) {
                    Text("You pay ")
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                    Text(taxPaid, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(bodyFont)
                        .fontWeight(.semibold)
                    Text(" today to permanently move ")
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                    Text(converted, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(bodyFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Text(" into tax-free compounding.")
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                }

                (Text("Roth conversions shift money from taxable compounding to tax-free compounding.")
                    .fontWeight(.bold) +
                Text(" Over time, tax-free compounding wins."))
                    .font(bodyFont)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Roth compounds at \(growthPct)% tax-free \u{2014} no RMDs, no tax on withdrawal")
                            .font(detailFont)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 6, height: 6)
                        Text("Tax dollars you kept only compound at ~\(taxGrowthFmt)% after tax drag")
                            .font(detailFont)
                            .foregroundStyle(.secondary)
                    }
                    if taxPaid > 0 {
                        let taxFV = dataManager.legacyTaxMoneyFutureValue
                        HStack(alignment: .top, spacing: 4) {
                            Circle().fill(.orange).frame(width: 6, height: 6).padding(.top, 5)
                            Text("Opportunity cost: the \(compactCurrency(taxPaid)) you pay in conversion tax today would have grown to about \(compactCurrency(taxFV)) if left invested in a taxable account \u{2014} that's the bar Roth conversion has to clear.")
                                .font(detailFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if converted > 0 {
                    let per100K = (abs(dataManager.legacyFamilyWealthAdvantage) / converted) * 100_000
                    let per100KLabel = compactCurrency(per100K)
                    let direction = dataManager.legacyFamilyWealthAdvantage >= 0 ? "adds" : "costs"
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.green)
                            .font(detailFont)
                        Text("Under these assumptions, every $100K converted \(direction) about \(per100KLabel) of family wealth")
                            .font(detailFont)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            }
        }
    }

    // MARK: - Section D: QCD Legacy Benefit

    private var qcdBenefitSection: some View {
        Group {
            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.circle.fill")
                        .foregroundStyle(.green)
                        .font(itemHeader)
                    Text("QCD Legacy Benefit")
                        .font(itemHeader)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                let qcdAmount = compactCurrency(dataManager.scenarioTotalQCD)
                let qcdSavings = compactCurrency(dataManager.legacyQCDHeirBenefit)
                Text("Removes \(qcdAmount) from your IRA tax-free \u{2014} saves heir ~\(qcdSavings) in future taxes")
                    .font(bodyFont)
                    .foregroundStyle(.secondary)
                Text(dataManager.legacyHeirType == "spouseThenChild"
                     ? "Reduces child's eventual 10-year tax burden"
                     : "Reduces heir's \(dataManager.legacyDrawdownYears)-year tax burden")
                    .font(bodyFont)
                    .foregroundStyle(.secondary)

                if dataManager.scenarioTotalRothConversion > 0 {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Trade-off: QCDs can only come from Traditional IRAs. Converted Roth dollars are no longer available for QCDs. If charitable giving is a long-term goal, keeping some Traditional balance preserves that tax-free giving path.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Section D2: Widow Tax Bracket Warning

    private var widowBracketSection: some View {
        let hasRothConversion = dataManager.scenarioTotalRothConversion > 0
        let currentPct = Int(dataManager.widowCurrentMarginalRate * 100)
        let survivorPct = Int(dataManager.widowSurvivorMarginalRate * 100)
        let jumpPts = Int(dataManager.widowBracketJump * 100)

        return Group {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill.xmark")
                        .foregroundStyle(.red)
                        .font(bodyFont)
                    Text("Surviving Spouse Tax Bracket Jump")
                        .font(bodyFont)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        VStack(spacing: 2) {
                            Text("Now (MFJ)")
                                .font(detailFont)
                                .foregroundStyle(.secondary)
                            Text("\(currentPct)%")
                                .font(metricFont)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity)

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.red)
                            .fontWeight(.bold)

                        VStack(spacing: 2) {
                            Text("Survivor (Single)")
                                .font(detailFont)
                                .foregroundStyle(.secondary)
                            Text("\(survivorPct)%")
                                .font(metricFont)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("Jump")
                                .font(detailFont)
                                .foregroundStyle(.secondary)
                            Text("+\(jumpPts) pts")
                                .font(metricFont)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Text("When one spouse passes, the survivor files Single \u{2014} but income barely drops. The same IRA withdrawals get taxed at higher Single rates.")
                        .font(bodyFont)
                        .foregroundStyle(.secondary)

                    if hasRothConversion {
                        let savings = dataManager.widowConversionBracketSavings
                        if savings > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                    .foregroundStyle(.green)
                                    .font(detailFont)
                                Text("Converting now at \(currentPct)% avoids the survivor paying \(survivorPct)% later \u{2014} saves \(compactCurrency(savings)) in bracket arbitrage")
                                    .font(bodyFont)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Text("This creates a \"golden conversion window\" \u{2014} while both spouses are alive, you have wider married tax brackets and two standard deductions. Convert now before the window closes.")
                        .font(detailFont)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.red.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Section E: Portfolio at Inheritance

    private var portfolioSection: some View {
        Group {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                let deathAge = dataManager.legacyEstimatedDeathAge
                Text("Projected Portfolio at Age \(deathAge)")
                    .font(bodyFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("No Scenario")
                        .font(detailFont)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("With Scenario")
                        .font(detailFont)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                portfolioRow(
                    label: "Traditional IRA",
                    before: dataManager.legacyNoActionTraditionalAtDeath,
                    after: dataManager.legacyWithScenarioTraditionalAtDeath,
                    betterIfLower: true
                )
                portfolioRow(
                    label: "Roth IRA",
                    before: dataManager.legacyNoActionRothAtDeath,
                    after: dataManager.legacyWithScenarioRothAtDeath,
                    betterIfLower: false
                )
                portfolioRow(
                    label: "Heir's tax bill",
                    before: dataManager.legacyCostOfInaction,
                    after: dataManager.legacyWithScenarioHeirTax,
                    betterIfLower: true
                )

                Text("Traditional balance reflects RMDs taken from age \(dataManager.rmdAge)+")
                    .font(detailFont)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Section F: Heir Inheritance Reality Check

    private var heirRealitySection: some View {
        let hasRothConversion = dataManager.scenarioTotalRothConversion > 0
        let tradAtDeath = hasRothConversion
            ? dataManager.legacyWithScenarioTraditionalAtDeath
            : dataManager.legacyNoActionTraditionalAtDeath
        let rothAtDeath = hasRothConversion
            ? dataManager.legacyWithScenarioRothAtDeath
            : dataManager.legacyNoActionRothAtDeath
        let drawdownYears = dataManager.legacyHeirType == "spouseThenChild" ? 10 : dataManager.legacyDrawdownYears
        let taxEst = hasRothConversion
            ? dataManager.legacyHeirTaxEstimate
            : dataManager.legacyNoActionHeirTaxEstimate

        return Group {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(bodyFont)
                    Text("What Your Heir Actually Inherits")
                        .font(bodyFont)
                        .fontWeight(.semibold)
                }

                if tradAtDeath > 0 {
                    let annualForced = tradAtDeath / Double(drawdownYears)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            if dataManager.legacyHeirType == "spouseThenChild" {
                                Text("Traditional IRA: \(compactCurrency(tradAtDeath)) \u{2014} spouse rolls over, then child empties in 10 years")
                                    .font(bodyFont)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Traditional IRA: \(compactCurrency(tradAtDeath)) \u{2014} must be emptied in \(drawdownYears) years")
                                    .font(bodyFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 4) {
                            Text("   ")
                                .font(detailFont)
                            Text("~\(compactCurrency(annualForced))/year added to heir's taxable income")
                                .font(detailFont)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }

                        if rothAtDeath > 0 {
                            HStack(spacing: 4) {
                                Circle().fill(.green).frame(width: 6, height: 6)
                                Text("Roth IRA: \(compactCurrency(rothAtDeath)) \u{2014} tax-free, no forced timeline")
                                    .font(bodyFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if dataManager.legacyHeirType != "spouse" {
                        VStack(alignment: .leading, spacing: 8) {
                            // Tax impact summary with progressive brackets
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your heir faces ~\(compactCurrency(taxEst.incrementalTax))/year in federal taxes on these distributions alone \u{2014} at an effective rate of \(Int(taxEst.effectiveRateOnDistribution * 100))%.")
                                    .font(bodyFont)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Marginal bracket")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(Int(taxEst.marginalRate * 100))%")
                                            .font(bodyFont)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.red)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Annual tax")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(compactCurrency(taxEst.incrementalTax))
                                            .font(bodyFont)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.red)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Total over \(drawdownYears) years")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(compactCurrency(taxEst.totalTaxOverDrawdown))
                                            .font(bodyFont)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }

                            if taxEst.crossesBracket {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "arrow.up.forward.square.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                    Text("Bracket crossing: these distributions push your heir from the \(Int(taxEst.salaryOnlyMarginalRate * 100))% bracket (salary alone) up into the \(Int(taxEst.marginalRate * 100))% bracket.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }

                            if dataManager.legacyHeirKiddieTaxPossible,
                               let heirAge = dataManager.legacyHeirAgeAtInheritance {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                    Text("Kiddie Tax possible: at the projected inheritance year your heir would be about \(heirAge). If they're a dependent full-time student or minor, unearned income over the annual threshold is taxed at the supporting parent's marginal rate \u{2014} not modeled here.")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }

                            if dataManager.legacyHeirEstimatedSalary > 0 {
                                Text("On top of their \(compactCurrency(dataManager.legacyHeirEstimatedSalary)) salary, the inheritance is taxed at rates up to \(Int(taxEst.marginalRate * 100))%. Each dollar you convert to Roth now avoids tax on the heir side.")
                                    .font(bodyFont)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Every dollar you convert to Roth now is one less dollar the heir could be taxed on at up to \(Int(taxEst.marginalRate * 100))% later.")
                                    .font(bodyFont)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }

                            Text("Based on current (2026) federal brackets. Not modeled: heir's state income tax, IRMAA, NIIT, AMT, or inflation adjustments to future brackets. These can shift the heir's true rate by roughly \u{00B1}5\u{2013}15 percentage points.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: {
                        switch dataManager.legacyHeirType {
                        case "spouse": return "person.2.fill"
                        case "spouseThenChild": return "person.3.fill"
                        default: return "clock.fill"
                        }
                    }())
                        .foregroundStyle(.blue)
                        .font(detailFont)
                        .padding(.top, 2)
                    Text(dataManager.legacyHeirTypeDescriptionDetailed)
                        .font(bodyFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func portfolioRow(label: String, before: Double, after: Double, betterIfLower: Bool) -> some View {
        let improved = betterIfLower ? after < before : after > before
        return HStack {
            Text(label)
                .font(bodyFont)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(before, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(bodyFont)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(after, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(bodyFont)
                .fontWeight(.semibold)
                .foregroundStyle(improved ? .green : (after == before ? .secondary : .orange))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func compactCurrency(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$" + String(format: "%.1fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return "$" + String(format: "%.0fK", amount / 1_000)
        } else {
            return "$" + String(format: "%.0f", amount)
        }
    }
}
