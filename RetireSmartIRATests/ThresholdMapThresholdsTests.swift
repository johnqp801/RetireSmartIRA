import Testing
@testable import RetireSmartIRA

@Suite("ThresholdMapThresholds")
struct ThresholdMapThresholdsTests {
    private let config = TaxCalculationEngine.config   // live 2026 config (deterministic)

    @Test("MFJ MAGI lines include IRMAA tiers and NIIT; ACA only when requested")
    func magiLines() {
        let withACA = ThresholdMapThresholds.magiLines(
            config: config, filingStatus: .marriedFilingJointly, householdSize: 2, includeACA: true)
        // IRMAA tier 1 MFJ threshold and NIIT MFJ threshold are present at known 2026 values.
        #expect(withACA.contains { $0.value == 218_001 })   // IRMAA tier 1 MFJ
        #expect(withACA.contains { $0.id == "niit" && $0.value == 250_000 })
        #expect(withACA.contains { $0.id == "aca" })

        let noACA = ThresholdMapThresholds.magiLines(
            config: config, filingStatus: .marriedFilingJointly, householdSize: 2, includeACA: false)
        #expect(!noACA.contains { $0.id == "aca" })
        // tier 0 (the $0 baseline) is excluded from the lines
        #expect(!withACA.contains { $0.value == 0 })
    }

    @Test("MFJ bracket lines use federal MFJ thresholds and exclude the 0 bracket")
    func bracketLines() {
        let lines = ThresholdMapThresholds.bracketLines(config: config, filingStatus: .marriedFilingJointly)
        #expect(lines.contains { $0.value == 24_800 && $0.label == "12%" })  // first MFJ bracket above 0
        #expect(!lines.contains { $0.value == 0 })
    }
}
