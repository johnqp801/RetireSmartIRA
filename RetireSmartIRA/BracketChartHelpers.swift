//
//  BracketChartHelpers.swift
//  RetireSmartIRA
//
//  Shared math for positioning a value marker inside an equal-width
//  bracket bar (federal/state/scenario charts). Extracted from
//  DashboardView.stateBracketMarkerPosition + ScenarioChartsView.scenarioBracketMarkerPosition
//  per spec C1 (1.8.2 Phase 3).
//

import SwiftUI

enum BracketChartHelpers {
    /// Positions a dollar value marker inside an equal-width segmented bar.
    static func bracketMarkerPosition<S: BracketSegmentLike>(
        value: Double,
        segments: [S],
        barWidth: CGFloat
    ) -> CGFloat {
        guard !segments.isEmpty else { return 0 }
        let segmentWidth = barWidth / CGFloat(segments.count)

        for (idx, segment) in segments.enumerated() {
            if value >= segment.rangeStart && value < segment.rangeEnd {
                let rangeDelta = segment.rangeEnd - segment.rangeStart
                let intra: CGFloat = rangeDelta > 0
                    ? CGFloat((value - segment.rangeStart) / rangeDelta)
                    : 0
                return CGFloat(idx) * segmentWidth + intra * segmentWidth
            }
        }
        return barWidth - 4
    }
}

public protocol BracketSegmentLike: Sendable {
    var rangeStart: Double { get }
    var rangeEnd: Double { get }
}
