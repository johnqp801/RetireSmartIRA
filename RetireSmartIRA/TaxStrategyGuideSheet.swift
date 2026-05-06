//
//  TaxStrategyGuideSheet.swift
//  RetireSmartIRA
//

import SwiftUI

struct TaxStrategyGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section(
                        title: "Roth Conversions",
                        body: "Move funds from a Traditional IRA to a Roth IRA. You'll pay tax now, but future growth and withdrawals are tax-free. Useful when current bracket is lower than expected future bracket, or to reduce future RMDs."
                    )
                    section(
                        title: "Qualified Charitable Distributions (QCDs)",
                        body: "If you're 70½ or older, you can donate up to $108K/yr (2026 limit) directly from an IRA to charity. The donation counts toward your RMD but is excluded from taxable income."
                    )
                    section(
                        title: "IRMAA (Medicare Surcharges)",
                        body: "Modified AGI two years prior determines your Medicare premiums. The thresholds are cliffs — $1 over a tier triggers thousands in extra premiums. Worth managing carefully when income is near a boundary."
                    )
                    section(
                        title: "Net Investment Income Tax (NIIT)",
                        body: "A 3.8% surtax on net investment income (interest, dividends, capital gains) when modified AGI exceeds $250K (MFJ) or $200K (Single). Roth conversions add to AGI but the conversion itself is not investment income."
                    )
                }
                .padding(16)
            }
            .navigationTitle("Tax Strategy Guide")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.callout).foregroundColor(.primary)
        }
    }
}
