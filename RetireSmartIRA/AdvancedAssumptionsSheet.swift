import SwiftUI

/// Advanced Multi-Year Plan assumptions. Binds directly to manager.assumptions; rate fields are
/// shown as whole percents. The caller recomputes when the sheet closes (onCommit); persistence
/// rides the presenter's onChange(of: manager.assumptions).
struct AdvancedAssumptionsSheet: View {
    @Binding var assumptions: MultiYearAssumptions
    let spouseEnabled: Bool
    var onCommit: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Growth and inflation") {
                    percentStepper("Investment growth", $assumptions.investmentGrowthRate, maxPercent: 15)
                    percentStepper("Inflation (CPI)", $assumptions.cpiRate, maxPercent: 10)
                }
                Section("Planning horizon") {
                    Stepper("Plan through age \(assumptions.horizonEndAge)",
                            value: $assumptions.horizonEndAge, in: 70...110)
                    if spouseEnabled {
                        Stepper("Spouse: plan through age \(spouseHorizon.wrappedValue)",
                                value: spouseHorizon, in: 70...110)
                    }
                }
                Section("Advanced tax assumptions") {
                    percentStepper("Future tax rate on leftover traditional IRA",
                                   $assumptions.terminalLiquidationTaxRate, maxPercent: 40)
                    Text("Higher values make conversions more aggressive, since leaving money in a traditional IRA looks more costly.")
                        .font(.caption).foregroundStyle(.secondary)
                    percentStepper("Present-value discount rate",
                                   $assumptions.pvRealDiscountRate, maxPercent: 8)
                    Picker("Withdrawal order", selection: $assumptions.withdrawalOrderingRule) {
                        ForEach(WithdrawalOrderingRule.allCases, id: \.self) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                }
            }
            .navigationTitle("Advanced assumptions")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { onCommit() }
    }

    /// Spouse horizon falls back to the primary horizon when unset.
    private var spouseHorizon: Binding<Int> {
        Binding(
            get: { assumptions.horizonEndAgeSpouse ?? assumptions.horizonEndAge },
            set: { assumptions.horizonEndAgeSpouse = $0 }
        )
    }

    /// Whole-percent stepper over a stored decimal rate (0.06 shown as 6%).
    private func percentStepper(_ label: String, _ value: Binding<Double>, maxPercent: Double) -> some View {
        // Show the true value (do not round in `get`, which would misreport a 2.5% default as 3%
        // and snap it to a whole percent on the first tap). Stepping moves by 1 percentage point.
        let pct = Binding<Double>(
            get: { value.wrappedValue * 100 },
            set: { value.wrappedValue = $0 / 100 }
        )
        let shown = (pct.wrappedValue * 10).rounded() / 10   // 1-decimal display, no float noise
        return Stepper("\(label): \(String(format: "%g", shown))%", value: pct, in: 0...maxPercent, step: 1)
    }
}
