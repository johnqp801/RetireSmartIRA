import Foundation

enum EngineMath {
    /// Present value of `amount` received `yearsFromBase` years from the base year, at a real rate.
    /// CONVENTION: `yearsFromBase == 0` is the base/current year and is **undiscounted** (factor 1.0);
    /// each later year is discounted by one more period. Tested in PresentValueTests.
    static func presentValue(_ amount: Double, yearsFromBase: Int, realDiscountRate r: Double) -> Double {
        amount / pow(1 + r, Double(max(0, yearsFromBase)))
    }

    /// Today's-dollars present value of a **nominal** future amount: first deflate by CPI to
    /// real (today's purchasing power), then discount at the real rate. Equivalent to discounting
    /// at the combined (Fisher) factor `(1+cpi)(1+r)`. Use for the present-value DISPLAY of
    /// nominally-projected balances/taxes. When `cpiRate == 0` this equals `presentValue(...)`.
    static func realPresentValue(_ amount: Double, yearsFromBase: Int,
                                 cpiRate: Double, realDiscountRate r: Double) -> Double {
        amount / pow((1 + cpiRate) * (1 + r), Double(max(0, yearsFromBase)))
    }
}
