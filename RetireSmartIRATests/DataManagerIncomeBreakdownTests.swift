// RetireSmartIRATests/DataManagerIncomeBreakdownTests.swift
import Testing
import Foundation
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

    @Test("foots on a real nonzero-RMD household (age past RBD + traditional IRA + tax-exempt interest)")
    func footsForNonzeroRMDHousehold() {
        let dm = DataManager(skipPersistence: true)
        dm.currentYear = 2026
        dm.profile.currentYear = 2026
        // Born 1950 -> age 76 in 2026, well past the RMD required beginning date.
        dm.profile.birthDate = Calendar.current.date(from: DateComponents(year: 1950, month: 1, day: 1))!
        dm.iraAccounts = [IRAAccount(name: "Trad", accountType: .traditionalIRA, balance: 500_000, owner: .primary)]
        dm.incomeSources = [
            IncomeSource(name: "Pension", type: .pension, annualAmount: 60_000),
            IncomeSource(name: "Municipal Bonds", type: .taxExemptInterest, annualAmount: 20_000)
        ]

        let regularRMD = dm.calculateCombinedRMD()
        #expect(regularRMD > 0)  // a real RMD is in play -- the case the demo profile hid

        let b = dm.incomeBreakdown
        // The regular-RMD row is shown with the canonical value.
        #expect(b.steps.contains { $0.label == "Regular RMD" && abs($0.amount - regularRMD) < 0.01 })
        // Tax-exempt interest pulls taxable below gross, so the bridge residual is exercised (negative).
        #expect(b.taxableFromSources < b.totalWithRMDs)
        #expect(b.steps.contains {
            $0.label == "Less tax-exempt interest and untaxed Social Security" && $0.amount < 0 })

        // The chain foots: component (non-subtotal) steps sum to each subtotal.
        var sum = 0.0
        for step in b.steps {
            if step.isSubtotal {
                switch step.label {
                case "Total income (sources + RMDs)": #expect(abs(sum - b.totalWithRMDs) < 0.01)
                case "Taxable income from sources": #expect(abs(sum - b.taxableFromSources) < 0.01)
                case "Gross income (with scenario)": #expect(abs(sum - b.grossWithScenario) < 0.01)
                default: Issue.record("unexpected subtotal: \(step.label)")
                }
            } else { sum += step.amount }
        }

        // Headline equivalence still holds on real data.
        #expect(abs(b.totalWithRMDs
            - (dm.totalAnnualIncome() + regularRMD + dm.inheritedIRARMDTotal)) < 0.01)
        #expect(abs(b.taxableFromSources
            - (dm.taxableIncome(filingStatus: dm.filingStatus) + regularRMD + dm.inheritedIRARMDTotal)) < 0.01)
    }
}
