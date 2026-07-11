//
//  ConversionApproach.swift
//  RetireSmartIRA
//
//  User-selectable Roth-conversion approach for the multi-year optimizer, plus the pure
//  bisection root-finder the deterministic ladders use. `.recommendedTaxMin` is the existing
//  greedy lifetime-tax minimizer; the other two are deterministic per-year rules.
//

import Foundation

enum ConversionApproach: Equatable, Sendable {
    /// The existing greedy lifetime-tax minimizer (default; unchanged behavior).
    case recommendedTaxMin
    /// Convert until ORDINARY taxable income reaches the top of the ordinary bracket at `rate`
    /// (e.g. 0.22). LTCG stacks above at preferential rates.
    case fillToBracket(rate: Double)
    /// Convert until MAGI reaches the chosen IRMAA `tier` threshold minus `buffer`, as a consistent
    /// income ceiling every year (pre- and post-Medicare).
    case limitToIRMAA(tier: Int, buffer: Double)
}

enum ConversionLadder {
    /// Largest `x` in `[0, upperBound]` with `evaluate(x) <= target`, assuming `evaluate` is
    /// monotone non-decreasing (allows flat "kink" regions from SS/senior-phaseout). Bisection.
    static func largestConversionBelow(
        target: Double,
        upperBound: Double,
        tolerance: Double = 100,
        maxIterations: Int = 24,
        evaluate: (Double) -> Double
    ) -> Double {
        guard upperBound > 0 else { return 0 }
        if evaluate(0) >= target { return 0 }
        if evaluate(upperBound) <= target { return upperBound }
        var lo = 0.0
        var hi = upperBound
        var iter = 0
        while hi - lo > tolerance && iter < maxIterations {
            let mid = (lo + hi) / 2
            if evaluate(mid) <= target { lo = mid } else { hi = mid }
            iter += 1
        }
        return lo   // largest value known to be at-or-below target
    }
}
