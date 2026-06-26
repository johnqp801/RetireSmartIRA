import Testing
import Foundation
@testable import RetireSmartIRA

@Suite("HeirFrontierViewModel", .serialized)
struct HeirFrontierViewModelTests {
    private func point(_ w: Double, owner: Double, heirs: Double) -> FrontierPoint {
        FrontierPoint(weight: w, ownerLifetimeTaxToday: owner, heirAfterTaxInheritanceToday: heirs,
            heirTaxToday: 0, pvDiscountFactor: 1, recommendedPath: [])
    }

    @Test("delta readout compares the selected point against the baseline")
    func deltaReadout() {
        let baseline = point(0, owner: 142_000, heirs: 610_000)
        let selected = point(0.5, owner: 168_000, heirs: 758_000)
        let vm = HeirFrontierViewModel(baseline: baseline, selected: selected, units: .todaysDollars)
        #expect(vm.ownerTaxDelta == 26_000)
        #expect(vm.heirInheritanceDelta == 148_000)
        #expect(vm.readoutText.contains("$26k"))
        #expect(vm.readoutText.contains("$148k"))
    }
}
