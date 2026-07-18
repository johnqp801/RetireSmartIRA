import Testing
@testable import RetireSmartIRA

@Suite("Expense resolution (recurring anchor + one-time)")
struct ExpenseResolutionTests {
    // Worked example from the spec: baseline $100k, cpi 0, baseYear 2026.
    private func expense(_ year: Int, _ o: [Int: YearOverride]) -> Double {
        ExpenseResolution.expense(year: year, baseYear: 2026, baselineAnnualExpenses: 100_000, cpiRate: 0, overrides: o)
    }
    private func le(recurring: Double? = nil, oneTime: Double? = nil) -> YearOverride {
        YearOverride(livingExpenses: FieldOverride(recurringLevel: recurring, oneTimeAmount: oneTime))
    }

    @Test("no overrides → CPI-grown baseline")
    func noOverrides() { #expect(expense(2030, [:]) == 100_000) }

    @Test("one-time spike changes only that year")
    func spike() {
        let o = [2030: le(oneTime: 40_000)]
        #expect(expense(2030, o) == 140_000)
        #expect(expense(2031, o) == 100_000)   // neighbor unaffected
    }

    @Test("recurring anchor re-baselines from its year onward until a later anchor")
    func anchor() {
        let o = [2028: le(recurring: 90_000), 2032: le(recurring: 75_000)]
        #expect(expense(2027, o) == 100_000)   // before anchor
        #expect(expense(2028, o) == 90_000)
        #expect(expense(2031, o) == 90_000)    // still 2028 anchor (cpi 0)
        #expect(expense(2032, o) == 75_000)    // new anchor
        #expect(expense(2040, o) == 75_000)
    }

    @Test("recurring and one-time coexist in the same year (sum)")
    func coexist() {
        let o = [2028: le(recurring: 90_000, oneTime: 40_000)]
        #expect(expense(2028, o) == 130_000)
        #expect(expense(2029, o) == 90_000)    // one-time does not persist
    }

    @Test("negative one-time floors the resolved expense at zero")
    func floor() {
        let o = [2030: le(oneTime: -250_000)]
        #expect(expense(2030, o) == 0)
    }

    @Test("full spec worked example with CPI")
    func workedExampleCPI() {
        // baseline 100k, cpi 2%. 2028 recurring 90k; 2030 one-time +40k.
        func e(_ y: Int) -> Double {
            ExpenseResolution.expense(year: y, baseYear: 2026, baselineAnnualExpenses: 100_000, cpiRate: 0.02,
                overrides: [2028: le(recurring: 90_000), 2030: le(oneTime: 40_000)])
        }
        // 2030 = 90k grown 2 yrs at 2% + 40k
        let anchorGrown = 90_000 * 1.02 * 1.02
        #expect(abs(e(2030) - (anchorGrown + 40_000)) < 0.01)
        #expect(abs(e(2031) - anchorGrown * 1.02) < 0.01)   // resumes anchor path, no spike residue
    }
}
