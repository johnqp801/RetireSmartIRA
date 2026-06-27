import SwiftUI

struct MultiYearPlanView: View {
    @Environment(DataManager.self) private var dataManager
    @StateObject private var manager = MultiYearStrategyManager()
    @State private var attached = false
    @State private var units: DisplayUnits = .todaysDollars

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
                            Text("Today's $").tag(DisplayUnits.todaysDollars)
                            Text("Present value").tag(DisplayUnits.presentValue)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                }

                AssumptionsStripView(
                    taxableBalance: Binding(get: { manager.assumptions.currentTaxableBalance },
                                            set: { manager.assumptions.currentTaxableBalance = $0 }),
                    hsaBalance: Binding(get: { manager.assumptions.currentHSABalance },
                                        set: { manager.assumptions.currentHSABalance = $0 }),
                    horizonEndAge: Binding(get: { manager.assumptions.horizonEndAge },
                                           set: { manager.assumptions.horizonEndAge = $0 }),
                    onCommit: { recomputeAll() })

                if manager.isComputing && manager.currentResult == nil {
                    ProgressView("Computing your plan…").frame(maxWidth: .infinity).padding()
                } else if activePath.isEmpty {
                    ContentUnavailableView("Set your assumptions to see your plan",
                        systemImage: "calendar.badge.clock")
                } else {
                    PlanSummaryView(summary: PlanSummary(path: activePath,
                        pvRealDiscountRate: manager.assumptions.pvRealDiscountRate), units: units)
                    if let baseline = manager.baselineProjection, !baseline.isEmpty {
                        PlanComparisonView(comparison: PlanComparison(
                            plan: activePath,
                            doingNothing: baseline,
                            heirSalary: dataManager.legacyHeirEstimatedSalary,
                            heirFilingStatus: dataManager.legacyHeirFilingStatus,
                            heirDrawdownYears: dataManager.legacyDrawdownYears,
                            pvRealDiscountRate: manager.assumptions.pvRealDiscountRate),
                            units: units)
                    }
                    LadderListView(rows: ladderRows)
                    if let frontier = manager.heirFrontier {
                        HeirFrontierView(result: frontier,
                            selectedWeight: Binding(get: { manager.selectedHeirWeight },
                                                    set: { manager.selectedHeirWeight = $0 }),
                            units: units)
                    } else if manager.isComputingFrontier {
                        ProgressView("Computing heir trade-off…")
                    }
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
    }

    private func recomputeAll() {
        manager.recompute(reason: .assumptionsChanged)
        manager.computeHeirFrontier()
    }
}
