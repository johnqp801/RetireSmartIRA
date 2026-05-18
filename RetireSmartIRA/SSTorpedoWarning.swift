//
//  SSTorpedoWarning.swift
//  RetireSmartIRA
//
//  Detects when an additional dollar of income is taxed at an effective
//  marginal rate above the user's nominal bracket because it pushes
//  Social Security benefits through the 50% / 85% taxability phase-in.
//  Spec H2 — 1.8.2 Phase 3.
//

import Foundation

enum SSTorpedoWarning {
    enum State: Equatable {
        case inactive
        case inTorpedo50
        case inTorpedo85
    }

    struct Thresholds {
        let lower: Double
        let upper: Double
        static let mfj = Thresholds(lower: 32_000, upper: 44_000)
        static let single = Thresholds(lower: 25_000, upper: 34_000)
    }

    struct Result: Equatable {
        let state: State
        let effectiveMarginalMultiplier: Double
    }

    static func detect(provisionalIncome: Double, totalSS: Double, thresholds: Thresholds) -> Result {
        guard totalSS > 0 else {
            return Result(state: .inactive, effectiveMarginalMultiplier: 1.0)
        }
        let pi = provisionalIncome
        let lower = thresholds.lower
        let upper = thresholds.upper

        if pi < lower {
            return Result(state: .inactive, effectiveMarginalMultiplier: 1.0)
        }
        if pi < upper {
            return Result(state: .inTorpedo50, effectiveMarginalMultiplier: 1.5)
        }
        // 85% band: pi >= upper, but taxable SS not yet saturated.
        // base = 0.5 × (upper - lower); taxableSS = base + 0.85 × (pi - upper)
        // Saturation when taxableSS = 0.85 × totalSS.
        let base = 0.5 * (upper - lower)
        let saturationPI = upper + (0.85 * totalSS - base) / 0.85
        if pi < saturationPI {
            return Result(state: .inTorpedo85, effectiveMarginalMultiplier: 1.85)
        }
        return Result(state: .inactive, effectiveMarginalMultiplier: 1.0)
    }

    static func message(result: Result, ordinaryBracketRate: Double) -> String {
        switch result.state {
        case .inactive:
            return ""
        case .inTorpedo50, .inTorpedo85:
            let effective = ordinaryBracketRate * result.effectiveMarginalMultiplier * 100
            let fmt = String(format: "%.0f%%", effective)
            return "\u{26A0} SS Tax Torpedo: your next dollar is taxed at an effective ~\(fmt) marginal rate as more of your Social Security becomes taxable."
        }
    }
}
