//
//  LockedMacroSlimBanner.swift
//  RetireSmartIRA

import SwiftUI

struct LockedMacroSlimBanner: View {
    let onSetUp: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.blue)
            Text("Multi-year strategy locked").font(.caption.weight(.semibold))
            Spacer()
            Button("Set up", action: onSetUp).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.2), lineWidth: 1))
        .cornerRadius(6)
        .padding(.horizontal, 14)
    }
}
