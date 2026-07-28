//
//  MultiYearTaxFundingCard.swift
//  RetireSmartIRA
//
//  V2.3: picks how the multi-year plan funds its tax bill.
//
//  Every option states its FULL behavior including the shortfall cascade. A friendly
//  label that hides the cascade is the main usability risk in this feature: a user who
//  reads "Withhold from conversion" could reasonably assume withholding is the only
//  modeled payment and that any balance is handled outside the plan. The per-option
//  copy lives on `RothTaxFundingMode.fundingSubtitle` so this view and the domain
//  layer cannot drift.
//

import SwiftUI

struct MultiYearTaxFundingCard: View {
    @Binding var assumptions: MultiYearAssumptions
    /// Youngest household member's age, for the under-59.5 disclosure.
    let youngestAge: Int

    /// The elected rate is FEDERAL ONLY. Everything else in the bill still funds through
    /// the shortfall cascade, so the user must not read the elected percentage as covering
    /// their whole liability.
    static let withholdingScopeNote =
        "Withholding is federal only. State income tax, Medicare surcharges (IRMAA), net investment income tax, and any repayment of ACA premium tax credits are not covered by it and are funded from your accounts."

    private var mode: RothTaxFundingMode { assumptions.rothTaxFundingMode }

    /// Both IRA-touching modes spend IRA dollars on tax, which is the tradeoff the
    /// disclosure exists to name. Hoisted so the gate is pinned by a test: narrowing it
    /// to a single mode would otherwise silently drop the disclosure from the other.
    var showsIRAFundingDisclosure: Bool {
        mode.canTouchIRADollarsForTax
    }

    /// The 10% additional tax under section 72(t) is not modeled, so the warning has to
    /// appear whenever the selected mode could expose the household to it. Age 60 is the
    /// gate (matching the single-year `RothConversionWithholdingCard`), since ages are
    /// whole numbers and 59 could be either side of 59.5.
    var showsEarlyDistributionWarning: Bool {
        youngestAge < 60 && mode.canTouchIRADollarsForTax
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Pay conversion tax by", selection: $assumptions.rothTaxFundingMode) {
                ForEach(RothTaxFundingMode.allCases, id: \.self) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .accessibilityLabel("Pay conversion tax by")

            Text(mode.fundingSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if mode.usesCustodialWithholding {
                HStack {
                    Text("Federal withholding rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Federal withholding rate", selection: $assumptions.federalWithholdingRate) {
                        ForEach(FederalWithholdingRates.options, id: \.rate) { opt in
                            Text(opt.label).tag(opt.rate)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Federal withholding rate")
                }
                Text(Self.withholdingScopeNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsIRAFundingDisclosure {
                disclosure(V2Disclosures.edSlottIRAFunding)
            }
            if showsEarlyDistributionWarning {
                disclosure(V2Disclosures.earlyDistributionNotModeled)
            }
        }
    }

    private func disclosure(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
