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

        // Age 60 is above both gates, so both configs exempt. This pair does
        // not catch a mutant the pair above misses; it documents the intended
        // shape of the boundary, that the two configs agree above it and
        // disagree below it.
        #expect(Self.tax(config: atFiftyFive, age: 60, distributions: 40_000) == 0)
        #expect(Self.tax(config: atDefault, age: 60, distributions: 40_000) == 0)
    }

    @Test("distributionMinAge defaults to 59, reproducing the previous hardcoded gate")
    func distributionMinAgeDefaultsTo59() {
        #expect(RetirementIncomeExemptions().distributionMinAge == 59)
    }

    @Test("distributionMinAge also gates per-individual cap doubling, not only scenario distributions")
    func distributionMinAgeGatesPerIndividualDoubling() {
        // Reaches `ageQualifiesForExemption`, which is only called from
        // `bothSpousesQualify` and therefore needs enableSpouse: true. Its
        // distributionMinAge fallback runs only when regularExemptionMinAge is
        // 0, so this config leaves that at its default. A $20,000 partial cap
        // that doubles is the cheapest way to make the multiplier observable.
        func config(distributionMinAge: Int) -> StateTaxConfig {
            Self.flatTenPercent(exemptions: RetirementIncomeExemptions(
                socialSecurityExempt: true,
                pensionExemption: .partial(maxExempt: 20_000),
                iraWithdrawalExemption: .none,
                exemptionAppliesPerIndividual: true,
                distributionMinAge: distributionMinAge))
        }

        func tax(config: StateTaxConfig, spouseAge: Int) -> Double {
            TaxCalculationEngine.calculateStateTax(
                income: 40_000, forState: .iowa, filingStatus: .marriedFilingJointly,
                taxableSocialSecurity: 0,
                incomeSources: [IncomeSource(name: "Pension", type: .pension,
                                             annualAmount: 40_000)],
                currentAge: 60, enableSpouse: true,
                spouseBirthYear: 2026 - spouseAge, currentYear: 2026,
                configOverride: config)
        }

        // Spouse is 56. Under a 55 gate BOTH spouses qualify, the cap doubles
        // to 40,000 and the whole pension is excluded. Under the default 59
        // gate the spouse does not qualify, the cap stays 20,000, and 20,000
        // remains taxable at 10 percent.
        #expect(tax(config: config(distributionMinAge: 55), spouseAge: 56) == 0)
        #expect(tax(config: config(distributionMinAge: 59), spouseAge: 56) == 2_000)

        // Spouse at 60 is above BOTH gates, so both configs double the cap.
        // Without this pair the first could pass for a config that simply
        // never doubles.
        #expect(tax(config: config(distributionMinAge: 55), spouseAge: 60) == 0)
        #expect(tax(config: config(distributionMinAge: 59), spouseAge: 60) == 0)
    }
}
