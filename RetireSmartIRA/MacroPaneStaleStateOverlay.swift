//
//  MacroPaneStaleStateOverlay.swift
//  RetireSmartIRA

import SwiftUI

struct StaleStateOverlay: ViewModifier {
    let isComputing: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isComputing ? 0.7 : 1.0)
            .overlay(alignment: .topTrailing) {
                if isComputing {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Recomputing…").font(.caption2.weight(.medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground))
                    .cornerRadius(6)
                    .shadow(radius: 2)
                    .padding(8)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isComputing)
    }
}

extension View {
    func macroStaleStateOverlay(isComputing: Bool) -> some View {
        modifier(StaleStateOverlay(isComputing: isComputing))
    }
}
