//
//  TaxPlanningAdvancedSheet.swift
//  RetireSmartIRA

import SwiftUI

struct TaxPlanningAdvancedSheet: View {
    @ObservedObject var manager: MultiYearStrategyManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Assumptions") {
                    HStack {
                        Text("Taxable balance")
                        Spacer()
                        TextField("0", value: $manager.assumptions.currentTaxableBalance, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("HSA balance")
                        Spacer()
                        TextField("0", value: $manager.assumptions.currentHSABalance, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Annual expenses")
                        Spacer()
                        TextField("60000", value: $manager.assumptions.baselineAnnualExpenses, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    HStack {
                        Text("Cliff buffer ($)")
                        Spacer()
                        TextField("5000", value: $manager.assumptions.cliffBuffer, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Power-user knobs")
                } footer: {
                    Text("Safety margin below IRMAA / ACA cliffs. Default $5K. Increase to be more conservative; decrease for tighter optimization.")
                }

                Section {
                    Button("Restore dismissed insights") {
                        manager.restoreDismissedInsights()
                    }
                    .disabled(manager.assumptions.dismissedInsightKeys.isEmpty)
                } footer: {
                    Text("Brings back any SS claim nudge or widow stress callout banners you've previously dismissed.")
                }
            }
            .navigationTitle("Advanced")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        manager.recompute(reason: .assumptionsChanged)
                        dismiss()
                    }
                }
            }
        }
    }
}
