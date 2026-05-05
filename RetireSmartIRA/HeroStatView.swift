//
//  HeroStatView.swift
//  RetireSmartIRA
//

import SwiftUI

struct HeroStatView: View {
    let recommendedLifetimeTax: Double
    let heirTaxRatePercent: Int
    let offPlanState: OffPlanIndicator.PlanState
    let useNeutralOffPlanFraming: Bool
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LIFETIME TAX")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                Spacer()
                OffPlanIndicator(
                    state: offPlanState,
                    useNeutralFraming: useNeutralOffPlanFraming,
                    onReset: onReset
                )
            }

            Text(formatDollars(recommendedLifetimeTax))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.blue)

            Text(objectiveCaption)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(LinearGradient(
            colors: [.blue.opacity(0.05), .blue.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
        .cornerRadius(10)
    }

    private var objectiveCaption: String {
        "Seeks to minimize lifetime tax including a \(heirTaxRatePercent)% tax on assets left to heirs. Accepts IRMAA or ACA cliffs only when they save more than they cost."
    }

    private func formatDollars(_ value: Double) -> String {
        let k = Int(value.rounded() / 1000)
        return "$\(k)K"
    }
}
