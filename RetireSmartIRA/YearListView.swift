//
//  YearListView.swift
//  RetireSmartIRA

import SwiftUI

struct YearListView: View {
    let path: [YearRecommendation]
    let tradeOffs: [ConstraintHit]
    @Binding var selectedYear: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(path, id: \.year) { y in
                row(for: y)
                    .background(y.year == selectedYear ? Color.blue.opacity(0.08) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedYear = y.year }
                Divider()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var header: some View {
        HStack {
            Text("YEAR").frame(width: 50, alignment: .leading)
            Text("STRATEGY").frame(maxWidth: .infinity, alignment: .leading)
            Text("TAX").frame(width: 70, alignment: .trailing)
            Image(systemName: "chevron.right").opacity(0).frame(width: 16)
        }
        .font(.caption2.weight(.semibold))
        .foregroundColor(.secondary)
        .tracking(0.5)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func row(for y: YearRecommendation) -> some View {
        HStack {
            Text(String(y.year)).frame(width: 50, alignment: .leading)
                .font(.caption.weight(.semibold))
            HStack(spacing: 4) {
                if let warn = warningText(for: y) {
                    Text(warn).font(.caption2).foregroundColor(.orange)
                } else {
                    Text(strategySummary(for: y)).font(.caption2).foregroundColor(.blue)
                }
                Spacer()
            }
            Text("$\(Int(y.taxBreakdown.total / 1000))K")
                .font(.caption.weight(.semibold))
                .frame(width: 70, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func warningText(for y: YearRecommendation) -> String? {
        guard let hit = tradeOffs.first(where: { $0.year == y.year }) else { return nil }
        switch hit.type {
        case .irmaaTier(let level): return "⚠ IRMAA T\(level)"
        case .acaCliff: return "⚠ ACA cliff"
        case .bracketOverrun: return "⚠ Bracket overrun"
        }
    }

    private func strategySummary(for y: YearRecommendation) -> String {
        var parts: [String] = []
        for action in y.actions {
            switch action {
            case .rothConversion(let amount) where amount > 0:
                parts.append("Roth $\(Int(amount / 1000))K")
            case .traditionalWithdrawal(let amount) where amount > 0:
                parts.append("WD $\(Int(amount / 1000))K")
            case .claimSocialSecurity(let spouse):
                parts.append(spouse == .primary ? "SS (you)" : "SS (sp)")
            default: break
            }
        }
        return parts.isEmpty ? "Hold" : parts.joined(separator: " · ")
    }
}
