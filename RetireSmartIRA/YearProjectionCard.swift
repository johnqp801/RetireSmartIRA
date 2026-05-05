//
//  YearProjectionCard.swift
//  RetireSmartIRA
//
//  Read-only projection for Year 2+. Sections in spec order:
//  YoY delta + cause → AGI/tax breakdown → recommended actions →
//  bracket headroom → acceptance rationale (conditional) → balances.
//

import SwiftUI

struct YearProjectionCard: View {
    let recommendation: YearRecommendation
    let priorRecommendation: YearRecommendation?
    let constraintHit: ConstraintHit?
    let priorBalances: AccountSnapshot?

    private var deltaResult: YearOverYearDeltaSynthesizer.Result {
        YearOverYearDeltaSynthesizer.synthesize(prior: priorRecommendation, current: recommendation)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                yoYDeltaSection
                taxBreakdownSection
                actionsSection
                bracketHeadroomSection
                if let hit = constraintHit {
                    acceptanceRationaleSection(hit: hit)
                }
                balancesSection
            }
            .padding(14)
        }
        .background(Color(PlatformColor.systemBackground))
    }

    private var header: some View {
        HStack {
            Text(String(recommendation.year))
                .font(.title2.weight(.bold))
            Spacer()
            Text("Projection · Read-only")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(PlatformColor.secondarySystemBackground))
                .cornerRadius(4)
        }
    }

    @ViewBuilder
    private var yoYDeltaSection: some View {
        if let delta = deltaResult.taxDelta, delta != 0 {
            HStack(spacing: 6) {
                Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                    .foregroundColor(delta > 0 ? .orange : .green)
                Text("\(delta > 0 ? "+" : "")$\(Int(delta / 1000))K vs \(recommendation.year - 1)")
                    .font(.caption.weight(.semibold))
                if let cause = deltaResult.causeSentence {
                    Text("— \(cause)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color(PlatformColor.secondarySystemBackground))
            .cornerRadius(6)
        }
    }

    private var taxBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Tax breakdown")
            taxRow("Federal", recommendation.taxBreakdown.federal)
            taxRow("State", recommendation.taxBreakdown.state)
            if recommendation.taxBreakdown.irmaa > 0 {
                taxRow("IRMAA", recommendation.taxBreakdown.irmaa, color: .orange)
            }
            if recommendation.taxBreakdown.acaPremiumImpact > 0 {
                taxRow("ACA", recommendation.taxBreakdown.acaPremiumImpact, color: .red)
            }
            Divider()
            taxRow("Total", recommendation.taxBreakdown.total, bold: true)
        }
    }

    private func taxRow(_ label: String, _ amount: Double, color: Color = .primary, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .caption.weight(.semibold) : .caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("$\(Int(amount).formatted())")
                .font(bold ? .caption.weight(.bold) : .caption)
                .foregroundColor(color)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Recommended actions")
            let descs = actionDescriptions
            if descs.isEmpty {
                Text("• Hold").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(descs, id: \.self) { desc in
                    Text("• \(desc)").font(.caption)
                }
            }
        }
    }

    private var actionDescriptions: [String] {
        recommendation.actions.compactMap { action in
            switch action {
            case .rothConversion(let a) where a > 0:
                return "Roth conversion $\(Int(a / 1000))K"
            case .traditionalWithdrawal(let a) where a > 0:
                return "Traditional withdrawal $\(Int(a / 1000))K"
            case .rothWithdrawal(let a) where a > 0:
                return "Roth withdrawal $\(Int(a / 1000))K"
            case .taxableWithdrawal(let a) where a > 0:
                return "Taxable withdrawal $\(Int(a / 1000))K"
            case .claimSocialSecurity(let s):
                return "Claim SS (\(s == .primary ? "you" : "spouse"))"
            default:
                return nil
            }
        }
    }

    private var bracketHeadroomSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Bracket headroom")
            BracketHeadroomGauge(irmaa: recommendation.taxBreakdown.irmaa)
        }
    }

    private func acceptanceRationaleSection(hit: ConstraintHit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Acceptance rationale")
            Text(hit.acceptanceRationale)
                .font(.caption)
                .padding(8)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
        }
    }

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("End-of-year balances")
            balanceRow("Trad", recommendation.endOfYearBalances.traditional, prior: priorBalances?.traditional)
            balanceRow("Roth", recommendation.endOfYearBalances.roth, prior: priorBalances?.roth)
            balanceRow("Taxable", recommendation.endOfYearBalances.taxable, prior: priorBalances?.taxable)
            balanceRow("HSA", recommendation.endOfYearBalances.hsa, prior: priorBalances?.hsa)
        }
    }

    private func balanceRow(_ label: String, _ amount: Double, prior: Double?) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary).frame(width: 70, alignment: .leading)
            Text("$\(Int(amount / 1000))K").font(.caption.weight(.semibold))
            if let prior, prior != amount {
                Image(systemName: amount > prior ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                    .foregroundColor(amount > prior ? .green : .orange)
            }
            Spacer()
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondary)
            .tracking(0.5)
    }
}

private struct BracketHeadroomGauge: View {
    let irmaa: Double

    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.green, .orange, .red], startPoint: .leading, endPoint: .trailing))
            .frame(height: 16)
            .cornerRadius(2)
            .overlay(
                Text(irmaa > 0 ? "IRMAA crossed (accepted)" : "Within safe brackets")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .shadow(radius: 1)
            )
    }
}
