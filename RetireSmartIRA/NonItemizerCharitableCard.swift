//
//  NonItemizerCharitableCard.swift
//  RetireSmartIRA
//
//  Surfaces the OBBBA §170(p) cash charitable deduction for filers who take
//  the standard deduction (up to $1,000 single / $2,000 MFJ for cash gifts,
//  2026+). Engine math lives in `DataManager.nonItemizerCharitableDeduction`;
//  this card explains it in user-facing terms. Self-hides whenever the
//  deduction does not apply (itemizing, pre-2026, or no cash gift).
//

import SwiftUI

struct NonItemizerCharitableCard: View {
    @Environment(DataManager.self) var dataManager

    var body: some View {
        let amount = dataManager.nonItemizerCharitableDeduction
        if amount > 0 {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "heart.text.square")
                        .foregroundStyle(Color.UI.brandTeal)
                    Text("Cash Charitable Deduction (no itemizing needed)")
                        .font(.subheadline.weight(.semibold))
                }
                HStack {
                    Text("Applied to your taxable income:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.Semantic.green)
                }
                Text("A 2025 tax-law change lets you deduct up to $1,000 ($2,000 if married filing jointly) of cash gifts to charity on top of the standard deduction. Cash gifts only; donated stock does not qualify.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if dataManager.cashDonationAmount > amount {
                    Text("Your cash gifts exceed the cap, so \(amount, format: .currency(code: "USD").precision(.fractionLength(0))) is deductible this way.")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.Semantic.amber)
                }
            }
            .padding(12)
            .background(Color.UI.surfaceInset)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("nonItemizerCharitableCard")
        }
    }
}
