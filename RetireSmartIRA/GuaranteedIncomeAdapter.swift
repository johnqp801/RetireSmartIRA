import Foundation

enum GuaranteedIncomeAdapter {
    /// Pension is treated as active from projection start (V1.9 limitation — see
    /// docs/superpowers/specs/2026-06-18-1.9-drawdown-design.md §4 open question;
    /// refine if IncomeModels gains a per-source start year).
    /// Returns NOMINAL gross guaranteed income per year offset: SS turns on once the
    /// owner reaches their claiming age; everything is inflated by the single rate.
    static func schedule(primaryCurrentAge: Int, primarySSClaimAge: Int, primaryAnnualSS: Double,
                         spouseCurrentAge: Int?, spouseSSClaimAge: Int?, spouseAnnualSS: Double,
                         annualPensionFromStart: Double, inflationRatePercent: Double,
                         horizonYears: Int) -> GuaranteedIncomeSchedule {
        let infl = inflationRatePercent / 100.0
        var arr: [Double] = []
        for y in 0..<horizonYears {
            var nominal = annualPensionFromStart
            if primaryCurrentAge + y >= primarySSClaimAge { nominal += primaryAnnualSS }
            if let sAge = spouseCurrentAge, let sClaim = spouseSSClaimAge, sAge + y >= sClaim {
                nominal += spouseAnnualSS
            }
            arr.append(nominal * pow(1 + infl, Double(y)))
        }
        return GuaranteedIncomeSchedule(annualByYearOffset: arr)
    }
}
