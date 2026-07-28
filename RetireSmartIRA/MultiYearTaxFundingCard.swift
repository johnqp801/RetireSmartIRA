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
    /// Household's tax state, for the PA Ans 274 note. Deliberately not defaulted: a
    /// default would let a new call site drop the note without a compile error.
    let state: USState

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

    /// Every option the user can pick, each paired with the copy that states its FULL
    /// funding order. The view renders ALL of these at once, so this is also what a test
    /// reads to prove the cascade is visible at decision time rather than only after the
    /// choice is made. A plain `Picker` in a `Form` renders as a pop-up menu on macOS and a
    /// push list on iOS, both of which show `displayName` alone.
    var optionRows: [(mode: RothTaxFundingMode, title: String, subtitle: String)] {
        RothTaxFundingMode.allCases.map { ($0, $0.displayName, $0.fundingSubtitle) }
    }

    /// PA DOR Answer 274: the conversion exemption covers only what actually lands in the
    /// Roth, so electing withholding creates PA tax. Gated exactly like the single-year
    /// `RothConversionWithholdingCard`: withholding elected AND the household is in PA.
    var showsPennsylvaniaNote: Bool {
        mode.usesCustodialWithholding && state == .pennsylvania
    }

    static let pennsylvaniaNote =
        "Pennsylvania note: Roth conversions are normally PA-exempt, but PA DOR Answer 274 requires the full pre-tax balance to land in the Roth. The withheld portion is treated as a PA-taxable distribution, so this plan's state tax reflects it."

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pay conversion tax by")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            // Selectable rows rather than a Picker: each option must state its own funding
            // order while the user is choosing, not after.
            VStack(alignment: .leading, spacing: 10) {
                ForEach(optionRows, id: \.mode) { row in
                    optionRow(row)
                }
            }

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

            if showsPennsylvaniaNote {
                disclosure(Self.pennsylvaniaNote)
            }
            if showsIRAFundingDisclosure {
                disclosure(V2Disclosures.edSlottIRAFunding)
            }
            if showsEarlyDistributionWarning {
                disclosure(V2Disclosures.earlyDistributionNotModeled)
            }
        }
    }

    @ViewBuilder
    private func optionRow(_ row: (mode: RothTaxFundingMode, title: String, subtitle: String)) -> some View {
        let isSelected = row.mode == mode
        Button {
            assumptions.rothTaxFundingMode = row.mode
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(row.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title). \(row.subtitle)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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

/// Plan-level headline for a plan that cannot be funded. Sits directly under the plan summary
/// so the lifetime-tax figure is qualified where it is read, rather than leaving the user to
/// scroll the ladder and discover the problem year by year.
///
/// It carries ONLY what a row cannot: the count of years that failed and the count that merely
/// inherit the failure. The full explanation, including each year's own shortfall, lives in the
/// ladder rows, so the two treatments never print the same sentences on one screen.
///
/// Deliberately NOT dismissible: without it the tab presents a shortfall-bearing plan as though
/// it were funded, which is the defect V2.3's infeasible-year marking exists to fix.
struct TaxFundingFeasibilityBanner: View {
    let summary: FundingFeasibilitySummary

    var body: some View {
        if !summary.isFullyFunded {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.Semantic.red)
                    Text(summary.headline)
                        .font(.headline)
                    Spacer()
                }
                Text(summary.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.Semantic.redTint)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
