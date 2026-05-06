//
//  ActionItemsBanner.swift
//  RetireSmartIRA
//

import SwiftUI

struct ActionItemsBanner: View {
    let year: Int
    let rothAmount: Double
    let qcdAmount: Double
    let stockDonationAmount: Double
    let requiredRMDAmount: Double
    let onViewAll: () -> Void

    var shouldShow: Bool { actionCount > 0 }

    var actionCount: Int {
        var n = 0
        if rothAmount > 0 { n += 1 }
        if qcdAmount > 0 { n += 1 }
        if stockDonationAmount > 0 { n += 1 }
        if requiredRMDAmount > 0 { n += 1 }
        return n
    }

    @ViewBuilder var body: some View {
        if shouldShow {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(actionCount) ACTION\(actionCount == 1 ? "" : "S") DUE BY DEC 31, \(year)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color(red: 0.62, green: 0.39, blue: 0))
                        .tracking(0.4)
                    Text(summary)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button("View all →", action: onViewAll)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(LinearGradient(
                colors: [Color(red: 1, green: 0.96, blue: 0.88), Color(red: 1, green: 0.91, blue: 0.76)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.5), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            EmptyView()
        }
    }

    private var summary: String {
        var parts: [String] = []
        if rothAmount > 0 { parts.append("Roth $\(Int(rothAmount / 1000))K") }
        if qcdAmount > 0 { parts.append("QCD $\(Int(qcdAmount / 1000))K") }
        if stockDonationAmount > 0 { parts.append("Stock donation $\(Int(stockDonationAmount / 1000))K") }
        if requiredRMDAmount > 0 { parts.append("RMD $\(Int(requiredRMDAmount / 1000))K") }
        return parts.joined(separator: " · ")
    }
}
