import Testing
@testable import RetireSmartIRA

@Suite("HeirFrontierChart")
struct HeirFrontierChartTests {
    private func fp(weight: Double, ownerToday: Double, heirsToday: Double) -> FrontierPoint {
        FrontierPoint(weight: weight, ownerLifetimeTaxToday: ownerToday,
                      heirAfterTaxInheritanceToday: heirsToday, heirTaxToday: 0,
                      pvDiscountFactor: 0.5, recommendedPath: [])
    }

    @Test("maps frontier points and flags the selected weight; PV scales by the factor")
    func maps() {
        let result = HeirFrontierResult(points: [fp(weight: 0, ownerToday: 100, heirsToday: 1_000),
                                                 fp(weight: 1, ownerToday: 200, heirsToday: 1_500)])
        let today = HeirFrontierChart(result: result, selectedWeight: 0, units: .todaysDollars)
        #expect(today.points.count == 2)
        #expect(today.points[0].ownerTax == 100)
        #expect(today.points[0].heirsKeep == 1_000)
        #expect(today.points[0].isSelected)
        #expect(!today.points[1].isSelected)

        let pv = HeirFrontierChart(result: result, selectedWeight: 1, units: .presentValue)
        #expect(pv.points[0].ownerTax == 50)        // 100 * 0.5
        #expect(pv.points[1].isSelected)
    }
}
