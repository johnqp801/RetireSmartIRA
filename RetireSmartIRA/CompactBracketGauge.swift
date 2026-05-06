//
//  CompactBracketGauge.swift
//  RetireSmartIRA
//

import SwiftUI

struct CompactBracketGauge: View {
    let currentRate: Double
    let currentIncome: Double
    let brackets: [(rate: Double, threshold: Double)]
    let roomToNextBracket: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Federal bracket")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(currentRate * 100))% · \(roomDescription)")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.blue)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<brackets.count, id: \.self) { i in
                            Rectangle()
                                .fill(color(for: brackets[i].rate))
                        }
                    }
                    if let markerX = markerPosition(in: geo.size.width) {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 2, height: geo.size.height + 4)
                            .offset(x: markerX, y: -2)
                    }
                }
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 12)

            HStack(spacing: 0) {
                ForEach(brackets, id: \.threshold) { b in
                    Text("\(Int(b.rate * 100))%")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var roomDescription: String {
        if roomToNextBracket == .infinity || roomToNextBracket > 10_000_000 {
            return "top bracket"
        }
        return "$\(Int(roomToNextBracket / 1000))K room"
    }

    private func color(for rate: Double) -> Color {
        switch rate {
        case ..<0.13: return Color(red: 0.64, green: 0.85, blue: 0.64)
        case ..<0.23: return Color(red: 0.74, green: 0.88, blue: 0.74)
        case ..<0.25: return Color(red: 0.86, green: 0.91, blue: 0.86)
        case ..<0.33: return Color(red: 0.96, green: 0.84, blue: 0.53)
        case ..<0.36: return Color(red: 0.94, green: 0.55, blue: 0.30)
        default:      return Color(red: 0.84, green: 0.36, blue: 0.36)
        }
    }

    private func markerPosition(in totalWidth: CGFloat) -> CGFloat? {
        guard !brackets.isEmpty, currentIncome >= 0 else { return nil }
        let topThreshold = brackets.last!.threshold + 100_000
        let clamped = min(currentIncome, topThreshold)
        return totalWidth * CGFloat(clamped / topThreshold)
    }
}
