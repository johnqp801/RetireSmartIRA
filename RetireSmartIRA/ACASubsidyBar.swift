//
//  ACASubsidyBar.swift
//  RetireSmartIRA
//
//  IRMAA-parity visualization for ACA marketplace subsidy.
//  4 colored subsidy bands + cliff zone, MAGI position markers,
//  context-aware readout below.
//
//  Per Ron Park beta feedback (1.8.1 incremental enhancement,
//  smoke-test enhancement per John's 2026-05-10 review).
//

import SwiftUI

// MARK: - Readout state

enum ACASubsidyBarReadoutState: Equatable {
    case wellUnder       // > $20K headroom
    case approaching     // > $5K and ≤ $20K
    case withinBuffer    // 0 to $5K
    case justOver        // 0 to -$20K (recoverable)
    case farOver         // < -$20K (no recovery)
}

// MARK: - Band classification

enum ACASubsidyBand: Equatable {
    case fullSubsidy     // ≤ 200% FPL
    case generous        // 200–300% FPL
    case moderate        // 300–350% FPL
    case thin            // 350–400% FPL
    case cliff           // > 400% FPL

    var label: String {
        switch self {
        case .fullSubsidy: return "Full subsidy"
        case .generous:    return "Generous"
        case .moderate:    return "Moderate"
        case .thin:        return "Thin"
        case .cliff:       return "🚫 Cliff"
        }
    }

    var fplRangeLabel: String {
        switch self {
        case .fullSubsidy: return "≤200% FPL"
        case .generous:    return "200–300%"
        case .moderate:    return "300–350%"
        case .thin:        return "350–400%"
        case .cliff:       return ">400% FPL"
        }
    }

    var color: Color {
        switch self {
        case .fullSubsidy: return .green
        case .generous:    return Color(red: 0.55, green: 0.75, blue: 0.25) // green-yellow
        case .moderate:    return .yellow
        case .thin:        return .orange
        case .cliff:       return .red
        }
    }

    /// Visual width allocation (sums to 1.0). Not FPL-proportional —
    /// compresses the unused "Strongest" band and widens the cliff zone for visibility.
    var widthFraction: CGFloat {
        switch self {
        case .fullSubsidy: return 0.15
        case .generous:    return 0.25
        case .moderate:    return 0.14
        case .thin:        return 0.14
        case .cliff:       return 0.32
        }
    }

    /// Upper bound (exclusive) for FPL%; cliff has no upper bound.
    var fplUpper: Double {
        switch self {
        case .fullSubsidy: return 200
        case .generous:    return 300
        case .moderate:    return 350
        case .thin:        return 400
        case .cliff:       return .infinity
        }
    }

    static let allOrdered: [ACASubsidyBand] = [.fullSubsidy, .generous, .moderate, .thin, .cliff]
}

// MARK: - ACASubsidyBar view

struct ACASubsidyBar: View {
    let acaResult: ACASubsidyResult
    let beforeMAGI: Double?

    // MARK: - Pure logic (exposed for testing)

    static func readoutState(headroom: Double) -> ACASubsidyBarReadoutState {
        if headroom > 20_000 { return .wellUnder }
        if headroom > 5_000  { return .approaching }
        if headroom >= 0     { return .withinBuffer }
        if headroom >= -20_000 { return .justOver }
        return .farOver
    }

    static func band(forFPLPercent fplPercent: Double) -> ACASubsidyBand {
        if fplPercent <= 200 { return .fullSubsidy }
        if fplPercent <= 300 { return .generous }
        if fplPercent <= 350 { return .moderate }
        if fplPercent <= 400 { return .thin }
        return .cliff
    }

    // MARK: - Computed

    private var cliffThreshold: Double {
        acaResult.acaMAGI + (acaResult.dollarsToCliff ?? 0)
    }

    private var headroom: Double {
        cliffThreshold - acaResult.acaMAGI
    }

    private var state: ACASubsidyBarReadoutState {
        Self.readoutState(headroom: headroom)
    }

    /// The full "cliff" point in the bar lines up with the end of the Thin band
    /// (i.e., the start of the cliff band). 400% FPL maps to fraction `cliffFraction`.
    private var cliffFraction: CGFloat {
        ACASubsidyBand.fullSubsidy.widthFraction
            + ACASubsidyBand.generous.widthFraction
            + ACASubsidyBand.moderate.widthFraction
            + ACASubsidyBand.thin.widthFraction
    }

    /// Bar max in MAGI dollars. We map cliffThreshold → cliffFraction of the bar.
    private var barMaxMAGI: Double {
        // cliffThreshold corresponds to cliffFraction; whole bar is cliffThreshold / cliffFraction
        guard cliffFraction > 0, cliffThreshold > 0 else { return max(acaResult.acaMAGI * 1.5, 1) }
        return cliffThreshold / Double(cliffFraction)
    }

    /// Returns x-position fraction (0…1) for a MAGI value within the bar.
    private func position(forMAGI magi: Double) -> CGFloat {
        guard barMaxMAGI > 0 else { return 0 }
        return CGFloat(max(0, min(1, magi / barMaxMAGI)))
    }

    private var currentIsClampedRight: Bool {
        acaResult.acaMAGI > barMaxMAGI
    }

    private var beforeIsDifferent: Bool {
        guard let b = beforeMAGI else { return false }
        return abs(b - acaResult.acaMAGI) > 100
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            barWithMarkers
            bandLegend
            readoutSection
            tipsDisclosure
        }
    }

    // MARK: - Tips disclosure

    @ViewBuilder
    private var tipsDisclosure: some View {
        DisclosureGroup("About ACA subsidies") {
            VStack(alignment: .leading, spacing: 8) {
                TipRow(
                    icon: "exclamationmark.circle",
                    iconColor: .orange,
                    title: "Tax-exempt interest counts in MAGI",
                    bodyText: "Municipal bond interest is federally tax-free but IS counted toward the ACA cliff threshold. This is the most common cause of unexpected cliff crossings."
                )

                TipRow(
                    icon: "arrow.triangle.swap",
                    iconColor: .blue,
                    title: "Roth conversions add to MAGI; Roth distributions don't",
                    bodyText: "Each year's Roth conversion increases that year's MAGI. Once converted, future Roth withdrawals don't count toward ACA MAGI at all."
                )

                TipRow(
                    icon: "map",
                    iconColor: .purple,
                    title: "State-extended subsidies vary",
                    bodyText: "Some states (NY, CA, MA, VT, and others) offer additional state-funded subsidies that continue past the 400% FPL cliff. This app shows federal subsidies only — consult your state marketplace directly for state-specific assistance."
                )
            }
            .padding(.vertical, 4)
        }
        .font(.caption.weight(.semibold))
    }

    // MARK: - Bar + markers

    private let barHeight: CGFloat = 28
    private let markerOverhang: CGFloat = 8
    private let labelHeight: CGFloat = 26
    private var totalBarAreaHeight: CGFloat { labelHeight + barHeight + markerOverhang }

    @ViewBuilder
    private var barWithMarkers: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let bands = ACASubsidyBand.allOrdered

            // Colored band rectangles
            ForEach(Array(bands.enumerated()), id: \.offset) { idx, band in
                let startFraction = bands.prefix(idx).map(\.widthFraction).reduce(0, +)
                let bandW = w * band.widthFraction
                let isFirst = idx == 0
                let isLast = idx == bands.count - 1
                bandRect(band: band, isFirst: isFirst, isLast: isLast)
                    .frame(width: bandW, height: barHeight)
                    .offset(x: w * startFraction, y: labelHeight)
            }

            // Before MAGI marker (dashed gray) — drawn first so current overlays it
            if beforeIsDifferent, let b = beforeMAGI {
                let bx = w * position(forMAGI: b)
                Rectangle()
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: 1.5, height: barHeight + markerOverhang)
                    .overlay(
                        // Simulate dashed via mask of small segments
                        VStack(spacing: 2) {
                            ForEach(0..<7, id: \.self) { _ in
                                Rectangle().fill(Color.gray.opacity(0.85)).frame(height: 3)
                            }
                        }
                        .frame(width: 1.5)
                    )
                    .offset(x: bx - 0.75, y: labelHeight - 4)

                VStack(spacing: 1) {
                    Text("Before")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(formatMagi(b))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .position(x: max(20, min(w - 20, bx)), y: 11)
            }

            // Current MAGI marker (solid)
            let cx = w * position(forMAGI: acaResult.acaMAGI)
            Rectangle()
                .fill(.primary)
                .frame(width: 2.5, height: barHeight + markerOverhang)
                .offset(x: cx - 1.25, y: labelHeight - 4)

            VStack(spacing: 1) {
                Text(beforeIsDifferent ? "After" : "Your MAGI")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(formatMagi(acaResult.acaMAGI))
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .position(x: max(24, min(w - 24, cx)), y: 11)

            // Off-bar overflow indicator
            if currentIsClampedRight {
                let overBy = acaResult.acaMAGI - barMaxMAGI
                Text("→ \(formatMagi(overBy)) over")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                    .position(x: w - 38, y: labelHeight + barHeight + 14)
            }
        }
        .frame(height: totalBarAreaHeight + 4)
    }

    @ViewBuilder
    private func bandRect(band: ACASubsidyBand, isFirst: Bool, isLast: Bool) -> some View {
        let currentBand = Self.band(forFPLPercent: acaResult.fplPercent)
        let opacity: Double = (band == currentBand) ? 1.0 : 0.6
        if isFirst {
            UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(band.color.opacity(opacity))
        } else if isLast {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 5, topTrailingRadius: 5)
                .fill(band.color.opacity(opacity))
        } else {
            Rectangle()
                .fill(band.color.opacity(opacity))
        }
    }

    // MARK: - Band legend (below bar)

    @ViewBuilder
    private var bandLegend: some View {
        HStack(spacing: 0) {
            ForEach(Array(ACASubsidyBand.allOrdered.enumerated()), id: \.offset) { _, band in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(band.color)
                            .frame(width: 6, height: 6)
                        Text(band.label)
                            .font(.system(size: 9, weight: band == Self.band(forFPLPercent: acaResult.fplPercent) ? .bold : .medium))
                            .foregroundStyle(band.color)
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(band.fplRangeLabel)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: nil, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Readout

    @ViewBuilder
    private var readoutSection: some View {
        switch state {
        case .wellUnder:
            readoutRow(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                primary: "Headroom to cliff: \(formatDollars(headroom))",
                primaryColor: .green,
                secondary: nil,
                tip: nil
            )

        case .approaching:
            readoutRow(
                icon: "info.circle",
                iconColor: .orange,
                primary: "Headroom: \(formatDollars(headroom))",
                primaryColor: .orange,
                secondary: "Crossing would cost ~\(formatDollars(acaResult.annualPremiumAssistance))/yr in lost subsidy",
                tip: nil
            )

        case .withinBuffer:
            readoutRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: .red,
                primary: "\(formatDollars(headroom)) to cliff — careful",
                primaryColor: .red,
                secondary: "Crossing costs ~\(formatDollars(acaResult.annualPremiumAssistance))/yr in lost subsidy",
                tip: nil
            )

        case .justOver:
            let recoverNeeded = -headroom
            readoutRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: .red,
                primary: "Over by \(formatDollars(-headroom))",
                primaryColor: .red,
                secondary: "Lost subsidy: \(formatDollars(estimatedLostSubsidy()))/yr",
                tip: "Reduce MAGI by \(formatDollars(recoverNeeded)) to recover subsidy"
            )

        case .farOver:
            readoutRow(
                icon: "xmark.octagon.fill",
                iconColor: .red,
                primary: "Over by \(formatDollars(-headroom))",
                primaryColor: .red,
                secondary: "No subsidy available at this income level",
                tip: nil
            )
        }
    }

    /// For just-over state, estimate lost subsidy. The engine's annualPremiumAssistance is
    /// zero once over the cliff — we approximate the lost subsidy by computing what the
    /// benchmark - expected contribution would have been at the cliff.
    private func estimatedLostSubsidy() -> Double {
        // If engine still has a positive value (cliff not crossed in engine), use it.
        if acaResult.annualPremiumAssistance > 0 { return acaResult.annualPremiumAssistance }
        // Otherwise approximate: benchmark - 8.5% * cliffThreshold
        let expectedAtCliff = cliffThreshold * 0.085
        return max(0, acaResult.benchmarkSilverPlanAnnual - expectedAtCliff)
    }

    @ViewBuilder
    private func readoutRow(
        icon: String,
        iconColor: Color,
        primary: String,
        primaryColor: Color,
        secondary: String?,
        tip: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.caption)
                Text(primary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryColor)
                    .monospacedDigit()
            }
            if let secondary {
                Text(secondary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let tip {
                HStack(spacing: 4) {
                    Text("💡")
                        .font(.caption2)
                    Text(tip)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.UI.brandTeal)
                }
            }
        }
    }

    // MARK: - Formatters

    private func formatMagi(_ value: Double) -> String {
        let abs = Swift.abs(value)
        if abs >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if abs >= 1_000 { return String(format: "$%.0fK", value / 1_000) }
        return String(format: "$%.0f", value)
    }

    private func formatDollars(_ value: Double) -> String {
        formatMagi(value)
    }
}

// MARK: - TipRow

private struct TipRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(iconColor)
                .frame(width: 16, alignment: .top)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                Text(bodyText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
