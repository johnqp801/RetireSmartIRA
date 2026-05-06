//
//  CalloutBannersHost.swift
//  RetireSmartIRA

import SwiftUI

struct CalloutBannersHost: View {
    @ObservedObject var manager: MultiYearStrategyManager

    var body: some View {
        VStack(spacing: 8) {
            if let nudge = manager.currentResult?.ssClaimNudge,
               !manager.assumptions.dismissedInsightKeys.contains(ssNudgeKey(nudge)) {
                ssNudgeBanner(nudge: nudge)
            }
            if let widow = manager.currentResult?.widowStressDelta,
               widow.delta > 50_000,
               !manager.assumptions.dismissedInsightKeys.contains(widowKey(widow)) {
                widowBanner(impact: widow)
            }
            if let yearsBeforeRMD = manager.yearsBeforeFirstRMD,
               !manager.assumptions.dismissedInsightKeys.contains(conversionWindowKey(yearsBeforeRMD)) {
                conversionWindowBanner(yearsBeforeRMD: yearsBeforeRMD)
            }
        }
    }

    private func ssNudgeBanner(nudge: ClaimAgeFlag) -> some View {
        let savings = abs(nudge.estimatedLifetimeTaxDelta)
        let impact: InsightCalloutBanner.Impact = savings > 50_000 ? .major : (savings > 15_000 ? .moderate : .minor)
        return InsightCalloutBanner(
            title: "Delay SS could save ~$\(Int(savings / 1000))K",
            message: "Engine suggests claiming at age \(nudge.suggestedClaimAge) instead of \(nudge.currentClaimAge) for the \(nudge.spouse == .primary ? "primary" : "spouse").",
            primaryActionLabel: nil,
            onPrimaryAction: nil,
            onDismiss: {
                manager.dismissInsight(ssNudgeKey(nudge))
            },
            impact: impact
        )
    }

    private func widowBanner(impact: TaxImpact) -> some View {
        let level: InsightCalloutBanner.Impact = impact.delta > 100_000 ? .major : .moderate
        return InsightCalloutBanner(
            title: "Widow penalty: ~$\(Int(impact.delta / 1000))K",
            message: "If the higher-earning spouse dies first, the surviving spouse pays this much more lifetime tax under single-filer rates.",
            primaryActionLabel: nil,
            onPrimaryAction: nil,
            onDismiss: { manager.dismissInsight(widowKey(impact)) },
            impact: level
        )
    }

    private func conversionWindowBanner(yearsBeforeRMD: Int) -> some View {
        InsightCalloutBanner(
            title: "Conversion window: \(yearsBeforeRMD) year\(yearsBeforeRMD == 1 ? "" : "s") before RMDs start",
            message: "Roth conversions today fill your low-bracket headroom before required distributions force a higher bracket. Best time to convert is now.",
            primaryActionLabel: nil,
            onPrimaryAction: nil,
            onDismiss: { manager.dismissInsight(conversionWindowKey(yearsBeforeRMD)) },
            impact: .moderate
        )
    }

    private func conversionWindowKey(_ years: Int) -> String {
        "conversion-window-\(years)"
    }

    private func ssNudgeKey(_ nudge: ClaimAgeFlag) -> String {
        "ss-nudge-\(nudge.spouse)-\(nudge.suggestedClaimAge)-\(Int(abs(nudge.estimatedLifetimeTaxDelta) / 1000))k"
    }

    private func widowKey(_ impact: TaxImpact) -> String {
        "widow-stress-\(Int(impact.delta / 1000))k"
    }
}
