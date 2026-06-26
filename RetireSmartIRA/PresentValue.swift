import Foundation

enum EngineMath {
    /// Present value of `amount` received `yearsFromBase` years from the base year, at a real rate.
    /// CONVENTION: `yearsFromBase == 0` is the base/current year and is **undiscounted** (factor 1.0);
    /// each later year is discounted by one more period. Tested in PresentValueTests.
    static func presentValue(_ amount: Double, yearsFromBase: Int, realDiscountRate r: Double) -> Double {
        amount / pow(1 + r, Double(max(0, yearsFromBase)))
    }
}
