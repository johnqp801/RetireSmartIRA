//
//  NIITCliffIndicator.swift
//  RetireSmartIRA
//
//  Cliff-awareness state for the NIIT (3.8% net investment income surtax)
//  position bar. Surfaces approaching/triggered warnings inside the
//  existing niitPositionChart (DashboardView + ScenarioChartsView).
//  Spec H1 — 1.8.2 Phase 3.
//

import Foundation

enum NIITCliffIndicator {
    enum State: Equatable {
        case hidden      // user has no investment income — NIIT not relevant
        case clear       // MAGI well below threshold
        case approaching // MAGI within $25K of threshold (from below) OR equal
        case triggered   // MAGI strictly above threshold
    }

    static func state(magi: Double, threshold: Double, nii: Double) -> State {
        if nii <= 0 { return .hidden }
        if magi > threshold { return .triggered }
        if magi >= threshold - 25_000 { return .approaching }
        return .clear
    }

    static func message(state: State, magi: Double, threshold: Double, nii: Double) -> String {
        switch state {
        case .hidden, .clear:
            return ""
        case .approaching:
            let headroom = max(0, threshold - magi)
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            fmt.maximumFractionDigits = 0
            let dollars = fmt.string(from: NSNumber(value: headroom)) ?? "$0"
            return "Approaching NIIT threshold — \(dollars) below the 3.8% surtax band."
        case .triggered:
            let subject = min(nii, max(0, magi - threshold))
            let surcharge = subject * 0.038
            let fmt = NumberFormatter()
            fmt.numberStyle = .currency
            fmt.maximumFractionDigits = 0
            let dollars = fmt.string(from: NSNumber(value: surcharge)) ?? "$0"
            return "\(dollars)/yr NIIT surcharge applies on this scenario."
        }
    }
}
