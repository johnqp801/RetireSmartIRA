//
//  YearListView.swift
//  RetireSmartIRA

import SwiftUI

struct YearListView: View {
    let path: [YearRecommendation]
    let tradeOffs: [ConstraintHit]
    @Binding var selectedYear: Int?

    @State private var expandedGroups: Set<Int> = []

    private var rows: [YearListRow] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return YearListGrouping.group(
            path: path,
            currentYear: currentYear,
            tierFor: { rec in
                rec.taxBreakdown.irmaa > 0 ? max(1, Int(rec.taxBreakdown.irmaa / 1000)) : 0
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    rowView(for: row)
                    Divider()
                }
            }
        }
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
    }

    @ViewBuilder
    private func rowView(for row: YearListRow) -> some View {
        switch row {
        case .full(let rec, let badge):
            fullRow(rec: rec, badge: badge)
        case .group(let startYear, let endYear, let tier, let taxRange):
            let isExpanded = expandedGroups.contains(startYear)
            groupRow(
                startYear: startYear,
                endYear: endYear,
                tier: tier,
                taxRange: taxRange,
                isExpanded: isExpanded,
                onToggle: {
                    if isExpanded { expandedGroups.remove(startYear) } else { expandedGroups.insert(startYear) }
                }
            )
            if isExpanded {
                ForEach(path.filter { $0.year >= startYear && $0.year <= endYear }, id: \.year) { rec in
                    fullRow(rec: rec, badge: .noChange)
                        .padding(.leading, 12)
                        .background(Color.secondary.opacity(0.04))
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("YEAR").frame(width: 70, alignment: .leading)
            Text("STRATEGY").frame(maxWidth: .infinity, alignment: .leading)
            Text("TAX").frame(width: 80, alignment: .trailing)
            Image(systemName: "chevron.right").opacity(0).frame(width: 16)
        }
        .font(.caption2.weight(.semibold))
        .foregroundColor(.secondary)
        .tracking(0.5)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(PlatformColor.secondarySystemBackground))
    }

    private func fullRow(rec: YearRecommendation, badge: TransitionBadge) -> some View {
        let isSelected = rec.year == selectedYear
        let warning = warningText(for: rec, badge: badge)
        return HStack {
            Text(String(rec.year)).frame(width: 70, alignment: .leading)
                .font(.caption.weight(.semibold))
            HStack(spacing: 4) {
                if let warn = warning {
                    Text(warn.text)
                        .font(.caption)
                        .foregroundColor(warn.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("$\(Int(rec.taxBreakdown.total / 1000))K")
                .frame(width: 80, alignment: .trailing)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedYear = rec.year }
    }

    private func groupRow(
        startYear: Int,
        endYear: Int,
        tier: Int,
        taxRange: ClosedRange<Double>,
        isExpanded: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        let years = endYear - startYear + 1
        let label = tier > 0 ? "stays in T\(tier) (\(years) years)" : "low IRMAA (\(years) years)"
        return HStack {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption2)
                .foregroundColor(.blue)
                .frame(width: 70, alignment: .leading)
                .overlay(
                    Text("\(startYear)–\(endYear % 100)").font(.caption2).foregroundColor(.secondary).padding(.leading, 16),
                    alignment: .leading
                )
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("$\(Int(taxRange.lowerBound / 1000))K–$\(Int(taxRange.upperBound / 1000))K")
                .frame(width: 80, alignment: .trailing)
                .font(.caption2)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(PlatformColor.secondarySystemBackground).opacity(0.5))
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }

    private struct WarnText {
        let text: String
        let color: Color
    }

    private func warningText(for rec: YearRecommendation, badge: TransitionBadge) -> WarnText? {
        switch badge {
        case .currentYear:
            return WarnText(text: "This year", color: .blue)
        case .entersTier(let tier):
            return WarnText(text: "⚠ Enters IRMAA T\(tier)", color: .orange)
        case .dropsToTier(let tier):
            return WarnText(text: "↓ Drops to IRMAA T\(tier)", color: .green)
        case .noChange:
            return nil
        }
    }
}
