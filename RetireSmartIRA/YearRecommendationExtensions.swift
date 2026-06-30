//
//  YearRecommendationExtensions.swift
//  RetireSmartIRA
//

import Foundation

extension Array where Element == YearRecommendation {
    /// Sum of tax breakdown totals across the path.
    /// Used by HeroStatView to compute Baseline Path vs Your Plan totals.
    var lifetimeTax: Double {
        reduce(0) { $0 + $1.taxBreakdown.total }
    }
}
