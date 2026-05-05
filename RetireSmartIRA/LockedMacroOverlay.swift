//
//  LockedMacroOverlay.swift
//  RetireSmartIRA

import SwiftUI

struct LockedMacroOverlay: View {
    let onSetUp: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            Text("Unlock your 30-year strategy")
                .font(.title3.weight(.semibold))
            Text("RetireSmart IRA now projects your tax plan decades into the future. Add a few details to see your lifetime savings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Set up multi-year plan", action: onSetUp)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            Button("Not now", action: onDismiss)
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(28)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(radius: 8)
        .padding()
    }
}
