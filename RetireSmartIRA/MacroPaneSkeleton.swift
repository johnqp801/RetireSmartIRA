//
//  MacroPaneSkeleton.swift
//  RetireSmartIRA

import SwiftUI

struct MacroPaneSkeleton: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            shimmerBlock(height: 80)         // hero placeholder
            shimmerBlock(height: 40)         // summary placeholder
            shimmerBlock(height: 180)        // waterfall placeholder
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in shimmerBlock(height: 60) }
            }
            shimmerBlock(height: 140)        // year list placeholder
        }
        .padding(14)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func shimmerBlock(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(
                colors: [Color(.tertiarySystemFill), Color(.secondarySystemFill), Color(.tertiarySystemFill)],
                startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
            ))
            .frame(height: height)
    }
}
