import SwiftUI

struct OnboardingAssumptionsSheet: View {
    @ObservedObject var manager: MultiYearStrategyManager
    @Environment(\.dismiss) private var dismiss

    @State private var taxableBalance: Double = 0
    @State private var hsaBalance: Double = 0
    @State private var annualExpenses: Double = 60_000
    @State private var horizonEndAge: Int = 95
    @State private var withdrawalRule: WithdrawalOrderingRule = .taxEfficient
    @State private var heirTaxRatePercent: Int = 22

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Taxable balance")
                        Spacer()
                        TextField("0", value: $taxableBalance, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                } footer: {
                    Text("Total in non-retirement brokerage accounts.")
                }

                Section {
                    HStack {
                        Text("HSA balance")
                        Spacer()
                        TextField("0", value: $hsaBalance, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                } footer: {
                    Text("Skip if you don't have an HSA.")
                }

                Section {
                    HStack {
                        Text("Annual expenses")
                        Spacer()
                        TextField("60,000", value: $annualExpenses, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                } footer: {
                    Text("Approximate annual spending in retirement (today's dollars).")
                }

                Section {
                    Stepper("Horizon end age: \(horizonEndAge)", value: $horizonEndAge, in: 80...105)
                } footer: {
                    Text("Plan ends at this age.")
                }

                Section {
                    Picker("Withdrawal preset", selection: $withdrawalRule) {
                        Text("Tax-efficient").tag(WithdrawalOrderingRule.taxEfficient)
                        Text("Deplete trad first").tag(WithdrawalOrderingRule.depleteTradFirst)
                        Text("Preserve Roth").tag(WithdrawalOrderingRule.preserveRoth)
                        Text("Proportional").tag(WithdrawalOrderingRule.proportional)
                    }
                } footer: {
                    Text("How the engine sources withdrawals to fund expenses.")
                }

                Section {
                    Stepper("Heir tax rate: \(heirTaxRatePercent)%", value: $heirTaxRatePercent, in: 0...37)
                } footer: {
                    Text("Tax rate on assets remaining at end of plan.")
                }
            }
            .navigationTitle("Set up your strategy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Build my strategy") {
                        submit()
                    }
                    .disabled(annualExpenses <= 0 || horizonEndAge < 80)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        manager.assumptions.currentTaxableBalance = taxableBalance
        manager.assumptions.currentHSABalance = hsaBalance
        manager.assumptions.baselineAnnualExpenses = annualExpenses
        manager.assumptions.horizonEndAge = horizonEndAge
        manager.assumptions.withdrawalOrderingRule = withdrawalRule
        manager.assumptions.terminalLiquidationTaxRate = Double(heirTaxRatePercent) / 100.0
        manager.recompute(reason: .assumptionsChanged)
        dismiss()
    }
}
