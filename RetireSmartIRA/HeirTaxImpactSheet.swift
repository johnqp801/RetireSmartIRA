//
//  HeirTaxImpactSheet.swift
//  RetireSmartIRA
//

import SwiftUI

struct HeirTaxImpactSheet: View {
    @ObservedObject var manager: MultiYearStrategyManager
    @Environment(\.dismiss) private var dismiss
    @State private var heirTaxPercent: Int

    init(manager: MultiYearStrategyManager) {
        self.manager = manager
        _heirTaxPercent = State(initialValue: Int(manager.assumptions.terminalLiquidationTaxRate * 100))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Stepper to adjust heir tax rate
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HEIR TAX RATE")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        HStack {
                            Text("Assumed rate on assets left to heirs")
                                .font(.callout)
                            Spacer()
                            Stepper("\(heirTaxPercent)%", value: $heirTaxPercent, in: 0...37, step: 1)
                                .fixedSize()
                                .onChange(of: heirTaxPercent) { _, newValue in
                                    manager.assumptions.terminalLiquidationTaxRate = Double(newValue) / 100.0
                                    manager.recompute(reason: .assumptionsChanged)
                                }
                        }
                        Text("Affects how heavily the optimizer weighs Roth conversions that reduce the traditional IRA balance passed to heirs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(PlatformColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Long-horizon Legacy / Family Wealth analytics note.
                    // LegacyImpactView is coupled to the v1.x single-year engine via
                    // @EnvironmentObject DataManager and is not embeddable here without
                    // those dependencies. Full long-horizon chart integration is deferred
                    // to a future task once the charts are refactored for the multi-year
                    // engine (MultiYearStrategyManager).
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LONG-HORIZON ANALYTICS")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        Text("Long-horizon Legacy Impact and Family Wealth charts coming soon.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Text("These charts will show how the heir tax rate assumption affects projected family wealth across the full planning horizon once they are migrated to the multi-year engine.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(PlatformColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(16)
            }
            .navigationTitle("Heir Tax Impact")
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
}
