import SwiftUI

struct MultiYearPlanView: View {
    @Environment(DataManager.self) private var dataManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @StateObject private var manager = MultiYearStrategyManager()
    @State private var attached = false
    @State private var units: DisplayUnits = .todaysDollars
    @State private var showingAdvanced = false
    @State private var isGeneratingPDF = false
    #if canImport(UIKit)
    @State private var briefingPDF: Data?
    @State private var showBriefingShare = false
    #endif

    // Whether heir / legacy analysis is active. Mirrors the Profile "Consider Legacy Planning"
    // toggle so the Multi-Year tab stays consistent with the single-year views: when off, the heir
    // trade-off (frontier + "what heirs keep") is hidden and the plan follows the owner-optimal path.
    private var legacyEnabled: Bool { dataManager.enableLegacyPlanning }

    // Selected weight's path (drives summary + ladder), then filtered through the selected
    // conversion approach: when a deterministic approach (fill-to-bracket / limit-to-IRMAA) is
    // chosen, the whole tab (summary, ladder, balances, threshold map, CPA briefing) reads that
    // approach's path from the comparison instead of the objective-optimizer path. Falls back to
    // currentResult. When legacy planning is off, the heir-weighted frontier path is ignored so the
    // view shows owner-optimal.
    private var activePath: [YearRecommendation] {
        let base: [YearRecommendation] = {
            if legacyEnabled,
               let p = manager.heirFrontier?.points.first(where: { $0.weight == manager.selectedHeirWeight })?.recommendedPath, !p.isEmpty {
                return p
            }
            return manager.currentResult?.recommendedPath ?? []
        }()
        return ApproachUILogic.activePath(
            selected: manager.assumptions.conversionApproach.toApproach(),
            comparison: manager.approachComparison,
            frontierOrCurrent: base)
    }

    // Ladder rows with IRMAA attributed to conversions only: each year's surcharge minus the
    // no-conversion baseline's surcharge for that year (so income-driven IRMAA isn't blamed on the plan).
    private var ladderRows: [LadderRow] {
        let baselineIRMAA = Dictionary(
            (manager.baselineProjection ?? []).map { ($0.year, $0.taxBreakdown.irmaa) },
            uniquingKeysWith: { first, _ in first })
        return activePath.map { LadderRow($0, baselineIRMAA: baselineIRMAA[$0.year] ?? 0) }
    }

    /// How many years the no-conversion baseline already pays Medicare IRMAA on its own. When this
    /// is high but few ladder rows are flagged, the surcharge is coming from RMDs/other income (not
    /// the conversions), so a note clarifies why the IRMAA column is nearly empty.
    private var baselineIRMAAYears: Int {
        (manager.baselineProjection ?? []).filter { $0.taxBreakdown.irmaa > 0 }.count
    }

    // Future-dollars vs present-value toggle. Shared by the compact (stacked) and regular
    // (side-by-side) header layouts. Only shown once there's a plan to display.
    @ViewBuilder private var unitsPicker: some View {
        if !activePath.isEmpty {
            Picker("Units", selection: $units) {
                Text("Future $").tag(DisplayUnits.todaysDollars)
                Text("Present value").tag(DisplayUnits.presentValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if hSizeClass == .compact {
                    // Narrow widths (iPhone): the fixed-size segmented picker crowds and truncates
                    // the large title on one line, so stack the toggle beneath it. iPad/Mac (regular)
                    // keep the original side-by-side header below.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Multi-Year Plan").font(.largeTitle.bold())
                        unitsPicker
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Multi-Year Plan").font(.largeTitle.bold())
                        Spacer()
                        unitsPicker
                    }
                }

                if let result = manager.currentResult {
                    SurvivorStressBanner(widowDelta: result.widowStressDelta,
                                         dismissed: dismissBinding("survivor"))
                    SSClaimNudgeBanner(nudge: result.ssClaimNudge,
                                       dismissed: dismissBinding("ssNudge"))
                }
                ConversionWindowBanner(yearsBeforeFirstRMD: manager.yearsBeforeFirstRMD,
                                       dismissed: dismissBinding("conversionWindow"))

                AssumptionsStripView(
                    taxableSummary: (dataManager.taxableAccounts.count,
                                     dataManager.taxableAccounts.reduce(0) { $0 + $1.balance }),
                    annualExpenses: Binding(get: { manager.assumptions.baselineAnnualExpenses },
                                            set: { manager.assumptions.baselineAnnualExpenses = $0 }),
                    hsaBalance: Binding(get: { manager.assumptions.currentHSABalance },
                                        set: { manager.assumptions.currentHSABalance = $0 }),
                    horizonEndAge: Binding(get: { manager.assumptions.horizonEndAge },
                                           set: { manager.assumptions.horizonEndAge = $0 }),
                    onCommit: { recomputeAll() })

                Year1EditorView(
                    year1RothConversion: year1RothBinding,
                    plannedYear1: activePath.first.map { year1Roth(actions: $0.actions) } ?? 0,
                    status: offPlanStatus,
                    onCommit: { onYear1Edited() },
                    onResetToOptimal: { resetYear1ToOptimal() })

                Button {
                    showingAdvanced = true
                } label: {
                    Label("Advanced assumptions", systemImage: "slider.horizontal.3")
                }
                .font(.callout)

                ConversionApproachSection(
                    approach: Binding(get: { manager.assumptions.conversionApproach },
                                      set: { manager.assumptions.conversionApproach = $0 }),
                    effectiveHeirWeight: legacyEnabled ? manager.selectedHeirWeight : 0,
                    brackets: dataManager.filingStatus == .marriedFilingJointly
                        ? TaxCalculationEngine.config.toTaxBrackets().federalMarried
                        : TaxCalculationEngine.config.toTaxBrackets().federalSingle,
                    irmaaTiers: TaxCalculationEngine.config.toIRMAATiers(),
                    filingStatus: dataManager.filingStatus,
                    baselineOrdinaryIncome: manager.baselineProjection?.first.map { $0.taxableIncome - $0.taxablePreferential },
                    baselineMAGI: manager.baselineProjection?.first?.magi,
                    cliffBuffer: Binding(get: { manager.assumptions.cliffBuffer },
                                        set: { manager.assumptions.cliffBuffer = $0 }),
                    givingAmount: dataManager.scenarioTotalCharitable,
                    onChange: { recomputeAll() })

                if manager.isComputing && manager.currentResult == nil {
                    ProgressView("Computing your plan…").frame(maxWidth: .infinity).padding()
                } else if activePath.isEmpty {
                    ContentUnavailableView("Set your assumptions to see your plan",
                        systemImage: "calendar.badge.clock")
                } else {
                    PlanSummaryView(summary: PlanSummary(path: activePath,
                        pvRealDiscountRate: manager.assumptions.pvRealDiscountRate,
                        cpiRate: manager.assumptions.cpiRate), units: units)
                    if dataManager.taxableAccounts.isEmpty,
                       ladderRows.contains(where: { $0.conversion > 0 }) {
                        Text("No taxable account entered. This plan assumes Roth conversion taxes must be paid from additional IRA withdrawals, which may materially change the conversion ladder.")
                            .font(.callout).foregroundStyle(.orange)
                            .padding().background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    let primarySS = dataManager.primarySSBenefit?.plannedAnnualBenefit(birthYear: dataManager.birthYear) ?? 0
                    let spouseSS = dataManager.enableSpouse ? (dataManager.spouseSSBenefit?.plannedAnnualBenefit(birthYear: dataManager.spouseBirthYear) ?? 0) : 0
                    if primarySS == 0 && spouseSS == 0 {
                        Text("No Social Security entered. This plan assumes $0 in benefits. Add yours on the Social Security tab.")
                            .font(.callout).foregroundStyle(.orange)
                            .padding().background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if dataManager.incomeSources.isEmpty {
                        Text("No income sources entered. If you have pension, wages, or investment income, add it on the Income & Deductions tab.")
                            .font(.callout).foregroundStyle(.orange)
                            .padding().background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if let cmp = manager.approachComparison {
                        ApproachComparisonView(
                            comparison: cmp,
                            effectiveHeirWeight: legacyEnabled ? manager.selectedHeirWeight : 0,
                            units: units,
                            showHeirs: legacyEnabled)
                    }
                    if let baseline = manager.baselineProjection, !baseline.isEmpty {
                        TaxImpactChartView(model: TaxImpactChart(plan: activePath, doingNothing: baseline))
                    }
                    if ladderRows.contains(where: { $0.conversion > 0 }) {
                        ConversionLadderChartView(model: ConversionLadderChart(path: activePath))
                    }
                    LadderListView(rows: ladderRows, baselineIRMAAYears: baselineIRMAAYears)
                    BalancesChartView(model: BalancesChart(
                        path: activePath,
                        pessimistic: manager.currentResult?.sensitivityBands.pessimistic,
                        optimistic: manager.currentResult?.sensitivityBands.optimistic))
                    ThresholdMapChartView(model: ThresholdMapChart(
                        path: activePath,
                        magiLines: ThresholdMapThresholds.magiLines(
                            config: TaxCalculationEngine.config,
                            filingStatus: dataManager.filingStatus,
                            householdSize: dataManager.scenario.acaHouseholdSize,
                            includeACA: dataManager.scenario.enableACAModeling),
                        bracketLines: ThresholdMapThresholds.bracketLines(
                            config: TaxCalculationEngine.config,
                            filingStatus: dataManager.filingStatus)))
                    if legacyEnabled {
                        if let frontier = manager.heirFrontier {
                            HeirFrontierChartView(model: HeirFrontierChart(
                                result: frontier, selectedWeight: manager.selectedHeirWeight, units: units))
                            HeirFrontierView(result: frontier,
                                selectedWeight: Binding(get: { manager.selectedHeirWeight },
                                                        set: { manager.selectedHeirWeight = $0 }),
                                units: units)
                        } else if manager.isComputingFrontier {
                            ProgressView("Computing heir trade-off…")
                        }
                    }
                    Text("Taxable-account sales use an average cost-basis estimate and a default funding order. Lot-level tax selection, short-term holding periods, and single-year income reconciliation are planned future enhancements.")
                        .font(.caption).foregroundStyle(.secondary)
                    AssumptionsLimitationsView()
                    Button {
                        exportBriefing()
                    } label: {
                        HStack(spacing: 8) {
                            if isGeneratingPDF { ProgressView().controlSize(.small) }
                            Image(systemName: "doc.richtext")
                            Text(isGeneratingPDF ? "Generating PDF..." : "Export CPA briefing")
                        }
                        .font(.callout)
                    }
                    .disabled(isGeneratingPDF)
                }
            }
            .padding()
        }
        .task {
            guard !attached else { return }
            attached = true
            manager.attach(dataManager: dataManager, scenarioStateManager: dataManager.scenario)
            recomputeAll()
        }
        // Run the heir frontier and persist on the infrequent events, not per keystroke: once per
        // settled compute (currentResult republishes after the debounced engine run) and, for the
        // save, on banner dismissal.
        .onChange(of: manager.currentResult) {
            // Once per settled compute (now infrequent, since the Year-1 field commits on a debounce):
            // refresh the heir frontier (at .utility, so it yields to the UI) and persist. Skip the
            // heavy 6-weight optimize entirely when legacy planning is off (heir view is hidden).
            if legacyEnabled { manager.computeHeirFrontier() }
            // Refresh the three-way approach comparison too (same cadence as the frontier). Not
            // gated by legacyEnabled: the comparison always covers the selected/anchor/no-conversion
            // columns; computeApproachComparison() itself folds in the heir weight only when legacy
            // planning is on.
            manager.computeApproachComparison()
            dataManager.saveAllData()
        }
        // The Profile "Consider Legacy Planning" toggle gates the heir trade-off here too. Turning it
        // back on refreshes the frontier (which may be nil or stale from while it was off).
        .onChange(of: dataManager.enableLegacyPlanning) { _, enabled in
            if enabled { manager.computeHeirFrontier() }
        }
        .onChange(of: manager.assumptions.dismissedInsightKeys) { dataManager.saveAllData() }
        // Switching the selected approach should refresh the comparison promptly rather than waiting
        // on the next settled plan compute (the picker's own onChange already recomputes the plan via
        // recomputeAll(), but that recompute may not touch currentResult's identity if the underlying
        // plan happens not to change, so the comparison needs its own trigger here).
        .onChange(of: manager.assumptions.conversionApproach) { manager.computeApproachComparison() }
        .sheet(isPresented: $showingAdvanced) {
            AdvancedAssumptionsSheet(
                assumptions: Binding(get: { manager.assumptions }, set: { manager.assumptions = $0 }),
                spouseEnabled: dataManager.enableSpouse,
                onCommit: { recomputeAll() })
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showBriefingShare) {
            if let briefingPDF {
                ShareSheet(pdfData: briefingPDF, fileName: "MultiYearPlan_\(dataManager.currentYear).pdf")
            }
        }
        #endif
    }

    // Editors just trigger a (debounced) recompute. The manager refreshes the heir frontier and
    // persists once per settled compute (see performCompute), so editing stays snappy.
    private func recomputeAll() {
        manager.recompute(reason: .assumptionsChanged)
    }

    // Builds the CPA briefing's leading approach-summary section from the live comparison. Nil when
    // no comparison has been computed yet, or when the selected approach IS the objective optimizer
    // (collapsed — ApproachComparison.collapsesToTwoColumns), so the briefing omits the section
    // entirely and reads exactly like today's single-plan document.
    private var briefingApproachSummary: CPABriefingModel.ApproachSummary? {
        guard let cmp = manager.approachComparison, !cmp.collapsesToTwoColumns else { return nil }
        let heirWeight = legacyEnabled ? manager.selectedHeirWeight : 0
        return CPABriefingModel.ApproachSummary(
            selectedLabel: ApproachUILogic.columnLabel(cmp.selectedApproach, effectiveHeirWeight: heirWeight),
            anchorLabel: ApproachUILogic.anchorLabel(effectiveHeirWeight: heirWeight),
            deltas: MultiYearCPABriefing.approachDeltaSummary(cmp),
            niitIncreased: cmp.flags.niitIncreased)
    }

    private func makeBriefingModel() -> CPABriefingModel {
        CPABriefingModel(
            preparedFor: dataManager.userName.isEmpty ? "Plan" : dataManager.userName,
            taxYear: dataManager.currentYear,
            filingStatusLabel: dataManager.filingStatus.rawValue,
            stateLabel: dataManager.selectedState.abbreviation,
            primaryBirthYear: dataManager.birthYear,
            summary: PlanSummary(path: activePath,
                                 pvRealDiscountRate: manager.assumptions.pvRealDiscountRate,
                                 cpiRate: manager.assumptions.cpiRate),
            comparison: PlanComparison(
                plan: activePath,
                doingNothing: manager.baselineProjection ?? [],
                heirSalary: dataManager.legacyHeirEstimatedSalary,
                heirFilingStatus: dataManager.legacyHeirFilingStatus,
                heirDrawdownYears: dataManager.legacyDrawdownYears),
            yearRows: activePath,
            frontier: legacyEnabled ? manager.heirFrontier : nil,
            includeHeirs: legacyEnabled,
            assumptions: manager.assumptions,
            limitations: V2Disclosures.limitations,
            positioning: V2Disclosures.positioning,
            approachSummary: briefingApproachSummary)
    }

    private func exportBriefing() {
        isGeneratingPDF = true
        let html = MultiYearCPABriefingHTML.build(makeBriefingModel())
        let year = dataManager.currentYear
        Task {
            let data = await PDFExportService.generatePDF(fromHTML: html)
            isGeneratingPDF = false
            #if canImport(UIKit)
            briefingPDF = data
            showBriefingShare = true
            #elseif canImport(AppKit)
            MacPDFExporter.save(pdfData: data, fileName: "MultiYearPlan_\(year).pdf")
            #endif
        }
    }

    // Combined household Year-1 Roth conversion. v2.0 treats it as one amount (matches
    // resetYear1ToEngineOptimal). Editing preserves any existing per-spouse split (engine sums them,
    // so totals/tax are unchanged); per-spouse editing UI is 2.1.
    private var year1RothBinding: Binding<Double> {
        Binding(
            get: { dataManager.yourRothConversion + dataManager.spouseRothConversion },
            set: { newValue in
                let split = Year1RothSplit.apply(
                    newTotal: newValue,
                    your: dataManager.yourRothConversion,
                    spouse: dataManager.spouseRothConversion)
                dataManager.yourRothConversion = split.your
                dataManager.spouseRothConversion = split.spouse
            }
        )
    }

    private func year1Roth(_ result: MultiYearStrategyResult) -> Double {
        year1Roth(actions: result.recommendedPath.first?.actions ?? [])
    }

    // Sums Year-1 Roth conversion actions from an arbitrary action list. Used to feed the Year-1
    // editor from activePath (which, while a deterministic approach is selected, is the approach's
    // path from the comparison rather than manager.currentResult), so the field reflects whichever
    // path is actually driving the tab.
    private func year1Roth(actions: [LeverAction]) -> Double {
        actions.reduce(0.0) { acc, act in
            if case let .rothConversion(amount) = act { return acc + amount }
            return acc
        }
    }

    private var offPlanStatus: OffPlanStatus? {
        guard let current = manager.currentResult, let optimal = manager.engineOptimalResult else { return nil }
        // Off-plan reflects the user's only lever here (Year-1 conversion). When it already matches
        // the engine-optimal Year-1, the residual whole-path gap is the optimizer's pinned-vs-free
        // path-dependence, not a user-fixable choice, so it reads as on plan.
        return OffPlanStatus.forYear1(
            userYear1: year1Roth(current),
            optimalYear1: year1Roth(optimal),
            currentLifetimeTax: current.lifetimeTaxFromRecommendedPath,
            optimalLifetimeTax: optimal.lifetimeTaxFromRecommendedPath)
    }

    private func onYear1Edited() {
        // Editing Year-1 directly is only meaningful against the objective optimizer's own path —
        // a deterministic approach (fill-to-bracket / limit-to-IRMAA) computes its own Year-1, so a
        // manual edit reverts the selection back to the optimizer (picker snaps to segment 1 via the
        // same conversionApproach binding) before the edit takes effect.
        if manager.assumptions.conversionApproach != .recommendedTaxMin {
            manager.assumptions.conversionApproach = PersistedConversionApproach(
                ApproachUILogic.approachAfterYear1Edit(manager.assumptions.conversionApproach.toApproach()))
        }
        manager.recompute(reason: .overridesChanged)   // current-only; optimal is cached
    }

    private func resetYear1ToOptimal() {
        manager.resetYear1ToEngineOptimal()            // writes the shared levers + recomputes current
    }

    /// One-way dismissal binding backed by the manager's dismissed-insight keys, which are
    /// persisted across app launches via MultiYearAssumptions / DataManager (manager.dismissInsight
    /// saves directly, since a dismissal does not trigger a recompute).
    /// Setting it true records the dismissal; banners do not un-dismiss themselves.
    private func dismissBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { manager.assumptions.dismissedInsightKeys.contains(key) },
            set: { newValue in if newValue { manager.dismissInsight(key) } }
        )
    }
}
