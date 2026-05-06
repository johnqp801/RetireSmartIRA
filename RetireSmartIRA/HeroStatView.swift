//
//  HeroStatView.swift
//  RetireSmartIRA
//

import SwiftUI

struct HeroStatView: View {
    let baselineLifetimeTax: Double
    let yourPlanLifetimeTax: Double
    let heirTaxRatePercent: Int
    let offPlanState: OffPlanIndicator.PlanState
    let useNeutralOffPlanFraming: Bool
    let onReset: () -> Void

    private var savings: Double { baselineLifetimeTax - yourPlanLifetimeTax }
    private var isAlreadyOptimal: Bool { abs(savings) < 1_000 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if isAlreadyOptimal {
                alreadyOptimalContent
            } else {
                savingsContent
            }
            ledger
            footnote
            objectiveCaption
        }
        .padding(14)
        .background(LinearGradient(
            colors: [.blue.opacity(0.05), .blue.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Header (label + off-plan badge)

    private var header: some View {
        HStack {
            Text(isAlreadyOptimal ? "YOUR PLAN IS ALREADY OPTIMAL" : "YOUR ENGINE-OPTIMIZED PLAN SAVES")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.green)
                .tracking(0.6)
            Spacer()
            OffPlanIndicator(
                state: offPlanState,
                useNeutralFraming: useNeutralOffPlanFraming,
                onReset: onReset
            )
        }
    }

    // MARK: - Standard "Saves $X" content

    private var savingsContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatDollars(savings))
                .font(.system(size: 46, weight: .heavy))
                .foregroundColor(.green)
                .kerning(-1)
            Text("in lifetime tax over 30 years")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - "Already Optimal" structural variant

    private var alreadyOptimalContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46, weight: .heavy))
                .foregroundColor(.green)
            Text("no Roth conversions or QCDs needed at current assumptions")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Ledger card

    private var ledger: some View {
        VStack(spacing: 0) {
            ledgerRow(label: "Baseline Path",
                      value: baselineLifetimeTax,
                      labelColor: .secondary,
                      valueColor: .secondary)
            ledgerRow(label: "Your Plan",
                      value: yourPlanLifetimeTax,
                      labelColor: .blue,
                      valueColor: .blue,
                      bold: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func ledgerRow(label: String, value: Double, labelColor: Color, valueColor: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(bold ? .semibold : .regular))
                .foregroundColor(labelColor)
            Spacer()
            Text(formatDollars(value))
                .font(.subheadline.weight(bold ? .bold : .semibold))
                .foregroundColor(valueColor)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Footnote

    private var footnote: some View {
        Text("**Baseline Path:** no Roth conversions, no QCDs. RMDs and SS still claimed at your planned ages.")
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }

    // MARK: - Objective caption

    private var objectiveCaption: some View {
        Text("Seeks to minimize lifetime tax including a \(heirTaxRatePercent)% tax on assets left to heirs. Accepts IRMAA or ACA cliffs only when they save more than they cost.")
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }

    // MARK: - Helpers

    private func formatDollars(_ value: Double) -> String {
        let absK = Int((abs(value) / 1000).rounded())
        let sign = value < 0 ? "−" : ""
        if absK >= 1_000 {
            let m = (abs(value) / 1_000_000 * 10).rounded() / 10
            return String(format: "\(sign)$%.1fM", m)
        }
        return "\(sign)$\(absK)K"
    }
}
