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
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Legacy Impact")
                            .font(.headline)
                        Text("How your decisions affect your heirs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // SECTION A: Family Wealth Impact (clean headline)
                if hasRothConversion {
                    familyWealthSection
                }

                // Compounding chart (always visible — most intuitive visual)
                if hasRothConversion {
                    compoundingChartSection
                }

                // Progressive disclosure toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showLegacyDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showLegacyDetails ? "Hide Details" : "See the Full Advantages of Converting")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: showLegacyDetails ? "chevron.up" : "chevron.down")
                            .font(.caption2)
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

                    // SECTION C: Break-Even + Time Horizon
                    if hasRothConversion {
                        breakEvenSection
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

    // MARK: - Section A: Family Wealth Impact

    private var familyWealthSection: some View {
        VStack(spacing: 10) {
            Text("Family Wealth Impact")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Without conversion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dataManager.legacyNoConversionTotalWealth, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    let conversionLabel = compactCurrency(dataManager.scenarioTotalRothConversion)
                    Text("With \(conversionLabel) Roth conversion")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(dataManager.legacyWithConversionTotalWealth, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.title3)
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
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(abs(advantage), format: .currency(code: "USD").precision(.fractionLength(0)))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(advantage >= 0 ? .green : .orange)
            }
            .frame(maxWidth: .infinity)

            let rotp = dataManager.legacyReturnOnTaxesPaid
            if dataManager.legacyConversionTaxPaidToday > 0 && abs(rotp) > 0.1 {
                let rotpFmt = String(format: "%.1f", abs(rotp))
                Text("Equivalent to a \(rotpFmt)% return on the \(compactCurrency(dataManager.legacyConversionTaxPaidToday)) in taxes paid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            let deathAge = dataManager.legacyEstimatedDeathAge
            let yearsLeft = dataManager.legacyYearsUntilDeath
            let growthPct = Int(dataManager.primaryGrowthRate)
            Group {
                if dataManager.legacyHeirType == "spouseThenChild" {
                    Text("Projected \(yearsLeft) years to age \(deathAge), then spouse rollover for \(dataManager.legacySpouseSurvivorYears) years, then child's 10-year drawdown at \(growthPct)% growth")
                } else {
                    let drawdownYears = dataManager.legacyDrawdownYears
                    Text("Projected \(yearsLeft) years to age \(deathAge), then heir's \(drawdownYears)-year drawdown at \(growthPct)% growth")
                }
            }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Compounding Divergence Chart

    private var compoundingChartSection: some View {
        let chartData = dataManager.legacyCompoundingChartData
        return Group {
            if chartData.count >= 2 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("How Roth Conversions Increase Family Wealth Over Time")
                        .font(.caption)
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
                                        .font(.caption2)
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
                                        .font(.caption2)
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
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartLegend(position: .bottom, spacing: 4)
                    .frame(height: 200)

                    if let beYear = breakEvenYr {
                        if beYear == 0 {
                            VStack(spacing: 2) {
                                Text("Under these assumptions, Roth wins immediately.")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                Text("Higher future tax rates (widow bracket jump or the SECURE Act 10-year rule for heirs) would strengthen the advantage further.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 2) {
                                Text("Under these assumptions, Roth overtakes Traditional at year \(beYear).")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                Text("Higher future tax rates (widow bracket jump or the SECURE Act 10-year rule for heirs) would move the crossover earlier.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text("The Roth advantage grows the longer the money compounds")
                        .font(.caption2)
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
        let growthPct = Int(dataManager.primaryGrowthRate)
        let taxGrowthFmt = String(format: "%.1f", dataManager.taxableAccountGrowthRate)

        return Group {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text("Why This Works")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                HStack(spacing: 0) {
                    Text("You pay ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(taxPaid, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(" today to permanently move ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(converted, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Text(" into tax-free compounding.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                (Text("Roth conversions shift money from taxable compounding to tax-free compounding.")
                    .fontWeight(.bold) +
                Text(" Over time, tax-free compounding wins."))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Roth compounds at \(growthPct)% tax-free \u{2014} no RMDs, no tax on withdrawal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 6, height: 6)
                        Text("Tax dollars you kept only compound at ~\(taxGrowthFmt)% after tax drag")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if converted > 0 {
                    let per100K = (abs(dataManager.legacyFamilyWealthAdvantage) / converted) * 100_000
                    let per100KLabel = compactCurrency(per100K)
                    let direction = dataManager.legacyFamilyWealthAdvantage >= 0 ? "adds" : "costs"
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.green)
                            .font(.caption2)
                        Text("Under these assumptions, every $100K converted \(direction) about \(per100KLabel) of family wealth")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
            }
        }
    }

    // MARK: - Section C: Break-Even Analysis

    private var breakEvenSection: some View {
        Group {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("Break-Even Analysis")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                let breakEvenPct = Int(dataManager.legacyBreakEvenHeirTaxRate * 100)
                let heirPct = Int(dataManager.legacyHeirTaxRate * 100)
                let favorable = dataManager.legacyConversionIsFavorable

                HStack(spacing: 6) {
                    Image(systemName: favorable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(favorable ? .green : .orange)
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conversion wins if heir's rate exceeds \(breakEvenPct)%")
                            .font(.caption)
                            .fontWeight(.semibold)
                        let statusText = favorable
                            ? "Your heir's \(heirPct)% rate clears the \(breakEvenPct)% threshold"
                            : "Your heir's \(heirPct)% rate is below the \(breakEvenPct)% threshold \u{2014} consider carefully"
                        Text(statusText)
                            .font(.caption2)
                            .foregroundStyle(favorable ? .green : .secondary)
                    }
                }

                let horizons = dataManager.legacyBreakEvenAtHorizons
                if !horizons.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Time Horizon")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Break-even")
                                .frame(maxWidth: .infinity, alignment: .center)
                            Text("Family Gain")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)

                        ForEach(horizons, id: \.years) { h in
                            HStack {
                                Text("\(h.years) years")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(Int(h.rate * 100))%")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                let label = h.advantage >= 0
                                    ? "+\(compactCurrency(h.advantage))"
                                    : "-\(compactCurrency(abs(h.advantage)))"
                                Text(label)
                                    .foregroundStyle(h.advantage >= 0 ? .green : .orange)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .font(.caption)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("The longer the money compounds, the more Roth conversions favor the family")
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(.secondary)
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
                        .font(.subheadline)
                    Text("QCD Legacy Benefit")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                let qcdAmount = compactCurrency(dataManager.scenarioTotalQCD)
                let qcdSavings = compactCurrency(dataManager.legacyQCDHeirBenefit)
                Text("Removes \(qcdAmount) from your IRA tax-free \u{2014} saves heir ~\(qcdSavings) in future taxes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dataManager.legacyHeirType == "spouseThenChild"
                     ? "Reduces child's eventual 10-year tax burden"
                     : "Reduces heir's \(dataManager.legacyDrawdownYears)-year tax burden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        .font(.caption)
                    Text("Surviving Spouse Tax Bracket Jump")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        VStack(spacing: 2) {
                            Text("Now (MFJ)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(currentPct)%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity)

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.red)
                            .fontWeight(.bold)

                        VStack(spacing: 2) {
                            Text("Survivor (Single)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(survivorPct)%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("Jump")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("+\(jumpPts) pts")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Text("When one spouse passes, the survivor files Single \u{2014} but income barely drops. The same IRA withdrawals get taxed at higher Single rates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if hasRothConversion {
                        let savings = dataManager.widowConversionBracketSavings
                        if savings > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "shield.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption2)
                                Text("Converting now at \(currentPct)% avoids the survivor paying \(survivorPct)% later \u{2014} saves \(compactCurrency(savings)) in bracket arbitrage")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Text("This creates a \"golden conversion window\" \u{2014} while both spouses are alive, you have wider married tax brackets and two standard deductions. Convert now before the window closes.")
                        .font(.caption2)
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
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("No Scenario")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("With Scenario")
                        .font(.caption2)
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
                    .font(.caption2)
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

        return Group {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("What Your Heir Actually Inherits")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                if tradAtDeath > 0 {
                    let annualForced = tradAtDeath / Double(drawdownYears)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            if dataManager.legacyHeirType == "spouseThenChild" {
                                Text("Traditional IRA: \(compactCurrency(tradAtDeath)) \u{2014} spouse rolls over, then child empties in 10 years")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Traditional IRA: \(compactCurrency(tradAtDeath)) \u{2014} must be emptied in \(drawdownYears) years")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 4) {
                            Text("   ")
                                .font(.caption2)
                            Text("~\(compactCurrency(annualForced))/year added to heir's taxable income")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }

                        if rothAtDeath > 0 {
                            HStack(spacing: 4) {
                                Circle().fill(.green).frame(width: 6, height: 6)
                                Text("Roth IRA: \(compactCurrency(rothAtDeath)) \u{2014} tax-free, no forced timeline")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if dataManager.legacyHeirType != "spouse" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your heir receives both accounts. The \(compactCurrency(annualForced))/year from the Traditional IRA is added on top of their own salary \u{2014} potentially pushing them into the \(Int(dataManager.legacyHeirTaxRate * 100))% bracket or higher during their peak earning years.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("Every dollar you convert to Roth now is one less dollar forced through their tax bracket later.")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
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
                        .font(.caption2)
                        .padding(.top, 2)
                    Text(dataManager.legacyHeirTypeDescriptionDetailed)
                        .font(.caption)
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
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(before, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(after, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.caption)
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
