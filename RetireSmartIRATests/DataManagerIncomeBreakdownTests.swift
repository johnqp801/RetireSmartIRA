// RetireSmartIRATests/DataManagerIncomeBreakdownTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("DataManager incomeBreakdown")
struct DataManagerIncomeBreakdownTests {
    @Test("each subtotal reproduces the exact headline expression its tab uses")
    func matchesHeadlineExpressions() {
        let dm = DataManager()
        let b = dm.incomeBreakdown
        let regularRMD = dm.calculateCombinedRMD()
        let inheritedRMD = dm.inheritedIRARMDTotal

        // Income headline
        #expect(b.allSources == dm.totalAnnualIncome())
        // Tax Summary headline: totalAnnualIncome() + combinedRMD + inheritedRMD
        #expect(abs(b.totalWithRMDs - (dm.totalAnnualIncome() + regularRMD + inheritedRMD)) < 0.01)
        // Scenarios headline: taxableIncome() + combinedRMD + inheritedRMD
        #expect(abs(b.taxableFromSources
            - (dm.taxableIncome(filingStatus: dm.filingStatus) + regularRMD + inheritedRMD)) < 0.01)
        // Quarterly headline
        #expect(b.grossWithScenario == dm.scenarioGrossIncome)
    }

    @Test("the composed chain foots: each subtotal equals the running total of its steps")
    func chainFoots() {
        let dm = DataManager()
        let b = dm.incomeBreakdown
        // Subtotal rows carry the cumulative value for display; footing means the component
        // (non-subtotal) steps sum to each subtotal.
        var sum = 0.0
        var subtotalsSeen = 0
        for step in b.steps {
            if step.isSubtotal {
                subtotalsSeen += 1
                switch step.label {
                case "Total income (sources + RMDs)": #expect(abs(sum - b.totalWithRMDs) < 0.01)
                case "Taxable income from sources": #expect(abs(sum - b.taxableFromSources) < 0.01)
                case "Gross income (with scenario)": #expect(abs(sum - b.grossWithScenario) < 0.01)
                default: Issue.record("unexpected subtotal label: \(step.label)")
                }
            } else {
                sum += step.amount
            }
        }
        #expect(subtotalsSeen == 3)
    }
}
