import SwiftUI

/// Approach picker (segmented control) + config-derived inline chips + a read-only giving
/// refinement block for the Multi-Year Plan tab (Phase 2c/5).
///
/// Segment 1 is labeled via `ApproachUILogic.anchorLabel` (never "Recommended" — see that type's
/// header comment). The other two segments expose deterministic ladders: "Fill to bracket" targets
/// the top of a chosen ordinary federal bracket; "Limit to IRMAA" targets a chosen IRMAA tier's
/// threshold minus a buffer. Bracket rates and IRMAA tiers are threaded in from the live tax-year
/// config (never hardcoded) so the chips track config updates automatically.
///
/// Selecting a segment/chip writes a `PersistedConversionApproach` through the `approach` binding
/// and calls `onChange` (the caller recomputes). This view does no engine work itself.
struct ConversionApproachSection: View {
    @Binding var approach: PersistedConversionApproach
    let effectiveHeirWeight: Double

    /// Ordinary federal brackets for the household's filing status, ascending by threshold.
    /// Config-derived: caller passes `TaxCalculationEngine.config.toTaxBrackets().federalSingle`
    /// (or `.federalMarried`) — never a hardcoded rate list.
    let brackets: [TaxBracket]
    /// All config IRMAA tiers (tier 0 = standard premium, filtered out below).
    /// Config-derived: `TaxCalculationEngine.config.toIRMAATiers()`.
    let irmaaTiers: [IRMAATier]
    let filingStatus: FilingStatus

    /// Year-1 no-additional-conversions baseline (ordinary income / MAGI), used only to flag chips
    /// whose target the household's baseline income has already passed. Nil disables the
    /// exceeded-status treatment entirely (all chips render as reachable) rather than inventing a
    /// number — see ApproachUILogic.bracketStatus.
    let baselineOrdinaryIncome: Double?
    let baselineMAGI: Double?

    /// IRMAA/ACA cliff safety margin (`MultiYearAssumptions.cliffBuffer`). Shared beyond this view,
    /// so edits always trigger `onChange`, regardless of which segment is active.
    @Binding var cliffBuffer: Double

    /// Seeded giving summary — read-only surfacing. The giving model itself (QCD-first funding,
    /// real-value maintenance) is computed by MultiYearInputAdapter from
    /// `dataManager.scenarioTotalCharitable`; this view does not recompute it.
    let givingAmount: Double
    var givingFundingLabel: String = "Funded QCD-first"

    var onChange: () -> Void

    private enum Segment: Hashable { case anchor, fillToBracket, limitToIRMAA }

    private var segment: Segment {
        switch approach.kind {
        case .recommendedTaxMin: return .anchor
        case .fillToBracket:     return .fillToBracket
        case .limitToIRMAA:      return .limitToIRMAA
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conversion approach").font(.headline)

            Picker("Conversion approach", selection: segmentBinding) {
                Text(ApproachUILogic.anchorLabel(effectiveHeirWeight: effectiveHeirWeight)).tag(Segment.anchor)
                Text("Fill to bracket").tag(Segment.fillToBracket)
                Text("Limit to IRMAA").tag(Segment.limitToIRMAA)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch segment {
            case .anchor:
                Text("Converts each year to \(effectiveHeirWeight > 0 ? "optimize tax and legacy" : "minimize lifetime tax") — the engine chooses the amount.")
                    .font(.caption).foregroundStyle(.secondary)
            case .fillToBracket:
                fillToBracketChips
            case .limitToIRMAA:
                limitToIRMAAChips
            }

            givingBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Segment switching

    private var segmentBinding: Binding<Segment> {
        Binding(
            get: { segment },
            set: { newSegment in
                switch newSegment {
                case .anchor:
                    approach = .recommendedTaxMin
                case .fillToBracket:
                    if approach.kind != .fillToBracket {
                        approach = PersistedConversionApproach(.fillToBracket(rate: 0.24))
                    }
                case .limitToIRMAA:
                    if approach.kind != .limitToIRMAA {
                        approach = PersistedConversionApproach(.limitToIRMAA(tier: 1, buffer: cliffBuffer))
                    }
                }
                onChange()
            }
        )
    }

    // MARK: - Fill to bracket

    private var fillToBracketChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Converts until ordinary taxable income (not total AGI) reaches the top of the chosen bracket.")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(brackets.enumerated()), id: \.offset) { index, bracket in
                    bracketChip(bracket, ceiling: index + 1 < brackets.count ? brackets[index + 1].threshold : nil)
                }
            }
            Text("AGI can be higher than the bracket top: qualified dividends and capital gains stack on top of ordinary income and are taxed separately.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func bracketChip(_ bracket: TaxBracket, ceiling: Double?) -> some View {
        let ratePercent = Int((bracket.rate * 100).rounded())
        let status: ApproachUILogic.TargetStatus = {
            guard let ceiling, let baselineOrdinaryIncome else { return .reachable }
            return ApproachUILogic.bracketStatus(bracketTopOrdinaryIncome: ceiling, baselineOrdinaryIncome: baselineOrdinaryIncome)
        }()
        let exceeded = status == .exceededByBaseline
        let isSelected = approach.kind == .fillToBracket && approach.rate.map { abs($0 - bracket.rate) < 1e-9 } ?? false

        return VStack(alignment: .leading, spacing: 2) {
            Button {
                approach = PersistedConversionApproach(.fillToBracket(rate: bracket.rate))
                onChange()
            } label: {
                Text("\(ratePercent)%")
                    .strikethrough(exceeded)
                    .font(.callout.weight(isSelected ? .bold : .regular))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12),
                                in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(exceeded)

            if exceeded {
                Text("Baseline income already exceeds the \(ratePercent)% ceiling, so no conversion is added this year — the policy still applies later.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Limit to IRMAA

    private var limitToIRMAAChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Converts until MAGI reaches the chosen IRMAA tier's threshold, minus the buffer below.")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(irmaaTiers.filter { $0.tier > 0 }, id: \.tier) { tier in
                    irmaaChip(tier)
                }
            }
            LabeledContent("Safety buffer below the tier threshold") {
                TextField("5000", value: $cliffBuffer, format: .number).multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
            }
            .font(.callout)
        }
        .onChange(of: cliffBuffer) { _, _ in onChange() }
    }

    private func irmaaChip(_ tier: IRMAATier) -> some View {
        let threshold = filingStatus == .marriedFilingJointly ? tier.mfjThreshold : tier.singleThreshold
        let ceiling = threshold - cliffBuffer
        let status: ApproachUILogic.TargetStatus = {
            guard let baselineMAGI else { return .reachable }
            return ApproachUILogic.bracketStatus(bracketTopOrdinaryIncome: ceiling, baselineOrdinaryIncome: baselineMAGI)
        }()
        let exceeded = status == .exceededByBaseline
        let isSelected = approach.kind == .limitToIRMAA && approach.tier == tier.tier

        return VStack(alignment: .leading, spacing: 2) {
            Button {
                approach = PersistedConversionApproach(.limitToIRMAA(tier: tier.tier, buffer: cliffBuffer))
                onChange()
            } label: {
                Text("Tier \(tier.tier)")
                    .strikethrough(exceeded)
                    .font(.callout.weight(isSelected ? .bold : .regular))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12),
                                in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(exceeded)

            if exceeded {
                Text("Baseline income already exceeds the tier \(tier.tier) ceiling, so no conversion is added this year — the policy still applies later.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Giving refinement (read-only surfacing)

    private var givingBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("Giving").font(.subheadline).foregroundStyle(.secondary)
            if givingAmount > 0 {
                Text("\(PlanSummary.shortDollars(givingAmount)) seeded annually. \(givingFundingLabel).")
                    .font(.callout)
            } else {
                Text("No charitable giving entered.").font(.callout).foregroundStyle(.secondary)
            }
            Text("Cash gifts are deducted in the year they're made — standard vs. itemized is chosen each year using itemizable deductions carried from your current-year scenario. Charitable carryforward and AMT aren't modeled in the projection.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
