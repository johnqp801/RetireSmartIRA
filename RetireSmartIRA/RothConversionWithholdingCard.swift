//
//  RothConversionWithholdingCard.swift
//  RetireSmartIRA
//
//  v1.8.4 — Jonggie Issue 2: when a user does a Roth conversion without
//  outside money to pay the federal tax, the brokerage withholds a portion
//  of the conversion. This view lets the user model that.
//
//  Surfaces:
//   - Picker: "Pay conversion tax from: [Outside Money / The Conversion Itself]"
//   - When withheld: federal withholding rate picker (10–37%, default 24%)
//   - Live readout: withholding amount + net Roth deposit
//   - Transparency note for PA Ans 274 (withheld portion becomes PA-taxable)
//   - Warning banner if user is under 59½ (early-withdrawal penalty risk on
//     the withheld portion)
//

import SwiftUI

struct RothConversionWithholdingCard: View {
    @Environment(DataManager.self) var dataManager

    private var grossConversion: Double {
        dataManager.scenarioTotalRothConversion
    }

    private var isWithheldMode: Bool {
        dataManager.rothConversionWithholdingMode == .withheldFromConversion
    }

    private var primaryUnder59Half: Bool {
        dataManager.currentAge < 60
    }

    private var spouseUnder59Half: Bool {
        dataManager.enableSpouse && dataManager.spouseCurrentAge < 60
    }

    private var paInteractionActive: Bool {
        isWithheldMode && dataManager.selectedState == .pennsylvania
    }

    /// Standard federal withholding-rate choices. Map to the marginal brackets
    /// that 2026 retirees most commonly fall into. Brokerages (Fidelity,
    /// Schwab, Vanguard) typically accept any whole-percent value, but
    /// these correspond to the 2026 bracket edges.
    private let rateOptions: [(label: String, rate: Double)] = [
        ("10%", 0.10), ("12%", 0.12), ("22%", 0.22), ("24%", 0.24),
        ("32%", 0.32), ("35%", 0.35), ("37%", 0.37)
    ]

    var body: some View {
        @Bindable var dm = dataManager

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(Color.UI.brandTeal)
                Text("Conversion Tax — Paid From")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Picker("Pay conversion tax from", selection: $dm.rothConversionWithholdingMode) {
                Text("Outside money").tag(RothConversionWithholdingMode.paidFromOutside)
                Text("Withhold from conversion").tag(RothConversionWithholdingMode.withheldFromConversion)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Pay conversion tax from")

            if isWithheldMode {
                // Federal withholding rate picker
                HStack {
                    Text("Federal withholding rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Federal withholding rate", selection: $dm.rothConversionFederalWithholdingRate) {
                        ForEach(rateOptions, id: \.rate) { opt in
                            Text(opt.label).tag(opt.rate)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .accessibilityLabel("Federal withholding rate")
                }

                Divider().padding(.vertical, 2)

                // Live readout: withholding + net deposit
                VStack(spacing: 6) {
                    readoutRow(
                        label: "Gross conversion",
                        value: grossConversion,
                        color: Color.UI.textPrimary
                    )
                    readoutRow(
                        label: "Federal withholding (paid to IRS)",
                        value: dataManager.scenarioRothConversionWithholdingAmount,
                        color: Color.Semantic.amber,
                        prefix: "−"
                    )
                    Divider().padding(.vertical, 2)
                    readoutRow(
                        label: "Net deposit to Roth",
                        value: dataManager.scenarioRothConversionNetAmount,
                        color: Color.UI.brandTeal,
                        bold: true
                    )
                }

                // PA Ans 274 transparency note
                if paInteractionActive {
                    let withholdingFmt = dataManager.scenarioRothConversionWithholdingAmount
                        .formatted(.currency(code: "USD").precision(.fractionLength(0)))
                    InlineNote(
                        icon: "info.circle.fill",
                        color: Color.Semantic.amber,
                        text: "Pennsylvania note: Roth conversions are normally PA-exempt, but PA DOR Answer 274 requires the full pre-tax balance to land in the Roth. The withheld portion (\(withholdingFmt)) is treated as a PA-taxable distribution."
                    )
                }

                // Under-59½ warning
                if primaryUnder59Half || spouseUnder59Half {
                    InlineNote(
                        icon: "exclamationmark.triangle.fill",
                        color: Color.Semantic.red,
                        text: "If you are under 59½, federal tax withheld from the conversion may be treated as an early distribution by the IRS — subject to a 10% additional tax. This app does not yet model that penalty. Consult a tax professional before electing withholding under age 59½."
                    )
                }
            } else {
                // Paid-from-outside summary
                Text("Full \(grossConversion.formatted(.currency(code: "USD").precision(.fractionLength(0)))) gross conversion will land in the Roth. The federal tax on this conversion comes from non-retirement assets (taxable brokerage, savings, etc.).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.UI.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func readoutRow(label: String, value: Double, color: Color, prefix: String = "", bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(prefix)\(value.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                .font(bold ? .callout.weight(.bold) : .callout)
                .foregroundStyle(color)
        }
    }
}

/// Lightweight inline note view — colored icon + text on the same row,
/// wrapped in a tinted background. Used for PA caveat + under-59½ warning.
private struct InlineNote: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
