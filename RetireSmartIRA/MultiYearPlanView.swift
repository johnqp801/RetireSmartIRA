import SwiftUI

struct MultiYearPlanView: View {
    @Environment(DataManager.self) private var dataManager
    @StateObject private var manager = MultiYearStrategyManager()
    @State private var attached = false
    @State private var units: DisplayUnits = .todaysDollars
    @State private var showingAdvanced = false

    // Selected weight's path (drives summary + ladder). Falls back to currentResult.
    private var activePath: [YearRecommendation] {
        if let p = manager.heirFrontier?.points.first(where: { $0.weight == manager.selectedHeirWeight })?.recommendedPath, !p.isEmpty {
            return p
        }
        return manager.currentResult?.recommendedPath ?? []
    }

    // Ladder rows with IRMAA attributed to conversions only: each year's surcharge minus the
    // no-conversion baseline's surcharge for that year (so income-driven IRMAA isn't blamed on the plan).
    private var ladderRows: [LadderRow] {
        let baselineIRMAA = Dictionary(
            (manager.baselineProjection ?? []).map { ($0.year, $0.taxBreakdown.irmaa) },
            uniquingKeysWith: { first, _ in first })
        return activePath.map { LadderRow($0, baselineIRMAA: baselineIRMAA[$0.year] ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Multi-Year Plan").font(.largeTitle.bold())
                    Spacer()
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

                if let result = manager.currentResult {
                    SurvivorStressBanner(widowDelta: result.widowStressDelta,
                                         dismissed: dismissBinding("survivor"))
                    SSClaimNudgeBanner(nudge: result.ssClaimNudge,
                                       dismissed: dismissBinding("ssNudge"))
                }
                ConversionWindowBanner(yearsBeforeFirstRMD: manager.yearsBeforeFirstRMD,
                                       dismissed: dismissBinding("conversionWindow"))

                AssumptionsStripView(
                    taxableBalance: Binding(get: { manager.assumptions.currentTaxableBalance },
                                            set: { manager.assumptions.currentTaxableBalance = $0 }),
                    hsaBalance: Binding(get: { manager.assumptions.currentHSABalance },
                                        set: { manager.assumptions.currentHSABalance = $0 }),
                    horizonEndAge: Binding(get: { manager.assumptions.horizonEndAge },
                                           set: { manager.assumptions.horizonEndAge = $0 }),
                    onCommit: { recomputeAll() })

                Year1EditorView(
                    year1RothConversion: year1RothBinding,
                    status: offPlanStatus,
                    onCommit: { onYear1Edited() },
                    onResetToOptimal: { resetYear1ToOptimal() })

                Button {
                    showingAdvanced = true
                } label: {
                    Label("Advanced assumptions", systemImage: "slider.horizontal.3")
                }
                .font(.callout)

                if manager.isComputing && manager.currentResult == nil {
                    ProgressView("Computing your plan…").frame(maxWidth: .infinity).padding()
                } else if activePath.isEmpty {
                    ContentUnavailableView("Set your assumptions to see your plan",
                        systemImage: "calendar.badge.clock")
                } else {
                    PlanSummaryView(summary: PlanSummary(path: activePath,
                        pvRealDiscountRate: manager.assumptions.pvRealDiscountRate,
                        cpiRate: manager.assumptions.cpiRate), units: units)
                    if let baseline = manager.baselineProjection, !baseline.isEmpty {
                        PlanComparisonView(comparison: PlanComparison(
                            plan: activePath,
                            doingNothing: baseline,
                            heirSalary: dataManager.legacyHeirEstimatedSalary,
                            heirFilingStatus: dataManager.legacyHeirFilingStatus,
                            heirDrawdownYears: dataManager.legacyDrawdownYears,
                            pvRealDiscountRate: manager.assumptions.pvRealDiscountRate,
                            cpiRate: manager.assumptions.cpiRate),
                            units: units)
                    }
                    if let baseline = manager.baselineProjection, !baseline.isEmpty {
                        TaxImpactChartView(model: TaxImpactChart(plan: activePath, doingNothing: baseline))
                    }
                    if ladderRows.contains(where: { $0.conversion > 0 }) {
                        ConversionLadderChartView(model: ConversionLadderChart(path: activePath))
                    }
                    LadderListView(rows: ladderRows)
                    BalancesChartView(model: BalancesChart(
                        path: activePath,
                        pessimistic: manager.currentResult?.sensitivityBands.pessimistic,
                        optimistic: manager.currentResult?.sensitivityBands.optimistic))
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
                    AssumptionsLimitationsView()
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
        .onChange(of: manager.assumptions) {
            dataManager.saveAllData()
        }
        .sheet(isPresented: $showingAdvanced) {
            AdvancedAssumptionsSheet(
                assumptions: Binding(get: { manager.assumptions }, set: { manager.assumptions = $0 }),
                spouseEnabled: dataManager.enableSpouse,
                onCommit: { recomputeAll() })
        }
    }

    private func recomputeAll() {
        manager.recompute(reason: .assumptionsChanged)
        manager.computeHeirFrontier()
    }

    // Combined household Year-1 Roth conversion. v2.0 treats it as one amount (matches
    // resetYear1ToEngineOptimal): editing assigns the whole amount to primary and zeroes spouse.
    private var year1RothBinding: Binding<Double> {
        Binding(
            get: { dataManager.yourRothConversion + dataManager.spouseRothConversion },
            set: { newValue in
                dataManager.yourRothConversion = max(0, newValue)
                dataManager.spouseRothConversion = 0
            }
        )
    }

    private var offPlanStatus: OffPlanStatus? {
        guard let current = manager.currentResult, let optimal = manager.engineOptimalResult else { return nil }
        return OffPlanStatus(extraLifetimeTax:
            current.lifetimeTaxFromRecommendedPath - optimal.lifetimeTaxFromRecommendedPath)
    }

    private func onYear1Edited() {
        manager.recompute(reason: .overridesChanged)   // current-only; optimal is cached
        manager.computeHeirFrontier()
        dataManager.saveAllData()
    }

    private func resetYear1ToOptimal() {
        manager.resetYear1ToEngineOptimal()            // writes the shared levers + recomputes current
        manager.computeHeirFrontier()
        dataManager.saveAllData()
    }

    /// One-way dismissal binding backed by the manager's dismissed-insight keys, which are
    /// persisted across app launches via MultiYearAssumptions / DataManager (the view's
    /// onChange(of: manager.assumptions) saves them through saveAllData()).
    /// Setting it true records the dismissal; banners do not un-dismiss themselves.
    private func dismissBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { manager.assumptions.dismissedInsightKeys.contains(key) },
            set: { newValue in if newValue { manager.dismissInsight(key) } }
        )
    }
}
