//
//  HeirTaxComparisonCard.swift
//  RetireSmartIRA
//
//  Phase 2 L3: Heir-Bracket Comparison Card.
//
//  Frames the family-wide tax tradeoff: pay tax now at the user's marginal rate
//  vs heir pays it later at their marginal rate under SECURE 10-year drain.
//
//  Per Phase 2 plan Decisions:
//  - A: Hidden entirely when heir is a spouse (gated upstream by
//       `dataManager.shouldShowHeirComparison`).
//  - B: Hybrid display at $10K conversion threshold — live amount when
//       `scenarioTotalRothConversion >= $10K`, illustrative $100K otherwise.
//

import SwiftUI

struct HeirTaxComparisonCard: View {
    @Environment(DataManager.self) var dataManager

    var body: some View {
        let c = dataManager.convertNowVsHeirComparison
        let useLive = dataManager.heirComparisonUsesLiveAmount
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(Color.UI.brandTeal)
                Text("Convert Now vs. Heirs Pay Later")
                    .font(.headline)
            }
            // Hybrid headline per Decision B
            if useLive {
                Text("Converting $\(Int(c.conversionAmount).formatted()) this year saves your heirs ~$\(Int(abs(c.netFamilyBenefit)).formatted()) (vs. SECURE 10-year drain at their bracket).")
                    .font(.callout)
                    .foregroundStyle(.primary)
            } else {
                let per100k = TaxCalculationEngine.convertNowVsHeirComparison(
                    conversionAmount: 100_000,
                    userMarginalRate: c.userMarginalRate,
                    heirMarginalRate: c.heirMarginalRate
                )
                Text("Per $100K converted, your heirs save ~$\(Int(abs(per100k.netFamilyBenefit)).formatted()) (vs. SECURE 10-year drain at their bracket).")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 6) {
                row(
                    label: "Convert $\(Int(c.conversionAmount).formatted()) now at your \(Int(c.userMarginalRate * 100))% bracket",
                    value: c.userTaxIfConvertedNow,
                    color: Color.UI.brandTeal
                )
                row(
                    label: "Same amount inherited under SECURE 10-year drain at heir's \(Int(c.heirMarginalRate * 100))% bracket",
                    value: c.heirTaxIfInheritedLater,
                    color: Color.Semantic.amber
                )
                Divider().padding(.vertical, 2)
                row(
                    label: c.netFamilyBenefit >= 0 ? "Net family benefit of converting now" : "Net family cost of converting now",
                    value: abs(c.netFamilyBenefit),
                    color: c.netFamilyBenefit >= 0 ? Color.Semantic.green : Color.Semantic.red,
                    bold: true
                )
            }
            Text("Heir bracket reflects your Heir Tax Rate setting in the assumptions bar.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.UI.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(label: String, value: Double, color: Color, bold: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(bold ? .callout.weight(.bold) : .callout)
                .foregroundStyle(color)
        }
    }
}
