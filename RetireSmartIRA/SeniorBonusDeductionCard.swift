//
//  SeniorBonusDeductionCard.swift
//  RetireSmartIRA
//
//  Prominent surfacing of the OBBBA senior bonus deduction for users age
//  65+. Engine math lives in `DataManager.seniorBonusDeductionAmount`
//  (which mirrors the bonus embedded inside `standardDeductionAmount`).
//  This card explains it in user-facing terms.
//  Spec H4 — 1.8.2 Phase 3.
//

import SwiftUI

struct SeniorBonusDeductionCard: View {
    @Environment(DataManager.self) var dataManager

    private var isApplicable: Bool {
        let primary65 = dataManager.currentAge >= 65
        let spouse65 = dataManager.filingStatus == .marriedFilingJointly
            && dataManager.enableSpouse
            && dataManager.spouseCurrentAge >= 65
        return primary65 || spouse65
    }

    var body: some View {
        if isApplicable {
            let amount = dataManager.seniorBonusDeductionAmount
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("OBBBA Senior Bonus (age 65+)")
                        .font(.subheadline.weight(.semibold))
                }
                HStack {
                    Text("Applied to your deduction:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(amount > 0 ? Color.Semantic.green : Color.UI.textSecondary)
                }
                Text("Up to +$6,000 per qualifying person 65+ (+$12,000 MFJ if both qualify). Phases out above $75K / $150K MAGI at 6%. Effective 2025–2028.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if amount == 0 {
                    Text("Fully phased out at your current MAGI.")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.Semantic.amber)
                }
            }
            .padding(12)
            .background(Color.UI.surfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("seniorBonusDeductionCard")
        }
    }
}
