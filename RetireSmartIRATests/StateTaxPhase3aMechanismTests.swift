import Testing
import Foundation
@testable import RetireSmartIRA

/// Phase 3a adds fields that every state leaves at its default, so the phase
/// gate proves only that they changed nothing. That is necessary and not
/// sufficient: a field the engine never reads would also change nothing.
///
/// This suite proves each new field is LOAD-BEARING, by building a synthetic
/// config with the field set away from its default and asserting the engine
/// responds. Every state's real config still uses the default; these are
/// hand-built configs passed through `configOverride`.
@Suite("Phase 3a mechanisms are load-bearing")
struct StateTaxPhase3aMechanismTests {

    /// A flat 10% state with a full IRA exemption, so the exemption's presence
    /// or absence is visible as a clean 10% of the distribution amount.
    static func flatTenPercent(
        exemptions: RetirementIncomeExemptions
    ) -> StateTaxConfig {
        StateTaxConfig(
            state: .iowa,
            taxSystem: .flat(rate: 0.10),
            retirementExemptions: exemptions,
            stateDeduction: .none
        )
    }

    static func tax(config: StateTaxConfig, age: Int, distributions: Double) -> Double {
        TaxCalculationEngine.calculateStateTax(
            income: distributions,
            forState: .iowa,
            filingStatus: .single,
            taxableSocialSecurity: 0,
            incomeSources: [],
            currentAge: age,
            enableSpouse: false,
            spouseBirthYear: 2026 - age,
            currentYear: 2026,
            scenarioRetirementDistributions: distributions,
            configOverride: config
        )
    }

    @Test("distributionMinAge gates scenario distributions at the configured age, not a hardcoded 59")
    func distributionMinAgeIsHonored() {
        let atFiftyFive = Self.flatTenPercent(
            exemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full,
                distributionMinAge: 55))
        let atDefault = Self.flatTenPercent(
            exemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .full,
                iraWithdrawalExemption: .full))

        // Age 56: exempt under a 55 gate, taxed under the default 59 gate.
        #expect(Self.tax(config: atFiftyFive, age: 56, distributions: 40_000) == 0)
        #expect(Self.tax(config: atDefault, age: 56, distributions: 40_000) == 4_000)

        // Age 60 is above both gates, so both exempt. This second pair is what
        // stops the first pair from passing for the wrong reason (a config that
        // simply never exempts anything).
        #expect(Self.tax(config: atFiftyFive, age: 60, distributions: 40_000) == 0)
        #expect(Self.tax(config: atDefault, age: 60, distributions: 40_000) == 0)
    }

    @Test("distributionMinAge defaults to 59, reproducing the previous hardcoded gate")
    func distributionMinAgeDefaultsTo59() {
        #expect(RetirementIncomeExemptions().distributionMinAge == 59)
    }
}
