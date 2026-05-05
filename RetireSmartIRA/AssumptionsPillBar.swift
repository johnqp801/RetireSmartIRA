//
//  AssumptionsPillBar.swift
//  RetireSmartIRA

import SwiftUI

struct AssumptionsPillBar: View {
    @ObservedObject var manager: MultiYearStrategyManager
    @State private var activePopover: PopoverID?

    enum PopoverID: Hashable {
        case cpi, growth, endAge, ssAge, withdrawalRule, heirTax, advanced
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                cpiPill
                growthPill
                endAgePill
                ssPill
                withdrawalRulePill
                heirTaxPill
                stressTestPill
                advancedPill
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(PlatformColor.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    private var cpiPill: some View {
        AssumptionPill(
            label: "CPI \(Int(manager.assumptions.cpiRate * 100))%",
            style: .standard
        ) { activePopover = .cpi }
        .popover(isPresented: bindingFor(.cpi)) {
            NumericStepperPopover(
                title: "CPI rate",
                value: Binding(
                    get: { manager.assumptions.cpiRate * 100 },
                    set: { manager.assumptions.cpiRate = $0 / 100 }
                ),
                range: 0...6,
                step: 0.1,
                format: { String(format: "%.1f%%", $0) },
                onCommit: {
                    activePopover = nil
                    manager.recompute(reason: .assumptionsChanged)
                }
            )
        }
    }

    private var growthPill: some View {
        AssumptionPill(
            label: "Growth \(Int(manager.assumptions.investmentGrowthRate * 100))%",
            style: .standard
        ) { activePopover = .growth }
        .popover(isPresented: bindingFor(.growth)) {
            NumericStepperPopover(
                title: "Growth rate",
                value: Binding(
                    get: { manager.assumptions.investmentGrowthRate * 100 },
                    set: { manager.assumptions.investmentGrowthRate = $0 / 100 }
                ),
                range: 0...10,
                step: 0.5,
                format: { String(format: "%.1f%%", $0) },
                onCommit: {
                    activePopover = nil
                    manager.recompute(reason: .assumptionsChanged)
                }
            )
        }
    }

    private var endAgePill: some View {
        AssumptionPill(
            label: "End age \(manager.assumptions.horizonEndAge)",
            style: .standard
        ) { activePopover = .endAge }
        .popover(isPresented: bindingFor(.endAge)) {
            NumericStepperPopover(
                title: "Horizon end age",
                value: Binding(
                    get: { Double(manager.assumptions.horizonEndAge) },
                    set: { manager.assumptions.horizonEndAge = Int($0) }
                ),
                range: 80...105,
                step: 1,
                format: { String(Int($0)) },
                onCommit: {
                    activePopover = nil
                    manager.recompute(reason: .assumptionsChanged)
                }
            )
        }
    }

    private var ssPill: some View {
        // Full SS popover deferred to v2.1 — pill is display-only in V2.0.
        AssumptionPill(label: "SS 67/67", style: .standard) { }
    }

    private var withdrawalRulePill: some View {
        AssumptionPill(
            label: "Rule: \(shortRuleLabel)",
            style: .standard
        ) { activePopover = .withdrawalRule }
        .popover(isPresented: bindingFor(.withdrawalRule)) {
            EnumPickerPopover<WithdrawalOrderingRule>(
                title: "Withdrawal ordering",
                selection: $manager.assumptions.withdrawalOrderingRule,
                options: [
                    ("Tax-efficient", .taxEfficient),
                    ("Deplete trad first", .depleteTradFirst),
                    ("Preserve Roth", .preserveRoth),
                    ("Proportional", .proportional)
                ],
                onCommit: {
                    activePopover = nil
                    manager.recompute(reason: .assumptionsChanged)
                }
            )
        }
    }

    private var shortRuleLabel: String {
        switch manager.assumptions.withdrawalOrderingRule {
        case .taxEfficient: return "Tax-eff"
        case .depleteTradFirst: return "Deplete trad"
        case .preserveRoth: return "Preserve Roth"
        case .proportional: return "Proportional"
        }
    }

    private var heirTaxPill: some View {
        AssumptionPill(
            label: "Heir Tax Rate: \(Int(manager.assumptions.terminalLiquidationTaxRate * 100))%",
            style: .featured
        ) { activePopover = .heirTax }
        .popover(isPresented: bindingFor(.heirTax)) {
            VStack(spacing: 12) {
                Text("Heir Tax Rate").font(.headline)
                Text("The tax rate we model your heirs (or you, at end of plan) paying on remaining traditional IRA balances. Higher rate → engine recommends more aggressive Roth conversions now.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 300)
                NumericStepperPopover(
                    title: "",
                    value: Binding(
                        get: { manager.assumptions.terminalLiquidationTaxRate * 100 },
                        set: { manager.assumptions.terminalLiquidationTaxRate = $0 / 100 }
                    ),
                    range: 0...37,
                    step: 1,
                    format: { String(format: "%.0f%%", $0) },
                    onCommit: {
                        activePopover = nil
                        manager.recompute(reason: .assumptionsChanged)
                    }
                )
            }
            .padding()
        }
    }

    private var stressTestPill: some View {
        AssumptionPill(
            label: manager.assumptions.stressTestEnabled ? "⚡ Stress ON" : "⚡ Stress OFF",
            style: manager.assumptions.stressTestEnabled ? .toggleOn : .toggleOff
        ) {
            manager.assumptions.stressTestEnabled.toggle()
            manager.recompute(reason: .assumptionsChanged)
        }
    }

    private var advancedPill: some View {
        AssumptionPill(label: "⋯ Advanced", style: .overflow) {
            activePopover = .advanced
        }
        .sheet(isPresented: bindingFor(.advanced)) {
            TaxPlanningAdvancedSheet(manager: manager)
        }
    }

    private func bindingFor(_ id: PopoverID) -> Binding<Bool> {
        Binding(
            get: { activePopover == id },
            set: { if !$0 { activePopover = nil } }
        )
    }
}
