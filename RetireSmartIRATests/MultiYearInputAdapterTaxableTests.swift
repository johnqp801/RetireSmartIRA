import Testing
@testable import RetireSmartIRA

@MainActor
@Suite("MultiYearInputAdapter taxable")
struct MultiYearInputAdapterTaxableTests {
    @Test("empty taxable accounts synthesize one bucket from currentTaxableBalance")
    func synthesizeLegacy() {
        let dm = DataManager()
        dm.taxableAccounts = []
        var a = dm.multiYearAssumptions
        a.currentTaxableBalance = 200_000
        let inputs = MultiYearInputAdapter.build(from: dm, scenarioState: dm.scenario, assumptions: a)
        #expect(inputs.taxableAccounts.count == 1)
        #expect(inputs.taxableAccounts[0].balance == 200_000)
        #expect(inputs.taxableAccounts[0].costBasis == 200_000)
    }

    @Test("when accounts exist, manual investment-income IncomeSources are not double-counted")
    func supersede() {
        let dm = DataManager()
        dm.incomeSources = [
            IncomeSource(name: "Div", type: .qualifiedDividends, annualAmount: 9_000, owner: .primary),
            IncomeSource(name: "Refund", type: .stateTaxRefund, annualAmount: 1_000, owner: .primary),
        ]
        dm.taxableAccounts = [TaxableAccount(name: "B", balance: 300_000, costBasis: 200_000,
                                             qualifiedDividendYield: 0.03)]
        let inputs = MultiYearInputAdapter.build(from: dm, scenarioState: dm.scenario,
                                                 assumptions: dm.multiYearAssumptions)
        // qualifiedDividends from the manual entry are dropped (account generates them now)...
        #expect(inputs.primaryPreferentialIncome == 0)
        // ...but the non-investment stateTaxRefund still flows as ordinary "other".
        #expect(inputs.primaryOtherOrdinaryIncome == 1_000)
        #expect(inputs.taxableAccounts.count == 1)
    }
}
