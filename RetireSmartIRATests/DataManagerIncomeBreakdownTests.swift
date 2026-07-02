// RetireSmartIRATests/DataManagerIncomeBreakdownTests.swift
import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("DataManager incomeBreakdown")
struct DataManagerIncomeBreakdownTests {
    @Test("breakdown's canonical values match the DataManager figures the tabs use today")
    func matches() {
        let dm = DataManager()
        let b = dm.incomeBreakdown
        #expect(b.allSources == dm.totalAnnualIncome())
        #expect(b.grossWithScenario == dm.scenarioGrossIncome)
        #expect(abs(b.totalWithRMDs - (dm.totalAnnualIncome() + dm.inheritedIRARMDTotal)) < 0.01)
    }
}
