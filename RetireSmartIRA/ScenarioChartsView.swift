import SwiftUI
import Charts

/// Scenario bracket, IRMAA, and NIIT charts extracted from TaxPlanningView
/// to reduce view hierarchy depth and prevent stack overflow on physical devices.
struct ScenarioChartsView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        Group {
            scenarioFederalBracketChart
            scenarioStateBracketChart
            scenarioIRMAAChart
            scenarioNIITChart
        }
    }

// MARK: - Scenario Bracket & IRMAA Charts

/// Compact dollar label for bracket chart axis and annotations
private func scenarioChartLabel(_ amount: Double) -> String {
    if amount >= 1_000_000 {
        return "$\(String(format: "%.1fM", amount / 1_000_000))"
    } else if amount >= 1_000 {
        return "$\(String(format: "%.0fK", amount / 1_000))"
    } else {
        return "$\(String(format: "%.0f", amount))"
    }
}

/// Helper to find next bracket rate label
private func scenarioNextBracketRate(after currentRate: Double) -> Int {
    let brackets = dataManager.filingStatus == .single
        ? dataManager.currentTaxBrackets.federalSingle
        : dataManager.currentTaxBrackets.federalMarried
    for i in brackets.indices {
        if abs(brackets[i].rate - currentRate) < 0.001, i + 1 < brackets.count {
            return Int(brackets[i + 1].rate * 100)
        }
    }
    return Int(currentRate * 100)
}

// MARK: Federal Bracket Chart (Scenario)

private struct ScenarioBracketSegment: Identifiable {
    let id = UUID()
    let rate: Double
    let label: String
    let rangeStart: Double
    let rangeEnd: Double
    let isCurrent: Bool
}

private var scenarioBracketSegments: [ScenarioBracketSegment] {
    let brackets = dataManager.filingStatus == .single
        ? dataManager.currentTaxBrackets.federalSingle
        : dataManager.currentTaxBrackets.federalMarried
    let afterIncome = dataManager.scenarioTaxableIncome

    var segments: [ScenarioBracketSegment] = []
    for i in brackets.indices {
        let start = brackets[i].threshold
        let end: Double
        if i + 1 < brackets.count {
            end = brackets[i + 1].threshold
        } else {
            end = max(start + 50_000, afterIncome * 1.2)
        }
        let isCurrent = afterIncome > start && (i + 1 >= brackets.count || afterIncome <= brackets[i + 1].threshold)
        segments.append(ScenarioBracketSegment(
            rate: brackets[i].rate,
            label: "\(Int(brackets[i].rate * 100))%",
            rangeStart: start,
            rangeEnd: end,
            isCurrent: isCurrent
        ))
    }
    return segments
}

@ViewBuilder
private var scenarioFederalBracketChart: some View {
    if dataManager.hasActiveScenario {
        let beforeIncome = max(0, dataManager.scenarioBaseIncome - dataManager.effectiveDeductionAmount)
        let afterIncome = dataManager.scenarioTaxableIncome
        if afterIncome > 0 {
            let segments = scenarioBracketSegments
            let bracketInfo = dataManager.federalBracketInfo(income: afterIncome, filingStatus: dataManager.filingStatus)
            let bracketColors: [Color] = [
                Color(red: 0.05, green: 0.78, blue: 0.35),
                Color(red: 0.0, green: 0.72, blue: 0.68),
                Color(red: 0.98, green: 0.78, blue: 0.0),
                Color(red: 1.0, green: 0.50, blue: 0.0),
                Color(red: 0.92, green: 0.22, blue: 0.50),
                Color(red: 0.58, green: 0.22, blue: 0.88),
                Color(red: 0.18, green: 0.30, blue: 0.85),
            ]

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.green.opacity(0.85), .red.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Federal Tax Bracket Position")
                            .font(.headline)
                        Text(dataManager.filingStatus.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                let currentIdx = segments.firstIndex(where: { $0.isCurrent }) ?? 0
                let showThrough = min(currentIdx + 1, segments.count - 1)
                let visibleSegments = Array(segments.prefix(showThrough + 1))
                let chartMax = visibleSegments.last?.rangeEnd ?? 1
                let barHeight: CGFloat = 36
                let topPad: CGFloat = 40

                GeometryReader { geo in
                    let w = geo.size.width

                    // Bracket bars
                    ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                        let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                        let color = bracketColors[min(globalIdx, bracketColors.count - 1)]
                        let x = w * segment.rangeStart / chartMax
                        let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax

                        if globalIdx <= currentIdx {
                            Rectangle().fill(color)
                                .frame(width: segW, height: barHeight)
                                .offset(x: x, y: topPad)
                        } else {
                            Rectangle().fill(color.opacity(0.22))
                                .frame(width: segW, height: barHeight)
                                .offset(x: x, y: topPad)
                        }
                    }

                    // Separator lines
                    ForEach(Array(visibleSegments.dropFirst().enumerated()), id: \.element.id) { _, segment in
                        let bx = w * segment.rangeStart / chartMax
                        Rectangle().fill(Color.primary.opacity(0.2))
                            .frame(width: 1, height: barHeight)
                            .offset(x: bx - 0.5, y: topPad)
                    }

                    // Before marker (dashed gray)
                    let beforeX = CGFloat(beforeIncome / chartMax) * w
                    Path { path in
                        path.move(to: CGPoint(x: beforeX, y: topPad - 5))
                        path.addLine(to: CGPoint(x: beforeX, y: topPad + barHeight + 5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.secondary)

                    Text("Before \(scenarioChartLabel(beforeIncome))")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .position(x: min(max(beforeX, 40), w - 40), y: 10)

                    // After marker (solid)
                    let afterX = CGFloat(afterIncome / chartMax) * w
                    Path { path in
                        path.move(to: CGPoint(x: afterX, y: topPad - 5))
                        path.addLine(to: CGPoint(x: afterX, y: topPad + barHeight + 5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2.5))
                    .foregroundStyle(.primary)

                    Text("After \(scenarioChartLabel(afterIncome))")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .position(x: min(max(afterX, 35), w - 35), y: 26)

                    // Outer border
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        .frame(width: w, height: barHeight)
                        .offset(y: topPad)

                }
                .frame(height: topPad + barHeight + 6)

                // Bracket legend below bar
                HStack(spacing: 0) {
                    ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                        let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                        let isLast = index == visibleSegments.count - 1
                        let color = bracketColors[min(globalIdx, bracketColors.count - 1)]
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(segment.label)
                                    .font(.system(size: 10, weight: segment.isCurrent ? .bold : .medium))
                                    .foregroundStyle(color)
                                let rangeText1 = isLast && segment.rate >= 0.37
                                    ? scenarioChartLabel(segment.rangeStart) + "+"
                                    : scenarioChartLabel(segment.rangeStart) + "–" + scenarioChartLabel(segment.rangeEnd)
                                Text(rangeText1)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 4)

                // Average tax rate before → after
                let beforeFedTax = dataManager.calculateFederalTax(income: beforeIncome, filingStatus: dataManager.filingStatus)
                let afterFedTax = dataManager.calculateFederalTax(income: afterIncome, filingStatus: dataManager.filingStatus)
                let beforeAvgFed = beforeIncome > 0 ? (beforeFedTax / beforeIncome) * 100 : 0
                let afterAvgFed = afterIncome > 0 ? (afterFedTax / afterIncome) * 100 : 0
                HStack(spacing: 6) {
                    Image(systemName: "percent")
                        .foregroundStyle(.purple)
                        .font(.caption)
                    Text("Avg rate:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", beforeAvgFed))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f%%", afterAvgFed))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(afterAvgFed > beforeAvgFed ? .red : .green)
                }

                // Room remaining callout
                if bracketInfo.roomRemaining > 0 {
                    let nextRate = scenarioNextBracketRate(after: bracketInfo.currentRate)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text("**\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))** room before the \(nextRate)% bracket")
                                .font(.caption)
                        }
                        if dataManager.enableLegacyPlanning {
                            Text("You could convert up to ~\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0))) more this year without entering the \(nextRate)% bracket.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                } else if bracketInfo.currentRate >= 0.37 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("In the top **37%** federal bracket")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(PlatformColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .red.opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        }
    }
}

// MARK: State Bracket Chart (Scenario)

@ViewBuilder
private var scenarioStateBracketChart: some View {
    if dataManager.hasActiveScenario {
        let config = dataManager.selectedStateConfig
        switch config.taxSystem {
        case .progressive(let single, let married):
            let brackets = dataManager.filingStatus == .single ? single : married
            let beforeIncome = max(0, dataManager.scenarioBaseIncome - dataManager.effectiveDeductionAmount)
            let afterIncome = dataManager.scenarioTaxableIncome
            if afterIncome > 0 && brackets.count > 1 {
                let bracketInfo = dataManager.stateBracketInfo(income: afterIncome, filingStatus: dataManager.filingStatus)

                // Build segments
                let segments: [ScenarioBracketSegment] = brackets.enumerated().map { i, bracket in
                    let start = bracket.threshold
                    let end: Double = i + 1 < brackets.count ? brackets[i + 1].threshold : max(start + 50_000, afterIncome * 1.2)
                    let isCurrent = afterIncome > start && (i + 1 >= brackets.count || afterIncome <= brackets[i + 1].threshold)
                    return ScenarioBracketSegment(
                        rate: bracket.rate,
                        label: String(format: "%.1f%%", bracket.rate * 100),
                        rangeStart: start,
                        rangeEnd: end,
                        isCurrent: isCurrent
                    )
                }

                // Generate colors for state brackets (gradient from green to red)
                let stateColors: [Color] = segments.enumerated().map { i, _ in
                    let t = segments.count > 1 ? Double(i) / Double(segments.count - 1) : 0
                    return Color(
                        red: t * 0.9,
                        green: (1 - t) * 0.7 + 0.1,
                        blue: 0.2
                    )
                }

                let currentIdx = segments.firstIndex(where: { $0.isCurrent }) ?? 0
                let showThrough = min(currentIdx + 1, segments.count - 1)
                let visibleSegments = Array(segments.prefix(showThrough + 1))
                let chartMax = visibleSegments.last?.rangeEnd ?? 1
                let barHeight: CGFloat = 36
                let topPad: CGFloat = 40

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.green.opacity(0.85), .orange.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Image(systemName: "building.columns.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(dataManager.selectedState.rawValue) Tax Bracket")
                                .font(.headline)
                            Text(dataManager.filingStatus.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    GeometryReader { geo in
                        let w = geo.size.width

                        // Bracket bars
                        ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                            let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                            let color = stateColors[min(globalIdx, stateColors.count - 1)]
                            let x = w * segment.rangeStart / chartMax
                            let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax

                            if globalIdx <= currentIdx {
                                Rectangle().fill(color)
                                    .frame(width: segW, height: barHeight)
                                    .offset(x: x, y: topPad)
                            } else {
                                Rectangle().fill(color.opacity(0.22))
                                    .frame(width: segW, height: barHeight)
                                    .offset(x: x, y: topPad)
                            }
                        }

                        // Separator lines
                        ForEach(Array(visibleSegments.dropFirst().enumerated()), id: \.element.id) { _, segment in
                            let bx = w * segment.rangeStart / chartMax
                            Rectangle().fill(Color.primary.opacity(0.2))
                                .frame(width: 1, height: barHeight)
                                .offset(x: bx - 0.5, y: topPad)
                        }

                        // Before marker
                        let beforeX = CGFloat(beforeIncome / chartMax) * w
                        Path { path in
                            path.move(to: CGPoint(x: beforeX, y: topPad - 5))
                            path.addLine(to: CGPoint(x: beforeX, y: topPad + barHeight + 5))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .foregroundStyle(.secondary)

                        Text("Before \(scenarioChartLabel(beforeIncome))")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .position(x: min(max(beforeX, 40), w - 40), y: 10)

                        // After marker
                        let afterX = CGFloat(afterIncome / chartMax) * w
                        Path { path in
                            path.move(to: CGPoint(x: afterX, y: topPad - 5))
                            path.addLine(to: CGPoint(x: afterX, y: topPad + barHeight + 5))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 2.5))
                        .foregroundStyle(.primary)

                        Text("After \(scenarioChartLabel(afterIncome))")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .position(x: min(max(afterX, 35), w - 35), y: 26)

                        // Outer border
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            .frame(width: w, height: barHeight)
                            .offset(y: topPad)

                    }
                    .frame(height: topPad + barHeight + 6)

                    // Bracket legend below bar
                    HStack(spacing: 0) {
                        ForEach(Array(visibleSegments.enumerated()), id: \.element.id) { index, segment in
                            let globalIdx = segments.firstIndex(where: { $0.id == segment.id }) ?? index
                            let isLast = index == visibleSegments.count - 1
                            let color = stateColors[min(globalIdx, stateColors.count - 1)]
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(segment.label)
                                        .font(.system(size: 10, weight: segment.isCurrent ? .bold : .medium))
                                        .foregroundStyle(color)
                                    let rangeText2 = isLast && globalIdx == segments.count - 1
                                        ? scenarioChartLabel(segment.rangeStart) + "+"
                                        : scenarioChartLabel(segment.rangeStart) + "–" + scenarioChartLabel(segment.rangeEnd)
                                    Text(rangeText2)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 4)

                    // Average state tax rate before → after
                    let beforeStateTax = dataManager.calculateStateTax(income: beforeIncome, filingStatus: dataManager.filingStatus)
                    let afterStateTax = dataManager.calculateStateTax(income: afterIncome, filingStatus: dataManager.filingStatus)
                    let beforeAvgState = beforeIncome > 0 ? (beforeStateTax / beforeIncome) * 100 : 0
                    let afterAvgState = afterIncome > 0 ? (afterStateTax / afterIncome) * 100 : 0
                    HStack(spacing: 6) {
                        Image(systemName: "percent")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Avg rate:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", beforeAvgState))
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", afterAvgState))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(afterAvgState > beforeAvgState ? .red : .green)
                    }

                    // Room remaining callout
                    if bracketInfo.roomRemaining > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text("**\(bracketInfo.roomRemaining, format: .currency(code: "USD").precision(.fractionLength(0)))** room before the next state bracket")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(PlatformColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.green.opacity(0.3), .orange.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            }
        default:
            EmptyView()
        }
    }
}

// MARK: IRMAA Chart (Scenario)

private struct ScenarioIRMAATierSegment: Identifiable {
    let id = UUID()
    let tier: Int
    let label: String
    let rangeStart: Double
    let rangeEnd: Double
    let surchargePerPerson: Double
    let isCurrent: Bool
}

private var scenarioIRMAATierSegments: [ScenarioIRMAATierSegment] {
    let tiers = DataManager.irmaa2026Tiers
    let isMFJ = dataManager.filingStatus == .marriedFilingJointly
    let magi = dataManager.scenarioIRMAA.magi
    let currentTier = dataManager.scenarioIRMAA.tier
    let standardB = DataManager.irmaaStandardPartB

    var segments: [ScenarioIRMAATierSegment] = []
    for i in tiers.indices {
        let threshold = isMFJ ? tiers[i].mfjThreshold : tiers[i].singleThreshold
        let nextThreshold: Double
        if i + 1 < tiers.count {
            nextThreshold = isMFJ ? tiers[i + 1].mfjThreshold : tiers[i + 1].singleThreshold
        } else {
            nextThreshold = max(threshold + 300_000, magi * 1.2)
        }

        let surchargeB = tiers[i].partBMonthly - standardB
        let surchargeD = tiers[i].partDMonthly
        let annualSurcharge = (surchargeB + surchargeD) * 12

        segments.append(ScenarioIRMAATierSegment(
            tier: i,
            label: i == 0 ? "No Surcharge" : "Tier \(i)",
            rangeStart: threshold,
            rangeEnd: nextThreshold,
            surchargePerPerson: max(0, annualSurcharge),
            isCurrent: currentTier == i
        ))
    }
    return segments
}

@ViewBuilder
private var scenarioIRMAAChart: some View {
    if dataManager.hasActiveScenario && dataManager.medicareMemberCount > 0 {
        let irmaa = dataManager.scenarioIRMAA
        let baselineIrmaa = dataManager.baselineIRMAA
        let afterMAGI = irmaa.magi
        let beforeMAGI = baselineIrmaa.magi
        let segments = scenarioIRMAATierSegments
        let memberCount = dataManager.medicareMemberCount
        let tierColors: [Color] = [
            Color(red: 0.05, green: 0.78, blue: 0.35),
            Color(red: 0.98, green: 0.78, blue: 0.0),
            Color(red: 1.0, green: 0.50, blue: 0.0),
            Color(red: 0.92, green: 0.22, blue: 0.50),
            Color(red: 0.58, green: 0.22, blue: 0.88),
            Color(red: 0.18, green: 0.30, blue: 0.85),
        ]

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.85), .red.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "heart.text.square.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("IRMAA Medicare Surcharge")
                        .font(.headline)
                    Text("Based on \(dataManager.filingStatus.rawValue) MAGI · Affects \(String(dataManager.currentYear + 2)) premiums")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            let chartMax = segments.last?.rangeEnd ?? 1
            let barHeight: CGFloat = 36
            let topPad: CGFloat = 40

            GeometryReader { geo in
                let w = geo.size.width

                // Tier bars
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    let color = tierColors[min(index, tierColors.count - 1)]
                    let x = w * segment.rangeStart / chartMax
                    let segW = w * (segment.rangeEnd - segment.rangeStart) / chartMax
                    let isFirst = index == 0
                    let isLastSeg = index == segments.count - 1

                    if isFirst {
                        UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 0)
                            .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                            .frame(width: segW, height: barHeight)
                            .offset(x: x, y: topPad)
                    } else if isLastSeg {
                        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 5, topTrailingRadius: 5)
                            .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                            .frame(width: segW, height: barHeight)
                            .offset(x: x, y: topPad)
                    } else {
                        Rectangle()
                            .fill(color.opacity(segment.isCurrent ? 1.0 : 0.75))
                            .frame(width: segW, height: barHeight)
                            .offset(x: x, y: topPad)
                    }
                }

                // Before marker (dashed gray)
                let beforeX = CGFloat(beforeMAGI / chartMax) * w
                Path { path in
                    path.move(to: CGPoint(x: beforeX, y: topPad - 5))
                    path.addLine(to: CGPoint(x: beforeX, y: topPad + barHeight + 5))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(.secondary)

                Text("Before \(scenarioChartLabel(beforeMAGI))")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .position(x: min(max(beforeX, 40), w - 40), y: 10)

                // After marker (solid)
                let afterX = CGFloat(afterMAGI / chartMax) * w
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2.5, height: barHeight + 10)
                    .offset(x: afterX - 1.25, y: topPad - 5)

                Text("After \(scenarioChartLabel(afterMAGI))")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .position(x: min(max(afterX, 35), w - 35), y: 26)

            }
            .frame(height: barHeight + topPad + 6)

            // Tier legend below bar
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                    let isLast = index == segments.count - 1
                    let color = tierColors[min(index, tierColors.count - 1)]
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(segment.label)
                                .font(.system(size: 10, weight: segment.isCurrent ? .bold : .medium))
                                .foregroundStyle(color)
                            if segment.tier == 0 {
                                Text("< \(scenarioChartLabel(segments.count > 1 ? segments[1].rangeStart : 0))")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            } else {
                                let rangeText3 = isLast
                                    ? scenarioChartLabel(segment.rangeStart) + "+"
                                    : scenarioChartLabel(segment.rangeStart) + "–" + scenarioChartLabel(segment.rangeEnd)
                                Text(rangeText3)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 4)

            // Callouts
            VStack(alignment: .leading, spacing: 6) {
                if irmaa.tier == 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("No IRMAA surcharge")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Tier \(irmaa.tier): \(irmaa.annualSurchargePerPerson, format: .currency(code: "USD").precision(.fractionLength(0)))/yr per person\(memberCount > 1 ? " (\(dataManager.scenarioIRMAATotalSurcharge, format: .currency(code: "USD").precision(.fractionLength(0))) household)" : "")")
                            .font(.caption)
                    }
                }

                if let distanceToNext = irmaa.distanceToNextTier, distanceToNext > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: distanceToNext < 10_000 ? "exclamationmark.triangle.fill" : "info.circle")
                            .foregroundStyle(distanceToNext < 10_000 ? .orange : .blue)
                            .font(.caption)
                        Text("\(distanceToNext, format: .currency(code: "USD").precision(.fractionLength(0))) below next IRMAA cliff")
                            .font(.caption)
                            .foregroundStyle(distanceToNext < 10_000 ? .orange : .secondary)
                    }
                }

                if dataManager.scenarioPushedToHigherIRMAATier {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("Scenario pushes you to a **higher IRMAA tier**")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if irmaa.tier > 0, let distanceToPrev = irmaa.distanceToPreviousTier {
                    let savingsPerPerson = irmaa.annualSurchargePerPerson - dataManager.scenarioIRMAAPreviousTierAnnualSurcharge
                    let householdSavings = savingsPerPerson * Double(memberCount)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Reduce by \(distanceToPrev + 1, format: .currency(code: "USD").precision(.fractionLength(0))) to save \(householdSavings, format: .currency(code: "USD").precision(.fractionLength(0)))/yr")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.green.opacity(0.3), .red.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
    }
}

// MARK: NIIT Position Chart (Scenario)

@ViewBuilder
private var scenarioNIITChart: some View {
    if dataManager.hasActiveScenario && dataManager.scenarioNetInvestmentIncome > 0 {
        let niit = dataManager.scenarioNIIT
        let baselineNiit = dataManager.baselineNIIT
        let beforeMAGI = baselineNiit.magi
        let afterMAGI = niit.magi
        let threshold = niit.threshold
        let chartMax = max(threshold * 1.5, afterMAGI * 1.2, beforeMAGI * 1.2)
        let barHeight: CGFloat = 36
        let topPad: CGFloat = 40

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.85), .red.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Net Investment Income Tax")
                        .font(.headline)
                    Text("3.8% surtax on investment income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            GeometryReader { geo in
                let w = geo.size.width
                let thresholdX = CGFloat(threshold / chartMax) * w

                // Left zone: No NIIT (green)
                UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 0)
                    .fill(Color(red: 0.05, green: 0.78, blue: 0.35))
                    .frame(width: thresholdX, height: barHeight)
                    .offset(y: topPad)

                // Right zone: 3.8% NIIT (red/orange)
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 5, topTrailingRadius: 5)
                    .fill(Color(red: 0.92, green: 0.22, blue: 0.22).opacity(0.85))
                    .frame(width: w - thresholdX, height: barHeight)
                    .offset(x: thresholdX, y: topPad)

                // Threshold boundary line
                Rectangle()
                    .fill(Color.primary.opacity(0.4))
                    .frame(width: 2, height: barHeight + 10)
                    .offset(x: thresholdX - 1, y: topPad - 5)

                // Before marker (dashed gray)
                let beforeX = CGFloat(beforeMAGI / chartMax) * w
                Path { path in
                    path.move(to: CGPoint(x: beforeX, y: topPad - 5))
                    path.addLine(to: CGPoint(x: beforeX, y: topPad + barHeight + 5))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(.secondary)

                Text("Before \(scenarioChartLabel(beforeMAGI))")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .position(x: min(max(beforeX, 40), w - 40), y: 10)

                // After marker (solid)
                let afterX = CGFloat(afterMAGI / chartMax) * w
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2.5, height: barHeight + 10)
                    .offset(x: afterX - 1.25, y: topPad - 5)

                Text("After \(scenarioChartLabel(afterMAGI))")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .position(x: min(max(afterX, 35), w - 35), y: 26)

                // Zone labels below bar
                let noNiitCenterX = thresholdX / 2
                let niitZoneCenterX = thresholdX + (w - thresholdX) / 2

                VStack(spacing: 1) {
                    Text("No NIIT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(red: 0.05, green: 0.78, blue: 0.35))
                    Text("< \(scenarioChartLabel(threshold))")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .position(x: noNiitCenterX, y: topPad + barHeight + 18)

                VStack(spacing: 1) {
                    Text("3.8% NIIT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(scenarioChartLabel(threshold) + "+")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .position(x: niitZoneCenterX, y: topPad + barHeight + 18)
            }
            .frame(height: topPad + barHeight + 36)

            // Callouts
            VStack(alignment: .leading, spacing: 6) {
                if niit.annualNIITax > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                        Text("NIIT: \(niit.annualNIITax, format: .currency(code: "USD").precision(.fractionLength(0)))/yr")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }

                    if dataManager.scenarioIncreasedNIIT {
                        let niitIncrease = niit.annualNIITax - baselineNiit.annualNIITax
                        if niitIncrease > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("Scenario adds \(niitIncrease, format: .currency(code: "USD").precision(.fractionLength(0))) in NIIT")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        let distance = niit.distanceToThreshold
                        Text("No NIIT — \(max(0, distance), format: .currency(code: "USD").precision(.fractionLength(0))) below threshold")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding()
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.green.opacity(0.3), .red.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
    }
}


}
