import Testing
@testable import RetireSmartIRA

@Suite("HeirValue")
struct HeirValueTests {
    @Test("taxable balance is credited to heirs at step-up")
    func taxableCredited() {
        let withTaxable = HeirValue.afterTaxToHeirs(
            roth: 100, traditional: 200, taxable: 500, heirTaxOnTraditional: 50)
        let withoutTaxable = HeirValue.afterTaxToHeirs(
            roth: 100, traditional: 200, taxable: 0, heirTaxOnTraditional: 50)
        #expect(withTaxable == withoutTaxable + 500)
        #expect(withTaxable == 100 + (200 - 50) + 500)
    }
}
