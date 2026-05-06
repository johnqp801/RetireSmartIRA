//
//  TaxPositionPanel.swift
//  RetireSmartIRA
//

import SwiftUI

struct TaxPositionPanel: View {
    let federalRate: Double
    let federalIncome: Double
    let federalBrackets: [(rate: Double, threshold: Double)]
    let federalRoomToNext: Double
    let irmaaTier: Int
    let irmaaCushionToNextK: Int?
    let stateRatePercent: Double
    let niitAnnualDollars: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR TAX POSITION THIS YEAR")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)

            CompactBracketGauge(
                currentRate: federalRate,
                currentIncome: federalIncome,
                brackets: federalBrackets,
                roomToNextBracket: federalRoomToNext
            )

            CompactIRMAAGauge(
                currentTier: irmaaTier,
                cushionToNextTierK: irmaaCushionToNextK
            )

            Divider()

            HStack {
                Text("State (CA): ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(stateRatePercent, specifier: "%.1f")%")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("NIIT: ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(niitDescription)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(niitAnnualDollars > 0 ? .orange : .primary)
            }
        }
        .padding(12)
        .background(Color(PlatformColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
    }

    private var niitDescription: String {
        niitAnnualDollars <= 0 ? "—" : "$\(Int(niitAnnualDollars / 1000))K/yr"
    }
}
