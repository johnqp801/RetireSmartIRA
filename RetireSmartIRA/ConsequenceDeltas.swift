import Foundation

/// Path-level dollar consequences of the selected conversion approach vs taking NO additional
/// Roth conversions. Each field is (selected-path channel sum) − (no-conversion-path channel sum),
/// using the five TaxBreakdown channels. NIIT is its own channel and never folded into `federal`.
/// 2.1.0 ships these path-level aggregates; per-conversion incremental attribution is 2.1.1.
struct ConsequenceDeltas: Equatable, Sendable {
    let federal: Double
    let state: Double
    let irmaa: Double
    let aca: Double
    let niit: Double

    var total: Double { federal + state + irmaa + aca + niit }

    init(selected: [YearRecommendation], noConversion: [YearRecommendation]) {
        func sum(_ p: [YearRecommendation], _ kp: KeyPath<TaxBreakdown, Double>) -> Double {
            p.reduce(0) { $0 + $1.taxBreakdown[keyPath: kp] }
        }
        self.federal = sum(selected, \.federal)          - sum(noConversion, \.federal)
        self.state   = sum(selected, \.state)            - sum(noConversion, \.state)
        self.irmaa   = sum(selected, \.irmaa)            - sum(noConversion, \.irmaa)
        self.aca     = sum(selected, \.acaPremiumImpact) - sum(noConversion, \.acaPremiumImpact)
        self.niit    = sum(selected, \.niit)             - sum(noConversion, \.niit)
    }
}
