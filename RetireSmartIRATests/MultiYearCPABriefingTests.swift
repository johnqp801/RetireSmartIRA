import Foundation
import Testing
@testable import RetireSmartIRA

@Suite("MultiYearCPABriefing")
struct MultiYearCPABriefingTests {
    private func rec(_ year: Int, conv: Double, taxFundingWithdrawal: Double = 0) -> YearRecommendation {
        YearRecommendation(year: year, agi: 120_000, acaMagi: nil, irmaaMagi: 120_000, taxableIncome: 95_000,
            taxBreakdown: TaxBreakdown(federal: 18_000, state: 4_000, irmaa: 1_200, acaPremiumImpact: 0),
            endOfYearBalances: AccountSnapshot(traditional: 800_000, roth: 200_000, taxable: 300_000, hsa: 0),
            actions: conv > 0 ? [.rothConversion(amount: conv)] : [], rmd: year >= 2030 ? 40_000 : 0,
            executedRothConversion: conv, taxFundingWithdrawal: taxFundingWithdrawal)
    }

    private func model() -> CPABriefingModel {
        let path = [rec(2026, conv: 60_000), rec(2027, conv: 50_000), rec(2030, conv: 0)]
        let none = [rec(2026, conv: 0), rec(2027, conv: 0), rec(2030, conv: 0)]
        return CPABriefingModel(
            preparedFor: "Jane & John Public",
            taxYear: 2026,
            filingStatusLabel: "Married Filing Jointly",
            stateLabel: "CA",
            primaryBirthYear: 1959,
            summary: PlanSummary(path: path),
            comparison: PlanComparison(plan: path, doingNothing: none, heirSalary: 0,
                                       heirFilingStatus: .single, heirDrawdownYears: 10),
            yearRows: path,
            frontier: nil,
            includeHeirs: true,
            assumptions: MultiYearAssumptions(),
            limitations: V2Disclosures.limitations,
            positioning: V2Disclosures.positioning)
    }

    @Test("HTML contains the required sections, a known figure, all limitations, and a disclaimer")
    func builds() {
        let html = MultiYearCPABriefingHTML.build(model())
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("Multi-Year Roth Conversion Plan"))
        #expect(html.contains("Jane &amp; John Public"))     // escaped ampersand
        #expect(html.contains("Recommended conversions"))
        #expect(html.contains("Your plan vs. doing nothing"))
        #expect(html.contains("Year-by-year detail"))
        #expect(html.contains("Assumptions"))
        #expect(html.contains("Limitations"))
        for limitation in V2Disclosures.limitations {
            #expect(html.contains(MultiYearCPABriefingHTML.escapeForTest(limitation)))
        }
        #expect(html.localizedCaseInsensitiveContains("not tax advice"))
        #expect(!html.contains("\u{2014}"))                  // no em dash
    }

    @Test("no Roth conversion case still builds a valid document")
    func emptyConversions() {
        var m = model()
        m = CPABriefingModel(preparedFor: m.preparedFor, taxYear: m.taxYear,
            filingStatusLabel: m.filingStatusLabel, stateLabel: m.stateLabel,
            primaryBirthYear: m.primaryBirthYear, summary: m.summary, comparison: m.comparison,
            yearRows: [rec(2026, conv: 0)], frontier: nil, includeHeirs: m.includeHeirs,
            assumptions: m.assumptions, limitations: m.limitations, positioning: m.positioning)
        let html = MultiYearCPABriefingHTML.build(m)
        #expect(html.contains("</html>"))
    }

    @Test("includeHeirs gates the heir metric row")
    func heirGating() {
        // Default model has includeHeirs == true: the heir row is present.
        #expect(MultiYearCPABriefingHTML.build(model()).contains("What heirs keep"))

        // includeHeirs == false (legacy planning off): the heir row is omitted.
        let m = model()
        let off = CPABriefingModel(preparedFor: m.preparedFor, taxYear: m.taxYear,
            filingStatusLabel: m.filingStatusLabel, stateLabel: m.stateLabel,
            primaryBirthYear: m.primaryBirthYear, summary: m.summary, comparison: m.comparison,
            yearRows: m.yearRows, frontier: nil, includeHeirs: false,
            assumptions: m.assumptions, limitations: m.limitations, positioning: m.positioning)
        #expect(!MultiYearCPABriefingHTML.build(off).contains("What heirs keep"))
    }

    @Test("A4: gross-up IRA withdrawal is disclosed separately from the conversion amount")
    func grossUpDisclosed() {
        let path = [rec(2026, conv: 60_000, taxFundingWithdrawal: 22_000), rec(2027, conv: 50_000)]
        let none = [rec(2026, conv: 0), rec(2027, conv: 0)]
        let m = CPABriefingModel(
            preparedFor: "Jane & John Public", taxYear: 2026,
            filingStatusLabel: "Married Filing Jointly", stateLabel: "CA", primaryBirthYear: 1959,
            summary: PlanSummary(path: path),
            comparison: PlanComparison(plan: path, doingNothing: none, heirSalary: 0,
                                       heirFilingStatus: .single, heirDrawdownYears: 10),
            yearRows: path, frontier: nil, includeHeirs: true,
            assumptions: MultiYearAssumptions(), limitations: V2Disclosures.limitations,
            positioning: V2Disclosures.positioning)
        let html = MultiYearCPABriefingHTML.build(m)
        #expect(html.contains("IRA withdrawn to pay tax"))
        #expect(html.contains("2026: IRA withdrawn to pay tax: $22,000"))
        // The year with no gross-up shows a "-" placeholder in the ladder's third column, not a
        // spurious dollar figure.
        #expect(html.contains("<td>2027</td><td>$50,000</td><td>-</td>"))
    }

    @Test("no gross-up anywhere: ladder table stays two columns, no disclosure note")
    func noGrossUpNoDisclosure() {
        let html = MultiYearCPABriefingHTML.build(model())
        #expect(!html.contains("IRA withdrawn to pay tax"))
        #expect(html.contains("<tr><th>Year</th><th>Roth conversion</th></tr>"))
    }

    // B5 parity: the on-screen compare table defaults to present value, so the CPA export's
    // lifetime-tax figures must be present value too (labeled), not the nominal sum — otherwise
    // the same "Lifetime tax" label shows two different numbers across the two surfaces.
    @Test("exec summary and comparison print lifetime tax in labeled present value")
    func lifetimeTaxIsPresentValueLabeled() {
        // Build with a real discount so nominal and PV genuinely differ (the shared model()
        // fixture defaults both rates to 0, which would make the PV assertions vacuous).
        let path = [rec(2026, conv: 60_000), rec(2027, conv: 50_000), rec(2030, conv: 0)]
        let none = [rec(2026, conv: 0), rec(2027, conv: 0), rec(2030, conv: 0)]
        let base = model()
        let m = CPABriefingModel(
            preparedFor: base.preparedFor, taxYear: base.taxYear,
            filingStatusLabel: base.filingStatusLabel, stateLabel: base.stateLabel,
            primaryBirthYear: base.primaryBirthYear,
            summary: PlanSummary(path: path, pvRealDiscountRate: 0.03, cpiRate: 0.025),
            comparison: PlanComparison(plan: path, doingNothing: none, heirSalary: 0,
                                       heirFilingStatus: .single, heirDrawdownYears: 10,
                                       pvRealDiscountRate: 0.03, cpiRate: 0.025),
            yearRows: path, frontier: nil, includeHeirs: true,
            assumptions: MultiYearAssumptions(), limitations: base.limitations,
            positioning: base.positioning)
        let html = MultiYearCPABriefingHTML.build(m)

        // Multi-year path with a nonzero discount rate: nominal and PV must differ, or the
        // assertion below would be vacuous.
        #expect(abs(m.summary.lifetimeTax - m.summary.lifetimeTaxPV) > 1.0)

        #expect(html.contains("Projected lifetime tax (plan, present value)"))
        #expect(html.contains("Projected lifetime tax (doing nothing, present value)"))
        #expect(html.contains("Lifetime tax (present value)"))
        // The PV figures are the ones printed.
        #expect(html.contains(MultiYearCPABriefingHTML.fmtForTest(m.summary.lifetimeTaxPV)))
        #expect(html.contains(MultiYearCPABriefingHTML.fmtForTest(m.comparison.lifetimeTaxPV.doingNothing)))
    }

    // Product decision 2026-07-17: Multi-Year displays default to Present value so the compare
    // table is unit-consistent on first view (the Future-$ toggle remains available).
    @Test("Multi-Year display units default to present value")
    func defaultUnitsIsPresentValue() {
        #expect(MultiYearPlanView.defaultUnits == .presentValue)
    }
}
