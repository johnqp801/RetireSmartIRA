//
//  TaxPlanningBottomSheet.swift
//  RetireSmartIRA

import SwiftUI

struct TaxPlanningBottomSheet: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var manager: MultiYearStrategyManager
    let selectedYear: Int?
    @Binding var detent: PresentationDetent

    var body: some View {
        Group {
            if detent == .fraction(0.15) {
                statusLine
            } else if let year = selectedYear, year == dataManager.currentYear {
                year1Content
            } else if let year = selectedYear,
                      let result = manager.currentResult,
                      let rec = result.recommendedPath.first(where: { $0.year == year }) {
                year2PlusContent(rec: rec, result: result)
            } else {
                Text("Select a year")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var statusLine: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Image(systemName: "chevron.up").font(.caption2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusText: String {
        guard let year = selectedYear,
              let result = manager.currentResult,
              let rec = result.recommendedPath.first(where: { $0.year == year }) else {
            return "Select a year"
        }
        if year == dataManager.currentYear {
            return "Year 1 (\(year)) · $\(Int(rec.taxBreakdown.total / 1000))K tax · ↑ Edit"
        }
        return "\(year) · $\(Int(rec.taxBreakdown.total / 1000))K tax · ↑ Detail"
    }

    private var year1Content: some View {
        ScrollView {
            VStack(spacing: 12) {
                Year1QuickEditor(manager: manager)
                    .environmentObject(dataManager)
                if detent == .large {
                    ScenarioBuilderView()
                        .environmentObject(dataManager)
                    DashboardView()
                        .environmentObject(dataManager)
                }
            }
            .padding(14)
        }
    }

    private func year2PlusContent(rec: YearRecommendation, result: MultiYearStrategyResult) -> some View {
        let priorIdx = result.recommendedPath.firstIndex(where: { $0.year == rec.year }) ?? 0
        let priorRec: YearRecommendation? = priorIdx > 0 ? result.recommendedPath[priorIdx - 1] : nil
        let hit = result.tradeOffsAccepted.first(where: { $0.year == rec.year })
        return YearProjectionCard(
            recommendation: rec,
            priorRecommendation: priorRec,
            constraintHit: hit,
            priorBalances: priorRec?.endOfYearBalances
        )
    }
}
