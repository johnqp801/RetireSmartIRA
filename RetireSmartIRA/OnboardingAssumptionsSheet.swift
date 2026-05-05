import SwiftUI

struct OnboardingAssumptionsSheet: View {
    @ObservedObject var manager: MultiYearStrategyManager
    @Environment(\.dismiss) private var dismiss

    @State private var taxableBalance: Double
    @State private var hsaBalance: Double
    @State private var annualExpenses: Double
    @State private var horizonEndAge: Int
    @State private var withdrawalRule: WithdrawalOrderingRule
    @State private var heirTaxRatePercent: Int

    init(manager: MultiYearStrategyManager) {
        self.manager = manager
        _taxableBalance = State(initialValue: manager.assumptions.currentTaxableBalance)
        _hsaBalance = State(initialValue: manager.assumptions.currentHSABalance)
        _annualExpenses = State(initialValue: manager.assumptions.baselineAnnualExpenses)
        _horizonEndAge = State(initialValue: manager.assumptions.horizonEndAge)
        _withdrawalRule = State(initialValue: manager.assumptions.withdrawalOrderingRule)
        _heirTaxRatePercent = State(initialValue: Int(manager.assumptions.terminalLiquidationTaxRate * 100))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Taxable balance")
                        Spacer()
                        TextField("0", value: $taxableBalance, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
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
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
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
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
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
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
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
        manager.assumptions.assumptionsConfirmed = true  // unlock the pane
        manager.recompute(reason: .assumptionsChanged)
        dismiss()
    }
}
